import 'dart:async';
import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart' hide Libraries, LibraryConfiguration;
import 'package:cbl_ffi/cbl_ffi.dart' as ffi;
import 'package:logging/logging.dart';

import 'blob.dart';
import 'document/common.dart';
import 'fleece/integration/integration.dart';
import 'fleece.dart';
import 'streams.dart';
import 'utils.dart';
import 'worker/cbl_worker.dart';

/// Configuration of a [DynamicLibrary], which can be used to load the
/// `DynamicLibrary` at a later time.
class LibraryConfiguration {
  /// Creates a configuration for a dynamic library opened with
  /// [DynamicLibrary.open].
  ///
  /// If [appendExtension] is `true` (default), the file extension which is used
  /// for dynamic libraries on the current platform is appended to [name].
  LibraryConfiguration.dynamic(String name, {bool appendExtension = true})
      : process = null,
        name = name,
        appendExtension = appendExtension;

  /// Creates a configuration for a dynamic library opened with
  /// [DynamicLibrary.process].
  LibraryConfiguration.process()
      : process = true,
        name = null,
        appendExtension = null;

  /// Creates a configuration for a dynamic library opened with
  /// [DynamicLibrary.executable].
  LibraryConfiguration.executable()
      : process = false,
        name = null,
        appendExtension = null;

  final bool? process;
  final String? name;
  final bool? appendExtension;

  ffi.LibraryConfiguration _toFfi() => ffi.LibraryConfiguration(
        process: process,
        name: name,
        appendExtension: appendExtension,
      );
}

/// The [DynamicLibrary]s which provide the Couchbase Lite C API and the Dart
/// support layer.
class Libraries {
  Libraries({
    this.enterpriseEdition = false,
    required LibraryConfiguration cbl,
    required LibraryConfiguration cblDart,
  })  : cbl = cbl,
        cblDart = cblDart;

  final LibraryConfiguration cbl;
  final LibraryConfiguration cblDart;

  /// Whether the provided Couchbase Lite C library is the enterprise edition.
  final bool enterpriseEdition;

  ffi.Libraries _toFfi() => ffi.Libraries(
        enterpriseEdition: enterpriseEdition,
        cbl: cbl._toFfi(),
        cblDart: cblDart._toFfi(),
      );
}

/// Subsystems that log information.
enum LogDomain {
  all,
  database,
  query,
  replicator,
  network,
}

extension on CBLLogDomain {
  LogDomain toLogDomain() => LogDomain.values[index];
}

/// Levels of log messages. Higher values are more important/severe. Each level
/// includes the lower ones.
enum LogLevel {
  /// Extremely detailed messages, only written by debug builds of CBL.
  debug,

  /// Detailed messages about normally-unimportant stuff.
  verbose,

  /// Messages about ordinary behavior.
  info,

  /// Messages warning about unlikely and possibly bad stuff.
  warning,

  /// Messages about errors
  error,

  /// Disables logging entirely.
  none
}

extension on CBLLogLevel {
  LogLevel toLogLevel() => LogLevel.values[index];
}

extension on LogLevel {
  CBLLogLevel toCBLLogLevel() => CBLLogLevel.values[index];
}

/// A entry, which is emitted when CouchbaseLite logs a message.
///
/// See:
/// - [CouchbaseLite.logMessages] for how to listen to log messages.
class LogMessage {
  LogMessage({
    required this.level,
    required this.domain,
    required this.message,
  });

  /// The level at which this message is emitted, allowing you to filter them
  /// based on urgency.
  final LogLevel level;

  /// The [domain] of the CouchbaseLite implementation this message comes from.
  final LogDomain domain;

  /// The logged message.
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogMessage &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          domain == other.domain &&
          message == other.message;

  @override
  int get hashCode => level.hashCode ^ domain.hashCode ^ message.hashCode;

  @override
  String toString() => 'LogMessage('
      'level: $level, '
      'domain: $domain, '
      'message: $message '
      ')';
}

/// Extension to map between CouchbaseLite's [LogLevel] and `logging`s [Level].
extension LogLevelExt on LogLevel {
  /// Returns a [Level] from the `logging` package which corresponds to this
  /// CouchbaseLite log level.
  Level toLoggingLevel() {
    switch (this) {
      case LogLevel.verbose:
        return Level.FINER;
      case LogLevel.debug:
        return Level.FINE;
      case LogLevel.info:
        return Level.INFO;
      case LogLevel.warning:
        return Level.WARNING;
      case LogLevel.error:
        return Level.SEVERE;
      case LogLevel.none:
        throw UnsupportedError('LogLevel.none has not mapping to Level');
    }
  }
}

