import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../../utils.dart';
import '../decoder.dart';
import '../encoder.dart';
import 'collection.dart';
import 'value.dart';

class MDict extends MCollection {
  MDict()
      : _dict = null,
        _values = {},
        _length = 0,
        _valuesHasAllKeys = true;

  MDict.asCopy(MDict original, {bool? isMutable})
      : _dict = original._dict,
        _values = Map.of(original._values),
        _length = original._length,
        _valuesHasAllKeys = original._valuesHasAllKeys,
        super.asCopy(original, isMutable: isMutable ?? original.isMutable);

  MDict.asChild(MValue slot, MCollection parent, {bool? isMutable})
      : _dict = (slot.value as CollectionFLValue).value.cast(),
        _values = {},
        _length = (slot.value as CollectionFLValue).length,
        _valuesHasAllKeys = false,
        super.asChild(
          slot,
          parent,
          isMutable: isMutable ?? parent.hasMutableChildren,
        );

  final Pointer<FLDict>? _dict;
  final Map<String, MValue> _values;
  int _length;

  /// Whether [_values] contains all the keys of [_dict].
  bool _valuesHasAllKeys;

  int get length => _length;

  bool contains(String key) => _getValue(key).isNotEmpty;

  MValue? get(String key) {
    final value = _getValue(key);
    return value.isNotEmpty ? value : null;
  }

  void set(String key, Object? native) {
    assert(isMutable);

    mutate();
    final value = _getValue(key);
    if (value.isEmpty) {
      _length++;
    }
    value.setNative(native, this);
  }

  void remove(String key) {
    assert(isMutable);

    final value = _getValue(key);
    if (value.isNotEmpty) {
      mutate();
      value.setEmpty(this);
      _length--;
    }
  }

  void clear() {
    assert(isMutable);

    if (_length == 0) {
      return;
    }

    // Clear out all entires.
    mutate();
    _values.values.forEach((value) => value.removeFromParent());
    _values.clear();
    _length = 0;

    // Shadow all keys in _dict with empty MValue.
    if (!_valuesHasAllKeys) {
      _valuesHasAllKeys = true;
      for (final key in context!.decoder.dictKeyIterable(_dict!)) {
        _values[key] = MValue.empty();
      }
    }
  }

  @override
  void encodeTo(FleeceEncoder encoder) {
    if (!isMutated) {
      encoder.writeValue(_dict!.cast());
    } else {
      encoder.beginDict(length);
      for (final entry in iterable) {
        encoder.writeKey(entry.key);
        if (entry.value.hasValue) {
          encoder.writeLoadedValue(entry.value.value!);
        } else {
          entry.value.encodeTo(encoder);
        }
      }
      encoder.endDict();
    }
  }

  @override
  Iterable<MValue> get values => _values.values;

  Iterable<MapEntry<String, MValue>> get iterable sync* {
    // Iterate over entries in _value.
    yield* _values.entries;

    // _values shadows all keys in _dict so there is no use in iterating _dict.
    if (_valuesHasAllKeys) return;

    // Iterate over entries in _dict.
    for (final entry in context!.decoder.dictIterable(_dict!)) {
      // Skip over entries which are shadowed by _values
      if (_values.containsKey(entry.key)) {
        continue;
      }

      // Cache the value to speed up lookups later.
      final key = entry.key;
      final value = _values[key] = MValue.withValue(entry.value);
      yield MapEntry(key, value);
    }

    _valuesHasAllKeys = true;
  }

  MValue _getValue(String key) =>
      _values[key] ??= (_loadValue(key) ?? MValue.empty())..updateParent(this);

  MValue? _loadValue(String key) {
    final dict = _dict;
    if (dict == null) return null;

    return context!.decoder
        .loadValueFromDict(dict, key)
        ?.let((it) => MValue.withValue(it));
  }
}
