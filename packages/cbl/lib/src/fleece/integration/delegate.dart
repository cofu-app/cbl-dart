import 'dart:typed_data';

import '../decoder.dart';
import '../encoder.dart';
import 'array.dart';
import 'collection.dart';
import 'dict.dart';
import 'value.dart';

abstract class MDelegate {
  static late MDelegate instance;

  MCollection? collectionFromNative(Object? native);

  Object? toNative(MValue value, MCollection parent, void Function() cacheIt);

  void encodeNative(FleeceEncoder encoder, Object? native);
}

class SimpleMDelegate extends MDelegate {
  @override
  MCollection? collectionFromNative(Object? native) {
    if (native is MCollection) return native;
  }

  @override
  void encodeNative(FleeceEncoder encoder, Object? native) {
    if (native == null ||
        native is String ||
        native is num ||
        native is bool ||
        native is TypedData) {
      encoder.writeDartObject(native);
    } else if (native is MCollection) {
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
      return flValue.isArray
          ? MArray.asChild(value, parent)
          : MDict.asChild(value, parent);
    }
  }
}