/// Extension for logging [LogMessage]s to [Logger]s.
extension LogMessageLoggerExtension on Logger {
  /// Logs [logMessage] to this logger.
  void logLogMessage(LogMessage logMessage) => log(
        logMessage.level.toLoggingLevel(),
        '${describeEnum(logMessage.domain)}: ${logMessage.message}',
      );
}

extension LogMessageStreamExtension on Stream<LogMessage> {
  /// Adds a subscription to to this stream which logs the emitted [LogMessage]s
  /// to [logger].
  ///
  /// If [logger] is not provided a new `Logger` with name 'CBL' will be created
  /// and used.
  StreamSubscription<LogMessage> logToLogger([Logger? logger]) {
    logger ??= Logger('CBL');
    return listen((logMessage) => logger!.logLogMessage(logMessage));
  }
}

bool _isInitialized = false;

void debugCouchbaseLiteIsInitialized() {
  assert(!_isInitialized, 'CouchbaseLite.initialize has not been called.');
}

late WorkerFactory _workerFactory;

/// The global worker factory used by all resources which need to create
/// workers.
WorkerFactory get workerFactory {
  debugCouchbaseLiteIsInitialized();
  return _workerFactory;
}

/// Initializes global resources and configures global settings, such as
/// logging.
class CouchbaseLite {
  /// Initializes the `cbl` package.
  static void initialize({required Libraries libraries}) {
    final ffiLibraries = libraries._toFfi();

    CBLBindings.initInstance(ffiLibraries);

    SlotSetter.register(blobSlotSetter);

    MDelegate.instance = CblMDelegate();

    _workerFactory = CblWorkerFactory(libraries: ffiLibraries);
  }

  /// Private constructor to allow control over instance creation.
  CouchbaseLite._();

  static late final _logBindings = CBLBindings.instance.logging;

  /// The current LogLevel of all of CouchbaseLite.
  ///
  /// Messages below this level will not be sent to the [logMessages] or the
  /// default log callback.
  ///
  /// It is not possible to configure logging individually for objects such as
  /// databases or replicators.
  ///
  /// See:
  /// - [logMessages] to handle log messages in Dart.
  /// - [loggingIsDisabled] for completely disabling logging completely.
  static LogLevel get logLevel => _logBindings.consoleLevel().toLogLevel();

  static set logLevel(LogLevel level) =>
      _logBindings.setConsoleLevel(level.toCBLLogLevel());

  static bool _loggingIsDisabled = false;

  /// Whether logging is completely disabled.
  ///
  /// [logMessages] cannot be listened to while logging is disabled and while
  /// [logMessages] has listeners, logging cannot be disabled.
  static bool get loggingIsDisabled => _loggingIsDisabled;

  static set loggingIsDisabled(bool disabled) {
    if (_loggingIsDisabled == disabled) return;

    _loggingIsDisabled = disabled;

    if (disabled) {
      assert(
        !_logMessagesController.hasListener,
        'logging cannot be be disabled while `logMessage` stream has listeners',
      );

      _logBindings.setCallback(nullptr);
    } else {
      _logBindings.restoreOriginalCallback();
    }
  }

  static late final _logMessagesController =
      callbackBroadcastStreamController<LogMessage>(
    startStream: (callback) {
      assert(
        !_loggingIsDisabled,
        '`logMessages` stream cannot be listened to while `loggingIsDisable` '
        'is `true`',
      );

      _logBindings.setCallback(callback.native.pointerUnsafe);
    },
    createEvent: (arguments) {
      final message = LogCallbackMessage.fromArguments(arguments);
      return LogMessage(
        level: message.level.toLogLevel(),
        domain: message.domain.toLogDomain(),
        message: message.message,
      );
    },
  );

  /// Broadcast stream which emits [LogMessage]s from the CouchbaseLite
  /// implementation.
  ///
  /// If [loggingIsDisabled] is `false` and this stream has no listeners the
  /// default consoler logger of the CouchbaseLite implementation will be used.
  ///
  /// Listening to this stream allows you to replace the default console logger
  /// with your own logging implementation.
  ///
  /// See:
  /// - [loggingIsDisabled] for how that property interacts with this stream.
  static Stream<LogMessage> logMessages() => _logMessagesController.stream;
}
