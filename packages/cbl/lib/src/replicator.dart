import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';

import 'database.dart';
import 'document/document.dart';
import 'errors.dart';
import 'fleece.dart';
import 'native_callback.dart';
import 'native_object.dart';
import 'resource.dart';
import 'streams.dart';
import 'utils.dart';
import 'worker/cbl_worker.dart';

// region Internal API

Future<Replicator> createReplicator({
  required DatabaseImpl db,
  required ReplicatorConfiguration config,
  required String? debugCreator,
}) {
  return runKeepAlive(() async {
    final pushFilterCallback = config.pushFilter?.let(_wrapReplicationFilter);
    final pullFilterCallback = config.pullFilter?.let(_wrapReplicationFilter);
    final conflictResolverCallback =
        config.conflictResolver?.let(_wrapConflictResolver);

    void disposeCallbacks() => ([
          pushFilterCallback,
          pullFilterCallback,
          conflictResolverCallback
        ].whereNotNull().forEach((it) => it.close()));

    final endpoint = config.createEndpoint();
    final authenticator = config.createAuthenticator();

    try {
      final result = await db.native.worker.execute(NewReplicator(
        db.native.pointer,
        endpoint,
        config.replicatorType ?? ReplicatorType.pushAndPull,
        config.continuous ?? false,
        null,
        null,
        null,
        null,
        authenticator,
        config.proxy?.type,
        config.proxy?.hostname,
        config.proxy?.port,
        config.proxy?.username,
        config.proxy?.password,
        config.headers?.let((it) => MutableDict(it).native.pointer.cast()),
        config.pinnedServerCertificate,
        config.trustedRootCertificates,
        config.channels?.let((it) => MutableArray(it).native.pointer.cast()),
        config.documentIds?.let((it) => MutableArray(it).native.pointer.cast()),
        pushFilterCallback?.native.pointer,
        pullFilterCallback?.native.pointer,
        conflictResolverCallback?.native.pointer,
      ));

      return ReplicatorImpl(
        database: db,
        pointer: result.pointer,
        disposeCallbacks: disposeCallbacks,
        debugCreator: debugCreator,
      );
    } catch (e) {
      disposeCallbacks();
      rethrow;
    } finally {
      _bindings.freeEndpoint(endpoint);
      if (authenticator != null) {
        _bindings.freeAuthenticator(authenticator);
      }
    }
  });
}

extension CBLReplicatorStatusExt on CBLReplicatorStatus {
  ReplicatorStatus toReplicatorStatus() => ReplicatorStatus(
        activity.toReplicatorActivityLevel(),
        ReplicatorProgress(
          progress.complete,
          progress.documentCount,
        ),
        exception?.translate(),
      );
}

// endregion

late final _bindings = CBLBindings.instance.replicator;

/// The location of a database to replicate with.
abstract class Endpoint {}

/// An endpoint representing a server-based database at the given [url].
///
/// The Url's scheme must be `ws` or `wss`, it must of course have a valid
/// hostname, and its path must be the name of the database on that server.
/// The port can be omitted; it defaults to 80 for `ws` and 443 for `wss`.
/// For example: `wss://example.org/dbname`
class UrlEndpoint extends Endpoint {
  UrlEndpoint(this.url);

  /// The url of the database to replicate with.
  final Uri url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlEndpoint &&
          other.runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'UrlEndpoint(url: $url)';
}

/// The authentication credentials for a remote server.
abstract class Authenticator {}

/// An authenticator for HTTP Basic (username/password) auth.
class BasicAuthenticator extends Authenticator {
  BasicAuthenticator({required this.username, required this.password});

  /// The username to authenticate with.
  final String username;

  /// The password to authenticate with.
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BasicAuthenticator &&
          other.runtimeType == other.runtimeType &&
          username == other.password &&
          password == other.password;

  @override
  int get hashCode => super.hashCode ^ username.hashCode ^ password.hashCode;

  @override
  String toString() =>
      'BasicAuthenticator(username: $username, password: ${redact(password)})';
}

/// An authenticator using a Couchbase Sync Gateway login session identifier,
/// and optionally a cookie name (pass `null` for the default.)
class SessionAuthenticator extends Authenticator {
  SessionAuthenticator({required this.sessionId, this.cookieName});

  /// The id of the authentication session.
  final String sessionId;

