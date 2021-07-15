import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';

import '../../utils.dart';
import '../decoder.dart';
import '../encoder.dart';
import 'collection.dart';
import 'value.dart';

class MArray extends MCollection {
  MArray()
      : _array = null,
        _values = [];

  MArray.asCopy(MArray original, {bool? isMutable})
      : _array = original._array,
        _values = List.of(original._values),
        super.asCopy(original, isMutable: isMutable ?? original.isMutable);

  MArray.asChild(MValue slot, MCollection parent, {bool? isMutable})
      : _array = (slot.value as CollectionFLValue).value.cast(),
        _values = List<MValue?>.filled(
          (slot.value as CollectionFLValue).length,
          null,
          growable: true,
        ),
        super.asChild(
          slot,
          parent,
          isMutable: isMutable ?? parent.hasMutableChildren,
        );

  final Pointer<FLArray>? _array;
  final List<MValue?> _values;

  int get length => _values.length;

  MValue? get(int index) {
    assert(index >= 0);

    if (index >= _values.length) return null;

    return _values[index] ??= _loadMValue(index)!;
  }

  bool set(int index, Object? native) {
    assert(isMutable);
    assert(index >= 0);

    if (index >= length) {
      return false;
    }

    mutate();
    (_values[index] ??= MValue.empty()).setNative(native, this);

    return true;
  }

  bool insert(int index, Object? native) {
    assert(isMutable);
    assert(index >= 0);

    final length = this.length;
    if (index > length) {
      return false;
    } else if (index < length) {
      _populateValues();
    }

    mutate();
    _values.insert(index, MValue.empty()..setNative(native, this));

    return true;
  }

  void append(Object? native) => insert(length, native);

  bool remove(int index, [int count = 1]) {
    assert(isMutable);
    assert(index >= 0);
    assert(count >= 0);

    final end = index + count;
    if (end > length) {
      return false;
    }

    if (count == 0) {
      return true;
    }

    if (end < length) {
      _populateValues();
    }

    mutate();
    _values.getRange(index, end).forEach((value) => value?.removeFromParent());
    _values.removeRange(index, end);

    return true;
  }

  void clear() {
    assert(isMutable);

    if (_values.isEmpty) {
      return;
    }

    mutate();
    _values.forEach((value) => value?.removeFromParent());
    _values.clear();
  }

  @override
  void encodeTo(FleeceEncoder encoder) {
    if (!isMutated) {
      encoder.writeValue(_array!.cast());
    } else {
      encoder.beginArray(length);
      var index = 0;
      for (final value in _values) {
        if (value == null) {
          encoder.writeArrayValue(_array!, index);
        } else {
          value.encodeTo(encoder);
        }
        ++index;
      }
      encoder.endArray();
    }
  }

  @override
  Iterable<MValue> get values => _values.whereNotNull();

  void _populateValues() {
    if (_array == null) return;

    var i = 0;
    for (final value in _values) {
      if (value == null) {
        _values[i] = _loadMValue(i);
      }
      i++;
    }
  }

  MValue? _loadMValue(int index) {
    final array = _array;
    if (array == null) return null;

    return context!.decoder
        .loadValueFromArray(array, index)
        ?.let((it) => MValue.withValue(it));
  }
}
