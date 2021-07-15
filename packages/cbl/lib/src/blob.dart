// ignore_for_file: comment_references

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import 'database.dart';
import 'fleece/containers.dart';
import 'native_object.dart';
import 'resource.dart';
import 'streams.dart';
import 'utils.dart';
import 'worker/cbl_worker.dart';

late final _blobBindings = CBLBindings.instance.blobs.blob;

/// A binary data value associated with a [Document].
///
/// The content of the Blob is not stored in the Document, but externally in the
/// [Database]. It is loaded only on demand, and can be streamed. Blobs can be
/// arbitrarily large, although Sync Gateway will only accept Blobs under 20MB.
///
/// The document contains only a Blob reference: a dictionary with the special
/// marker property `"@type":"blob"`, and another property `digest` whose value
/// is a hex SHA-1 digest of the Blob's data. This digest is used as the key to
/// retrieve the Blob data. The dictionary usually also has the property
/// `length`, containing the Blob's length in bytes, and it may have the
/// property `content_type`, containing a MIME type.
///
/// A Blob object acts as a proxy for such a dictionary in a [Document]. Once
/// you've loaded a Document and located the [Dict] holding the Blob reference,
/// call [ValueBlobExtension]`.blob` on it to create a Blob object you can call.
/// The object has accessors for the Blob's metadata. To access the content of
/// the Blob use [BlobManager.blobContent] or
/// [BlobManager.readStream].
///
/// To create a new Blob from in-memory data, call [BlobManager.createBlob],
/// then add the Blob to a dictionary or array property of the Document.
///
/// To create a new Blob from a stream, call [BlobManager.openWriteStream]
/// to create a [BlobWriteStream], then make one or more calls to
/// [BlobWriteStream.addStream] to write data to the Blob, then finally call
/// [BlobWriteStream.createBlob] to create the blob.
///
/// See:
/// - [BlobWriteStream] for writing a Blob in chunks.
/// - [BlobManager] for the entry point to reading and writing Blob.
class Blob extends NativeResource<NativeObject<CBLBlob>> {
  Blob._(
    Pointer<CBLBlob> pointer, {
    required bool retain,
    required String? debugCreator,
  }) : super(CblRefCountedObject(
          pointer,
          release: true,
          retain: retain,
          debugName: 'Blob(creator: $debugCreator)',
        ));

  /// The length in bytes of this Blob's content (from its `length` property).
  int get length => _blobBindings.length(native.pointerUnsafe);

  /// The cryptographic digest of this Blob's content (from its `digest`
  /// property).
  String get digest => _blobBindings.digest(native.pointerUnsafe);

  /// This Blob's MIME type, if its metadata has a `content_type` property.
  String? get contentType => _blobBindings.contentType(native.pointerUnsafe);

  /// This Blob's metadata. This includes the `digest`, `length` and
  /// `content_type` properties, as well as any custom ones that may have been
  /// added.
  MutableDict get properties => MutableDict.fromPointer(
        _blobBindings.properties(native.pointerUnsafe).cast(),
        release: true,
        retain: true,
      );
}

late final blobSlotSetter = _BlobSlotSetter();

class _BlobSlotSetter implements SlotSetter {
  @override
  bool canSetValue(Object? value) => value is Blob;

  @override
  void setSlotValue(Pointer<FLSlot> slot, Object? value) =>
      _blobBindings.setBlob(slot, (value as Blob).native.pointerUnsafe);
}

/// Extension to get a [Blob] from a [Dict].
extension DictBlobExtension on Dict {
  /// Returns true if this Dict in a [Document] is a blob reference.
  ///
  /// If so, you can use [asBlob] to access it.
  bool get isBlob => _blobBindings.isBlob(native.pointerUnsafe.cast());

  /// Instantiates a [Blob] object corresponding to a Blob dictionary in a
  /// [Document].
  ///
  /// Returns `null` if this Dict is not a Blob.
  Blob? get asBlob =>
      _blobBindings.getBlob(native.pointerUnsafe.cast())?.let((it) => Blob._(
            it,
            retain: true,
            debugCreator: 'Dict.asBlob',
          ));
}

/// Extension to get a [Blob] from a [Value].
extension ValueBlobExtension on Value {
  /// Returns true if this Value in a [Document] is a blob reference.
  ///
  /// If so, you can use [asBlob] to access it.
  bool get isBlob => asDict?.isBlob ?? false;

  /// Instantiates a [Blob] object corresponding to a Blob dictionary in a
  /// [Document].
  ///
  /// Returns `null` if this Value is not a Blob.
  Blob? get asBlob => asDict?.asBlob;
}

/// A stream for writing a new [Blob] to the [Database].
///
/// You should call [addStream] one or more times to write the data, then
/// [createBlob] to create the Blob. [addStream] consumes a [Stream] of chunks
/// of data and completes the returned [Future] when all the data from the
/// Stream has been written. You must not call [addStream] again before the
/// Future from the last call has completed.
///
/// If for some reason you need to abort, call [close].
abstract class BlobWriteStream
    implements StreamConsumer<Uint8List>, ClosableResource {
  /// Writes the chunks in [stream] to this stream.
  ///
  /// You must not call this method again until the returned [Future] completes.
  ///
  /// The first time [stream] emits an error, the subscription to it is canceled
  /// and the returned Future rejects with the error.
  ///
  /// If there is an error writing a chunk the subscription to [stream] is
  /// canceled and the returned Future rejects with the error.
  ///
  /// Even if the returned Future rejects, you have to call [close] if you are
  /// not going to finish the stream with a call to [createBlob].
  @override
  Future<void> addStream(Stream<Uint8List> stream);

  /// Closes this stream, if you need to give up without creating a [Blob].
  @override
  Future<void> close();

  /// Creates a new [Blob] after its content has been written to this stream.
  ///
  /// You should then add the Blob to a [MutableDocument] as a property.
  ///
  /// [contentType] is the MIME type of the data written to this stream.
  Future<Blob> createBlob({String? contentType});
}

