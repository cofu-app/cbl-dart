import 'dart:async';
import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import 'worker/worker.dart';

/// Keeps a [NativeObject] alive while the [Function] [fn] is running.
///
/// If [fn] returns a [Future] [object] is kept alive until the future
/// completes.
T keepAlive<P extends NativeType, T>(
  NativeObject<P> object,
  T Function(Pointer<P> pointer) fn,
) {
  assert(() {
    object._debugKeepAliveRefCount++;
    return true;
  }());

  final result = fn(object.pointer);

  if (result is Future) {
    return result.whenComplete(() {
      assert(() {
        object._debugKeepAliveRefCount--;
        return true;
      }());
      _keepAliveUntil(object);
    }) as T;
  }

  assert(() {
    object._debugKeepAliveRefCount--;
    return true;
  }());
  _keepAliveUntil(object);
  return result;
}

final _keepAlive = keepAlive;

extension KeepAliveExtension<P extends NativeType> on NativeObject<P> {
  /// Keeps this [NativeObject] alive while the [Function] [fn] is running.
  ///
  /// If [fn] returns a [Future] this object is kept alive until the future
  /// completes.
  R keepAlive<R>(R Function(Pointer<P> pointer) fn) => _keepAlive(this, fn);
}

@pragma('vm:never-inline')
void _keepAliveUntil(Object? object) {}

/// Runs [body] while keeping accessed [NativeObject]s alive.
///
/// A native object keep alive is a [Zone], in which [NativeObject] are
/// recorded when their [NativeObject.pointer] property has been accessed.
///
/// When accessing [NativeObject.pointer] and using it, the
/// native object needs to stay alive while its pointer is being used. While
/// the pointer to the native object is used, the [NativeObject] can be garbage
/// collected too early. In this case native finalizers are executed while work
/// is ongoing. To prevent this condition, a native object keep alive creates
/// references to [NativeObject]s, whose pointers have been accessed. This keeps
/// them from being garbage collected while their pointers are being used.
T runKeepAlive<T>(T Function() body) => runZoned(
      body,
      zoneValues: {#_aliveNativeObjects: <NativeObject>{}},
    );

Set<NativeObject>? get _aliveNativeObjects =>
    Zone.current[#_aliveNativeObjects] as Set<NativeObject>?;

/// Represents an object on the native side.
///
/// The lifetime of the native object is determined by the lifetime of this
/// object.
class NativeObject<T extends NativeType> {
  NativeObject(Pointer<T> pointer) : _pointer = pointer;

  final Pointer<T> _pointer;

  var _debugKeepAliveRefCount = 0;

  /// The pointer to the native object.
  ///
  /// Code which access this property must be run in a
  /// [runKeepAlive].
  Pointer<T> get pointer {
    final aliveNativeObjects = _aliveNativeObjects;

    assert(
      _debugKeepAliveRefCount > 0 || aliveNativeObjects != null,
      'NativeObject.pointer must to be accessed from within `keepAlive` or'
      ' `runKeepAlive`',
    );

    aliveNativeObjects?.add(this);

    return _pointer;
  }

  /// The pointer to the native object, without requiring a native object keep
  /// alive.
  ///
  /// Callers must guarantee that the returned pointer is only used while this
  /// object has not been garbage collected.
  ///
  /// See:
  /// - [runKeepAlive] for what a native object keep alive is.
  Pointer<T> get pointerUnsafe => _pointer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeObject &&
          runtimeType == other.runtimeType &&
          _pointer.address == other._pointer.address;

  @override
  int get hashCode => _pointer.address.hashCode;
}

/// A native object, whose operations are executed in a [Worker].
mixin WorkerObject<T extends NativeType> on NativeObject<T> {
  /// The worker on which operations of this object are executed.
  Worker get worker;

  /// Executes an operation of this object on [worker] and returns the result.
  ///
  /// The call to [createRequest] is wrapped in [runKeepAlive].
  ///
  /// [createRequest] is passed the address of this object as an `int` and
  /// has to return the [WorkerRequest] to be executed.
  Future<R> execute<R>(
    FutureOr<WorkerRequest<R>> Function(Pointer<T> pointer) createRequest,
  ) =>
      runKeepAlive(() async {
        return worker.execute(await createRequest(pointer));
      });
}

class SimpleWorkerObject<T extends NativeType> extends NativeObject<T>
    with WorkerObject {
  SimpleWorkerObject(Pointer<T> pointer, this.worker) : super(pointer);

  @override
  final Worker worker;
}

/// Represents a reference to a CouchbaseLite C API object that is reference
/// counted.
class CblRefCountedObject<T extends NativeType> extends NativeObject<T> {
  /// Creates a reference to a reference counted native CouchbaseLite C API
  /// object.
  ///
  /// When [release] is `true`, the reference count of the native object
  /// will be decremented when the Dart object is garbage collected.
  ///
  /// When [retain] is `true`, the reference count of the native object
  /// will be increment as part of creating the Dart object.
  CblRefCountedObject(
    Pointer<T> pointer, {
    required bool release,
    required bool retain,
    required String? debugName,
  }) : super(pointer) {
    assert(!retain || release, 'only a retained object can be released');

    if (release) {
      CBLBindings.instance.base.bindCBLRefCountedToDartObject(
        this,
        pointer.cast(),
        retain,
        debugName,
      );
    }
  }
}

/// A [CblRefCountedObject] which is also a [WorkerObject].
class CblRefCountedWorkerObject<T extends NativeType>
    extends CblRefCountedObject<T> with WorkerObject {
  CblRefCountedWorkerObject(
    Pointer<T> pointer,
    this.worker, {
    required bool release,
    required bool retain,
    required String? debugName,
  }) : super(
          pointer,
          release: release,
          retain: retain,
          debugName: debugName,
        );

  @override
  final Worker worker;
}

/// Represents a reference to a CBLReplicator.
class CBLReplicatorObject extends NativeObject<CBLReplicator>
    with WorkerObject {
  /// Creates a reference to a CBLReplicator.
  CBLReplicatorObject(
    Pointer<CBLReplicator> pointer, {
    required this.worker,
    required String? debugName,
  }) : super(pointer) {
    CBLBindings.instance.replicator
        .bindReplicatorToDartObject(this, pointer, debugName);
  }

  @override
  final Worker worker;
}

/// Represents a reference to a Fleece document.
class FleeceDocObject extends NativeObject<FLDoc> {
  /// Creates a reference to a Fleece document.
  FleeceDocObject(Pointer<FLDoc> pointer) : super(pointer) {
    CBLBindings.instance.fleece.doc.bindToDartObject(this, pointer);
  }
}

/// Represents a reference to a Fleece value that is reference counted.
class FleeceRefCountedObject<T extends NativeType> extends NativeObject<T> {
  /// Creates a reference to a Fleece value that is reference counted.
  ///
  /// When [release] is `true`, the reference count of the native object
  /// will be decremented when the Dart object is garbage collected.
  ///
  /// When [retain] is `true`, the reference count of the native object
  /// will be increment as part of creating the Dart object.
  FleeceRefCountedObject(
    Pointer<T> pointer, {
    required bool release,
    required bool retain,
  }) : super(pointer) {
    assert(
      !(retain && !release),
      'only an object which will be released can be retained',
    );

    if (release) {
      CBLBindings.instance.fleece.value.bindToDartObject(
        this,
        pointer.cast(),
        retain,
      );
    }
  }
}