  /// The name of the cookie to send the [sessionId] in.
  final String? cookieName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAuthenticator &&
          other.runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          cookieName == other.cookieName;

  @override
  int get hashCode => super.hashCode ^ sessionId.hashCode ^ cookieName.hashCode;

  @override
  String toString() => 'SessionAuthenticator('
      'sessionId: ${redact(sessionId)}, '
      'cookieName: $cookieName'
      ')';
}

/// A callback that can decide whether a particular document should be pushed or
/// pulled.
///
/// It should not take a long time to return, or it will slow down the
/// replicator.
///
/// The callback receives the [document] in question and whether it [isDeleted].
///
/// Return `true` if the document should be replicated, `false` to skip it.
typedef ReplicationFilter = FutureOr<bool> Function(
  Document document,
  bool isDeleted,
);

NativeCallback _wrapReplicationFilter(ReplicationFilter filter) =>
    NativeCallback((arguments, result) async {
      final message = ReplicationFilterCallbackMessage.fromArguments(arguments);
      final doc = DocumentImpl(
        doc: message.document,
        retain: true,
        debugCreator: 'ReplicationFilter()',
      );

      var decision = false;
      try {
        decision = await filter(
          doc,
          message.flags.contains(CBLReplicatedDocumentFlag.deleted),
        );
      } finally {
        result!(decision);
      }
    });

/// Conflict-resolution callback for use in replications.
///
/// This callback will be invoked when the [Replicator] finds a newer
/// server-side revision of a document that also has local changes. The local
/// and remote changes must be resolved before the document can be pushed to the
/// server.
///
/// Unlike a [ReplicationFilter], it does not need to return quickly. If it
/// needs to prompt for user input, that's OK.
///
/// The callback receives the [documentId] of the conflicted document,
/// the [local] revision of the document in the database, or `null` if the
/// local document has been deleted and the the [remote] revision of the
/// document found on the server or `null` if the document has been deleted
/// on the server.
///
/// Return the resolved document to save locally (and push, if the replicator is
/// pushing.) This can be the same as [local] or [remote], or you can create
/// a mutable copy of either one and modify it appropriately.
/// Alternatively return `null` if the resolution is to delete the document.
typedef ConflictResolver = FutureOr<Document?> Function(
  String documentId,
  Document? local,
  Document? remote,
);

NativeCallback _wrapConflictResolver(ConflictResolver filter) =>
    NativeCallback((arguments, result) async {
      final message =
          ReplicationConflictResolverCallbackMessage.fromArguments(arguments);

      final local = message.localDocument?.let((it) => DocumentImpl(
            doc: it,
            retain: true,
            debugCreator: 'ConflictResolver(local)',
          ));

      final remote = message.remoteDocument?.let((it) => DocumentImpl(
            doc: it,
            retain: true,
            debugCreator: 'ConflictResolver(remote)',
          ));

      var resolved = remote;
      // TODO: throw on the native side when resolver throws
      // Also review whether other callbacks can be aborted.
      try {
        resolved = await filter(
          message.documentId,
          local,
          remote,
        ) as DocumentImpl?;
        if (resolved is MutableDocumentImpl) {
          resolved.flushProperties();
        }
      } finally {
        final resolvedPointer = resolved?.doc.pointerUnsafe;

        // If the resolver returned a document other than `local` or `remote`,
        // the ref count of `resolved` needs to be incremented because the
        // native conflict resolver callback is expected to returned a document
        // with a ref count of +1, which the caller balances with a release.
        // This must happen on the Dart side, because `resolved` can be garbage
        // collected before `resolvedAddress` makes it back to the native side.
        // if (resolvedPointer != null &&
        //     resolved != local &&
        //     resolved != remote) {
        //   CBLBindings.instance.base.retainRefCounted(resolvedPointer.cast());
        // }

        // Workaround for a bug in CBL C SDK, which frees all resolved
        // documents, not just merged ones. When this bug is fixed the above
        // commented out code block should replace this one.
        // https://github.com/couchbase/couchbase-lite-C/issues/148
        if (resolvedPointer != null) {
          CBLBindings.instance.base.retainRefCounted(resolvedPointer.cast());
        }

        result!(resolvedPointer?.address);
      }
    });

/// Types of proxy servers, for CBLProxySettings.
enum ProxyType {
  /// HTTP proxy; must support 'CONNECT' method
  http,

