import '../decoder.dart';
import '../encoder.dart';
import 'collection.dart';
import 'delegate.dart';

MDelegate get _delegate => MDelegate.instance!;

class MValue {
  MValue.empty() : this(null, null, hasNative: false);

  MValue.withValue(LoadedFLValue value) : this(value, null, hasNative: false);

  MValue.withNative(Object? native) : this(null, native, hasNative: true);

  MValue(LoadedFLValue? value, Object? native, {required bool hasNative})
      : assert(hasNative || native == null),
        _value = value,
        _hasNative = hasNative,
        _native = native;

  bool get isEmpty => !hasValue && !hasNative;

  bool get isNotEmpty => !isEmpty;

  bool get isMutated => !hasValue;

  bool get hasValue => _value != null;

  LoadedFLValue? get value => _value;
  LoadedFLValue? _value;

  bool get hasNative => _hasNative;
  bool _hasNative;
  Object? _native;

  Object? asNative(MCollection parent) {
    assert(!isEmpty);

    if (hasNative) {
      return _native;
    } else {
      var cacheIt = false;
      final native = _delegate.toNative(this, parent, () => cacheIt = true);
      if (cacheIt) {
        _native = native;
        _hasNative = true;
      }
      return native;
    }
  }

  void setNative(Object? native, MCollection parent) =>
      _setNative(native, parent: parent, hasNative: true);

  void setEmpty(MCollection parent) {
    if (isEmpty) return;
    _value = null;
    _setNative(null, parent: parent, hasNative: false);
  }

  void mutate() {
    _value = null;
  }

  void updateParent(MCollection parent) => _updateNativeParent(this, parent);

  void removeFromParent() => _updateNativeParent(null, null);

  void encodeTo(FleeceEncoder encoder) {
    assert(!isEmpty);

    final value = _value;
    if (value != null) {
      encoder.writeLoadedValue(value);
    } else {
      _delegate.encodeNative(encoder, _native);
    }
  }

  void _setNative(
    Object? native, {
    required MCollection parent,
    required bool hasNative,
  }) {
    assert(
      hasNative || native == null,
      'native must be null when hasNative is false',
    );

    if (_native == native && _hasNative == hasNative) return;

    // Update parent of old native value
    _updateNativeParent(null, null);

    _hasNative = hasNative;
    _native = native;
    mutate();

    // Update parent of new native value
    _updateNativeParent(this, parent);
  }

  void _updateNativeParent(MValue? slot, MCollection? parent) {
    if (!_hasNative) return;
    _delegate.collectionFromNative(_native)?.updateParent(slot, parent);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MValue &&
          runtimeType == other.runtimeType &&
          _value == other._value &&
          _hasNative == other._hasNative &&
          _native == other._native;

  @override
  int get hashCode => _value.hashCode ^ _hasNative.hashCode ^ _native.hashCode;

  @override
  String toString() => 'MValue('
      'hasValue: $hasValue, '
      'hasNative: $hasNative, '
      'value: $_value, '
      'native: $_native'
      ')';
}
