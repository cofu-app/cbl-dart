import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../fleece/decoder.dart';
import '../fleece/encoder.dart';
import '../fleece/integration/integration.dart';
import 'array.dart';
import 'blob.dart';
import 'dictionary.dart';

late final _blobBindings = CBLBindings.instance.blobs.blob;

abstract class MCollectionWrapper {
  MCollection get mCollection;
}

abstract class FleeceEncodable {
  void encodeTo(FleeceEncoder encoder);
}

class CblMDelegate extends MDelegate {
  @override
  MCollection? collectionFromNative(Object? native) {
    if (native is MCollectionWrapper) {
      return native.mCollection;
    }
  }

  @override
  void encodeNative(FleeceEncoder encoder, Object? native) {
    if (native == null ||
        native is String ||
        native is num ||
        native is bool ||
        native is TypedData) {
      encoder.writeDartObject(native);
    } else if (native is DateTime) {
      encoder.writeString(native.toIso8601String());
    } else if (native is FleeceEncodable) {
      native.encodeTo(encoder);
    } else {
      throw ArgumentError.value(
        native,
        'native',
        'is not a value of a recognized native type',
      );
    }
  }

  @override
  Object? toNative(MValue value, MCollection parent, void Function() cacheIt) {
    final flValue = value.value;
    if (flValue is SimpleFLValue) {
      return flValue.value;
    } else if (flValue is SliceFLValue) {
      cacheIt();
      return flValue.isString
          ? flValue.slice.toDartString()
          : flValue.slice.asBytes();
    } else if (flValue is CollectionFLValue) {
      cacheIt();
      if (flValue.isArray) {
        final array = MArray.asChild(value, parent);
        if (parent.hasMutableChildren) {
          return MutableArrayImpl(array);
        } else {
          return ArrayImpl(array);
        }
      } else {
        final blob = _blobBindings.getBlob(flValue.value.cast());
        if (blob != null) {
          return BlobImpl(
            blob: blob,
            // `getBlob` returns an existing instance retained by the containing
            // document.
            retain: true,
            debugCreator: 'CblMDelegate.toNative()',
          );
        }

        final dictionary = MDict.asChild(value, parent);
        if (parent.hasMutableChildren) {
          return MutableDictionaryImpl(dictionary);
        } else {
          return DictionaryImpl(dictionary);
        }
      }
    }

    throw ArgumentError.value(
      value,
      'value',
      'unable to create corresponding native value',
    );
  }
}

bool valueWouldChange(
  Object? newValue,
  MValue? oldValue,
  MCollection container,
) {
  if (oldValue?.value is CollectionFLValue) {
    return false;
  }

  if (newValue is Array || newValue is Dictionary) {
    return true;
  }

  return newValue != oldValue?.asNative(container);
}

Object? toPrimitiveObject(Object? object) {
  if (object is Array) {
    return object.map(toPrimitiveObject).toList();
  }
  if (object is Dictionary) {
    return Map.fromEntries(object.map((key) => MapEntry(
          key,
          toPrimitiveObject(object.value(key)),
        )));
  }
  return object;
}

Object? toCblObject(Object? object) {
  if (object == null || object is num || object is bool || object is String) {
    return object;
  }
  if (object is DateTime) {
    return object.toIso8601String();
  }
  if (object is TypedData) {
    return Blob.fromData(
      'application/octet-stream',
      object.buffer.asUint8List(),
    );
  }
  if (object is Blob) {
    return object;
  }
  if (object is MutableArray) {
    return object;
  }
  if (object is Array) {
    return object.toMutable();
  }
  if (object is MutableDictionary) {
    return object;
  }
  if (object is Dictionary) {
    return object.toMutable();
  }
  if (object is Iterable<Object?>) {
    return MutableArray(object);
  }
  if (object is Map<String, dynamic>) {
    if (Blob.isBlob(object)) {
      // TODO
      throw UnimplementedError();
    }
    return MutableDictionary(object);
  }

  throw ArgumentError.value(object, 'value', 'cannot be stored in a Documents');
}

T? coerceObject<T>(Object? object) {
  if (object is T) {
    return object;
  }
  if (T == bool) {
    if (object == null) {
      return false as T;
    }
    if (object is num) {
      return (object.toInt() != 0) as T;
    }
    return true as T;
  }
  if (T == int) {
    if (object is num) {
      return object.toInt() as T;
    }
  }
  if (T == double) {
    if (object is num) {
      return object.toDouble() as T;
    }
  }
  if (T == DateTime) {
    if (object is String) {
      return DateTime.parse(object) as T;
    }
  }
}