  /// HTTPS proxy; must support 'CONNECT' method
  https,
}

/// Proxy settings for the replicator.
class ProxySettings {
  ProxySettings({
    required this.type,
    required this.hostname,
    required this.port,
    this.username,
    required this.password,
  });

  /// Type of proxy
  final ProxyType type;

  /// Proxy server hostname or IP address
  final String hostname;

  /// Proxy server port
  final int port;

  /// Username for proxy auth
  final String? username;

  /// Password for proxy auth
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProxySettings &&
          other.runtimeType == other.runtimeType &&
          type == other.type &&
          hostname == other.hostname &&
          port == other.port &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode =>
      type.hashCode ^
      hostname.hashCode ^
      port.hashCode ^
      username.hashCode ^
      password.hashCode;

  @override
  String toString() => 'ProxySettings('
      'type: $type, '
      'hostname: $hostname, '
      'port: $port, '
      'username: $username, '
      'password: ${redact(password)}'
      ')';
}

/// Direction of replication: push, pull, or both.
enum ReplicatorType {
  /// Bidirectional; both push and pull
  pushAndPull,

  /// Pushing changes to the target
  push,

  /// Pulling changes from the target
  pull,
}

/// The configuration of a replicator.
class ReplicatorConfiguration {
  ReplicatorConfiguration({
    required this.endpoint,
    this.replicatorType,
    this.continuous,
    this.authenticator,
    this.proxy,
    this.headers,
    this.pinnedServerCertificate,
    this.trustedRootCertificates,
    this.channels,
    this.documentIds,
    this.pushFilter,
    this.pullFilter,
    this.conflictResolver,
  });

  /// The address of the other database to replicate with
  final Endpoint endpoint;

  /// The type of the replicator
  ///
  /// The default is [ReplicatorType.pushAndPull].
  final ReplicatorType? replicatorType;

  /// Whether the replicator should work continuously
  ///
  /// The default is `false`.
  final bool? continuous;

  /// Authentication credentials, if needed
  final Authenticator? authenticator;

  /// HTTP client proxy settings
  final ProxySettings? proxy;

  /// Extra HTTP headers to add to the WebSocket request
  final Map<String, String>? headers;

  /// An X.509 cert to "pin" TLS connections to (PEM or DER)
  final Uint8List? pinnedServerCertificate;

  /// Set of anchor certs (PEM format)
  final Uint8List? trustedRootCertificates;

  /// Optional set of channels to pull from
  final List<String>? channels;

  /// Optional set of document ids to replicate
  final List<String>? documentIds;

  /// Optional callback to filter which docs are pushed
  final ReplicationFilter? pushFilter;

  /// Optional callback to validate incoming docs
  final ReplicationFilter? pullFilter;

  /// Optional conflict-resolver callback
  final ConflictResolver? conflictResolver;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplicatorConfiguration &&
          other.runtimeType == other.runtimeType &&
          endpoint == other.endpoint &&
          replicatorType == other.replicatorType &&
          continuous == other.continuous &&
          authenticator == other.authenticator &&
          proxy == other.proxy &&
          headers == other.headers &&
          pinnedServerCertificate == other.pinnedServerCertificate &&
          trustedRootCertificates == other.trustedRootCertificates &&
          channels == other.channels &&
          documentIds == other.documentIds &&
          pushFilter == other.pushFilter &&
          pullFilter == other.pullFilter &&
          conflictResolver == other.conflictResolver;

  @override
  int get hashCode =>
      endpoint.hashCode ^
      replicatorType.hashCode ^
      continuous.hashCode ^
      authenticator.hashCode ^
      proxy.hashCode ^
      headers.hashCode ^
      pinnedServerCertificate.hashCode ^
      trustedRootCertificates.hashCode ^
      channels.hashCode ^
      documentIds.hashCode ^
      pushFilter.hashCode ^
      pullFilter.hashCode ^
      conflictResolver.hashCode;

  @override
  String toString() => 'ReplicatorConfiguration('
      'endpoint: $endpoint, '
      'replicatorType: $replicatorType, '
      'continuous: $continuous, '
      'authenticator: $authenticator, '
      'proxy: $proxy, '
      'headers: $headers, '
      'pinnedServerCertificate: $pinnedServerCertificate, '
      'trustedRootCertificate: $trustedRootCertificates, '
      'channels: $channels, '
      'documentIds: $documentIds, '
      'pushFilter: $pushFilter, '
      'pullFilter: $pullFilter, '
      'conflictResolver: $conflictResolver'
      ')';
}

