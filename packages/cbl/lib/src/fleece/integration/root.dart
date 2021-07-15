import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../../native_object.dart';
import '../encoder.dart';
import '../slice.dart';
import 'collection.dart';
import 'context.dart';
import 'value.dart';

class MRoot extends MCollection {
  MRoot.fromData(
    SliceResult data, {
    required MContext context,
    required bool isMutable,
  })  : data = data,
        _slot = MValue.withValue(context.decoder.loadValueFromData(data)!),
        super(context: context, isMutable: isMutable) {
    _slot.updateParent(this);
  }

  MRoot.fromValue(
    Pointer<FLValue> value, {
    required MContext context,
    required bool isMutable,
  })  : value = FleeceRefCountedObject(value, release: true, retain: true),
        _slot = MValue.withValue(context.decoder.loadValue(value)!),
        super(context: context, isMutable: isMutable) {
    _slot.updateParent(this);
  }

  SliceResult? data;

  FleeceRefCountedObject<FLValue>? value;

  final MValue _slot;

  @override
  MContext get context => super.context!;

  @override
  bool get isMutated => _slot.isMutated;

  @override
  Iterable<MValue> get values => [_slot];

  @override
  void encodeTo(FleeceEncoder encoder) => _slot.encodeTo(encoder);

  Object? get asNative => _slot.asNative(this);

  SliceResult encode() {
    var encoder = FleeceEncoder();
    encodeTo(encoder);
    return encoder.finish();
  }
}