class _BlobWriteStream
    extends NativeResource<SimpleWorkerObject<CBLBlobWriteStream>>
    with ClosableResourceMixin
    implements BlobWriteStream {
  _BlobWriteStream(
    BlobManagerImpl blobManager,
    Pointer<CBLBlobWriteStream> pointer,
  ) : super(SimpleWorkerObject(pointer, blobManager.native.worker)) {
    blobManager.registerChildResource(this);
  }

  @override
  Future<void> addStream(Stream<Uint8List> stream) => use(() => stream
      .asyncMap((chunk) =>
          native.execute((pointer) => WriteToBlobWriteStream(pointer, chunk)))
      .drain());

  @override
  Future<Blob> createBlob({String? contentType}) => closeAndUse(
        () async {
          final result =
              await native.execute((pointer) => CreateBlobWithWriteStream(
                    pointer,
                    contentType,
                  ));

          return Blob._(
            result.pointer,
            retain: false,
            debugCreator: 'BlobWriteStream.createBlob()',
          );
        },
        doPerformClose: false,
      );

  @override
  Future<void> performClose() =>
      native.execute((pointer) => CloseBlobWriteStream(pointer));
}

class _BlobReadStreamController
    extends ClosableResourceStreamController<Uint8List> {
  _BlobReadStreamController({
    required AbstractResource parent,
    required this.worker,
    required this.blob,
    required this.chunkSize,
  }) : super(parent: parent);

  final Worker worker;
  final Blob blob;
  final int chunkSize;

  Future<void>? _setupDone;
  late Pointer<CBLBlobReadStream> _streamPointer;
  var _isPaused = false;

  @override
  Future<void> onListen() => _start();

  @override
  void onPause() => _pause();

  @override
  void onResume() => _start();

  @override
  Future<void> onCancel() async {
    _pause();
    await _cleanUp();
  }

  Future<void> _setup() async {
    _streamPointer = await runKeepAlive(() => worker
        .execute(OpenBlobReadStream(blob.native.pointer, chunkSize))
        .then((result) => result.pointer));
  }

  Future<void> _cleanUp() async {
    await _setupDone;

    await worker.execute(CloseBlobReadStream(_streamPointer));
  }

  Future<void> _start() async {
    try {
      _isPaused = false;

      await (_setupDone ??= _setup());

      while (!_isPaused) {
        final buffer =
            await worker.execute(ReadFromBlobReadStream(_streamPointer));

        // The read stream is done (EOF).
        if (buffer == null) {
          await controller.close();
          break;
        }

        controller.add(Uint8List.fromList(buffer.bytes));
      }
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      await controller.close();
    }
  }

  void _pause() => _isPaused = true;
}

/// Manage reading and writing of [Blob]s.
///
/// See:
/// - [Database.blobManager] to get the [BlobManager] instance associated with
///   a Database.
abstract class BlobManager {
  /// Opens a [BlobWriteStream] for writing a new [Blob].
  ///
  /// You have to either use the returned stream to [BlobWriteStream.createBlob]
  /// or [BlobWriteStream.close] it, to free the resources used by it.
  ///
  /// See:
  /// - [BlobWriteStream] for how to add data to the stream and finally create
  ///   the new Blob.
  Future<BlobWriteStream> openWriteStream();

  /// Creates a new blob given its [content] as a single chunk of data.
  ///
  /// [contentType] is the MIME type of the data in [content].
  Future<Blob> createBlob(Uint8List content, {String? contentType});

  /// Returns a stream for reading a [Blob]'s content in chunks.
  ///
  /// The maximum size of the emitted chunks can be controlled through
  /// [chunkSize].
  ///
  /// The returned Stream only starts reading after a subscription has been
  /// created and can only be listened to once.
  Stream<Uint8List> readStream(Blob blob, {int chunkSize = 4096});

  /// Reads the [Blob]'s contents into memory and returns them.
  Future<Uint8List> blobContent(Blob blob);
}

class BlobManagerImpl extends NativeResource<WorkerObject<CBLDatabase>>
    with DelegatingResourceMixin
    implements BlobManager {
  BlobManagerImpl(this.database) : super(database.native) {
    database.registerChildResource(this);
  }

  final DatabaseImpl database;

  @override
  Future<BlobWriteStream> openWriteStream() => use(() => native
      .execute((pointer) => OpenBlobWriteStream(pointer))
      .then((result) => _BlobWriteStream(this, result.pointer)));

  @override
  Future<Blob> createBlob(Uint8List content, {String? contentType}) =>
      use(() async {
        final writeStream = await openWriteStream();
        await writeStream.addStream(Stream.value(content));
        return writeStream.createBlob(contentType: contentType);
      });

  @override
  Stream<Uint8List> readStream(Blob blob, {int chunkSize = 4096}) =>
      useSync(() => _BlobReadStreamController(
            parent: this,
            worker: native.worker,
            blob: blob,
            chunkSize: chunkSize,
          ).stream);

  @override
  Future<Uint8List> blobContent(Blob blob) =>
      use(() => readStream(blob).toList().then(jointUint8Lists));
}