extension on ReplicatorConfiguration {
  Pointer<CBLEndpoint> createEndpoint() {
    final endpoint = this.endpoint;
    if (endpoint is UrlEndpoint) {
      return _bindings.createEndpointWithUrl(endpoint.url.toString());
    } else {
      throw UnimplementedError('Endpoint type is not implemented: $endpoint');
    }
  }

  Pointer<CBLAuthenticator>? createAuthenticator() {
    final authenticator = this.authenticator;
    if (authenticator == null) return null;

    if (authenticator is BasicAuthenticator) {
      return _bindings.createPasswordAuthenticator(
        authenticator.username,
        authenticator.password,
      );
    } else if (authenticator is SessionAuthenticator) {
      return _bindings.createSessionAuthenticator(
        authenticator.sessionId,
        authenticator.cookieName,
      );
    } else {
      throw UnimplementedError(
        'Authenticator type is not implemented: $authenticator',
      );
    }
  }
}

/// A fractional progress value, ranging from 0.0 to 1.0 as replication
/// progresses.
///
/// The value is very approximate and may bounce around during replication;
/// making it more accurate would require slowing down the replicator and
/// incurring more load on the server. It's fine to use in a progress bar,
/// though.
class ReplicatorProgress {
  ReplicatorProgress(this.fractionComplete, this.documentCount);

  /// Very-approximate completion, from 0.0 to 1.0
  final double fractionComplete;

  /// Number of documents transferred so far
  final int documentCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplicatorProgress &&
          other.runtimeType == other.runtimeType &&
          fractionComplete == other.fractionComplete &&
          documentCount == other.documentCount;

  @override
  int get hashCode => fractionComplete.hashCode ^ documentCount.hashCode;

  @override
  String toString() => 'ReplicatorProgress('
      'fractionComplete: $fractionComplete, '
      'documentCount: $documentCount'
      ')';
}

/// The possible states a replicator can be in during its lifecycle.
enum ReplicatorActivityLevel {
  /// The replicator is unstarted, finished, or hit a fatal error.
  stopped,

  /// The replicator is offline, as the remote host is unreachable.
  offline,

  /// The replicator is connecting to the remote host.
  connecting,

  /// The replicator is inactive, waiting for changes to sync.
  idle,

  /// The replicator is actively transferring data.
  busy,
}

extension on CBLReplicatorActivityLevel {
  ReplicatorActivityLevel toReplicatorActivityLevel() =>
      ReplicatorActivityLevel.values[index];
}

/// A [Replicator]'s current status
class ReplicatorStatus {
  ReplicatorStatus(this.activity, this.progress, this.error);

  /// Current state
  final ReplicatorActivityLevel activity;

  /// Approximate fraction complete
  final ReplicatorProgress progress;

  /// Error, if any
  final BaseException? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplicatorStatus &&
          other.runtimeType == other.runtimeType &&
          activity == other.activity &&
          progress == other.progress &&
          error == other.error;

  @override
  int get hashCode => activity.hashCode ^ progress.hashCode ^ error.hashCode;

  @override
  String toString() => 'ReplicatorStatus('
      'activity: $activity, '
      'progress: $progress, '
      'error: $error'
      ')';
}

/// Flags describing a replicated document.
enum ReplicatedDocumentFlag {
  /// The document has been deleted.
  deleted,

  /// Lost access to the document on the server
  accessRemoved,
}

extension on CBLReplicatedDocumentFlag {
  ReplicatedDocumentFlag toReplicatedDocumentFlag() => ReplicatedDocumentFlag
      .values[CBLReplicatedDocumentFlag.values.indexOf(this)];
}

/// Information about a [Document] that's been pushed or pulled.
class ReplicatedDocument {
  ReplicatedDocument(this.id, this.flags, this.error);

  /// The document's [id].
  final String id;

  /// Indicates whether the document was deleted or removed
  final Set<ReplicatedDocumentFlag> flags;

  /// If not `null`, the document failed to replicate.
  final BaseException? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplicatedDocument &&
          other.runtimeType == other.runtimeType &&
          id == other.id &&
          const DeepCollectionEquality().equals(flags, other.flags) &&
          error == other.error;

  @override
  int get hashCode =>
      id.hashCode ^ const DeepCollectionEquality().hash(flags) ^ error.hashCode;

  @override
  String toString() => 'ReplicatedDocument('
      'id: $id, '
      'flags: $flags, '
      'error: $error'
      ')';
}

extension on CBLDart_ReplicatedDocument {
  ReplicatedDocument toReplicatedDocument() => ReplicatedDocument(
        ID,
        flags.map((flag) => flag.toReplicatedDocumentFlag()).toSet(),
        exception?.translate(),
      );
}

/// The direction in which documents may be replicated.
enum ReplicationDirection {
  /// Documents are push from a local to a remote database.
  push,

  /// Documents are pulled from a remote to a local database.
  pull,
}

/// An event that is emitted when [Document]s have been replicated.
class DocumentsReplicated {
  DocumentsReplicated(this.direction, this.documents);

  /// The direction in which [documents] have been replicated.
  final ReplicationDirection direction;

  /// A list with information about each document.
  final List<ReplicatedDocument> documents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentsReplicated &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          const DeepCollectionEquality().equals(documents, other.documents);

  @override
  int get hashCode =>
      direction.hashCode ^ const DeepCollectionEquality().hash(documents);

  @override
  String toString() => 'DocumentsReplicated('
      'direction: $direction, '
      'documents: $documents'
      ')';
}

/// A replicator is a background task that synchronizes changes between a local
/// database and another database on a remote server (or on a peer device, or
/// even another local database.)
abstract class Replicator extends NativeResource<WorkerObject<CBLReplicator>>
    implements ClosableResource {
  Replicator._(WorkerObject<CBLReplicator> native) : super(native);

  /// The database this replicator is pulling changes into and pushing changes
  /// out of.
  Database get database;

  /// Starts this replicator, asynchronously.
  ///
  /// Does nothing if it's already started.
  Future<void> start();

  /// Stops a running replicator, asynchronously.
  ///
  /// Does nothing if it's not already started.
  ///
  /// The [Stream] returned from [statusChanges] will emit a [ReplicatorStatus]
  /// with an activity level of [ReplicatorActivityLevel.stopped] after it
  /// stops. Until then, consider it still active.
  Future<void> stop();

  /// Informs this replicator whether it's considered possible to reach the
  /// remote host with the current network configuration.
  ///
  /// The default value is `true`. This only affects the [Replicator]'s behavior
  /// while it's in the Offline state:
  /// * Setting it to false will cancel any pending retry and prevent future
  ///   automatic retries.
  /// * Setting it back to true will initiate an immediate retry.
  Future<void> setHostReachable(bool reachable);

  /// Puts this replicator in or out of "suspended" state.
  ///
  /// The default is false.
  ///
  /// * Setting [suspended] to `true` causes the replicator to disconnect and
  ///   enter Offline state; it will not attempt to reconnect while it's
  ///   suspended.
  /// * Setting [suspended] ot `false` causes the replicator to attempt to
  ///   reconnect, _if_ it was connected when suspended, and is still in Offline
  ///   state.
  Future<void> setSuspended(bool suspended);

  /// Returns this [Replicator]'s current status.
  Future<ReplicatorStatus> status();

  /// Returns a stream that emits this replicators [ReplicatorStatus] when the
  /// it changes.
  Stream<ReplicatorStatus> statusChanges();

  /// Indicates which documents have local changes that have not yet been pushed
  /// to the server by this replicator.
  ///
  /// This is of course a snapshot, that will go out of date as the replicator
  /// makes progress and/or documents are saved locally.
  ///
  /// The result is, effectively, a set of document ids: a dictionary whose keys
  /// are the ids and values are `true`.
  ///
  /// If there are no pending documents, the dictionary is empty.
  ///
  /// This function can be called on a stopped or un-started replicator.
  ///
  /// Documents that would never be pushed by this replicator, due to its
  /// configuration's [ReplicatorConfiguration.pushFilter] or
  /// [ReplicatorConfiguration.documentIds], are ignored.
  Future<Dict> pendingDocumentIds();

  /// Indicates whether the document with the given id has local changes that
  /// have not yet been pushed to the server by this replicator.
  ///
  /// This is equivalent to, but faster than, calling [pendingDocumentIds] and
  /// checking whether the result contains [id]. See that function's
  /// documentation for details.
  ///
  /// A `false` result means the document is not pending.
  Future<bool> isDocumentPending(String id);

  /// Returns a stream that emits [DocumentsReplicated]s when [Document]s
  /// have been replicated.
  Stream<DocumentsReplicated> documentReplications();
}

class ReplicatorImpl extends Replicator with ClosableResourceMixin {
  ReplicatorImpl({
    required this.database,
    required Pointer<CBLReplicator> pointer,
    required void Function() disposeCallbacks,
    required String? debugCreator,
  })  : _disposeCallbacks = disposeCallbacks,
        super._(CBLReplicatorObject(
          pointer,
          worker: database.native.worker,
          debugName: 'Replicator(creator: $debugCreator)',
        )) {
    database.registerChildResource(this);
  }

  final void Function() _disposeCallbacks;

  @override
  final DatabaseImpl database;

  @override
  Future<void> start() =>
      use(() => native.execute((pointer) => StartReplicator(pointer, false)));

  @override
  Future<void> stop() => use(_stop);

  Future<void> _stop() => native.execute((pointer) => StopReplicator(pointer));

  @override
  Future<void> setHostReachable(bool reachable) => use(() => native
      .execute((pointer) => SetReplicatorHostReachable(pointer, reachable)));

  @override
  Future<void> setSuspended(bool suspended) =>
      use(() => native.execute((pointer) => SetReplicatorSuspended(
            pointer,
            suspended,
          )));

  @override
  Future<ReplicatorStatus> status() => use(_status);

  Future<ReplicatorStatus> _status() =>
      native.execute((pointer) => GetReplicatorStatus(pointer));

  @override
  Stream<ReplicatorStatus> statusChanges() => useSync(_statusChanges);

  Stream<ReplicatorStatus> _statusChanges() =>
      CallbackStreamController<ReplicatorStatus, void>(
        parent: this,
        worker: native.worker,
        createRegisterCallbackRequest: (callback) =>
            AddReplicatorChangeListener(
          native.pointerUnsafe,
          callback.native.pointerUnsafe,
        ),
        // The native caller allocates some memory for the arguments and blocks
        // until the Dart side copies them and finishes the call, so it can
        // free the memory.
        finishBlockingCall: true,
        createEvent: (_, arguments) {
          final message =
              ReplicatorStatusCallbackMessage.fromArguments(arguments);
          return message.status.ref.toReplicatorStatus();
        },
      ).stream;

  @override
  Future<Dict> pendingDocumentIds() => use(() => native
      .execute((pointer) => GetReplicatorPendingDocumentIds(pointer))
      .then((result) => Dict.fromPointer(
            result.pointer,
            release: true,
            retain: false,
          )));

  @override
  Future<bool> isDocumentPending(String id) => use(() =>
      native.execute((pointer) => GetReplicatorIsDocumentPening(pointer, id)));

  @override
  Stream<DocumentsReplicated> documentReplications() =>
      useSync(() => CallbackStreamController(
            parent: this,
            worker: native.worker,
            createRegisterCallbackRequest: (callback) =>
                AddReplicatorDocumentListener(
              native.pointerUnsafe,
              callback.native.pointerUnsafe,
            ),
            // See `statusChanges` for an explanation of why this option is `true`.
            finishBlockingCall: true,
            createEvent: (_, arguments) {
              final message =
                  DocumentReplicationsCallbackMessage.fromArguments(arguments);

              final direction = message.isPush
                  ? ReplicationDirection.push
                  : ReplicationDirection.pull;

              final documents = List.generate(
                message.documentCount,
                (index) => message.documents.elementAt(index),
              ).map((it) => it.ref.toReplicatedDocument()).toList();

              return DocumentsReplicated(direction, documents);
            },
          ).stream);

  @override
  Future<void> performClose() async {
    await _stop();

    final statusStream = changeStreamWithInitialValue(
      createInitialValue: _status,
      createChangeStream: _statusChanges,
    );

    await for (final status in statusStream) {
      if (status.activity == ReplicatorActivityLevel.stopped) {
        break;
      }
    }

    _disposeCallbacks();
  }

  @override
  String toString() => 'Replicator()';
}
