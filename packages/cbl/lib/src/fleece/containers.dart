import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';

import '../errors.dart';
import 'slice.dart';
import '../native_object.dart';
import '../resource.dart';

/// Options for how values are copied.
enum CopyFlag {
  /// Make a deep copy instead of a shallow copy, by recursively copying values.
  deepCopy,

  /// Copy immutables instead of referencing them.
  copyImmutables,
}

extension on CopyFlag {
  FLCopyFlag toFLCopyFlag() => FLCopyFlag.values[index];
}

extension on Iterable<CopyFlag> {
  Set<FLCopyFlag> toFLCopyFlags() => map((flag) => flag.toFLCopyFlag()).toSet();
}

// === Doc =====================================================================

/// An [Doc] points to (and often owns) Fleece-encoded data and provides access
/// to its Fleece values.
class Doc extends NativeResource<NativeObject<FLDoc>> {
  static late final _bindings = CBLBindings.instance.fleece.doc;

  factory Doc.fromResultData(SliceResult data, FLTrust trust) {
    final doc = _bindings.fromResultData(
      data.makeGlobal().cast<FLSliceResult>().ref,
      trust,
    );
    if (doc == null) {
      throw FleeceException(
        'The data is not valid Fleece data.',
        FleeceErrorCode.invalidData,
      );
    }
    return Doc.fromPointer(doc);
  }

  /// Creates an [Doc] from JSON-encoded data.
  ///
  /// The data is first encoded into Fleece, and the Fleece data is kept by the
  /// doc.
  factory Doc.fromJson(String json) {
    try {
      return Doc.fromPointer(_bindings.fromJson(json));
    } on CBLErrorException catch (e) {
      throw translateCBLErrorException(e);
    }
  }

  /// Creates an [Doc] based on a [pointer] to the the native value.
  Doc.fromPointer(Pointer<FLDoc> pointer) : super(FleeceDocObject(pointer));

  /// Returns the root value in the [Doc], usually an [Dict].
  Value get root => Value.fromPointer(_bindings.getRoot(native.pointerUnsafe));
}

// === Value ===================================================================

/// Types of Fleece values. Basically JSON, with the addition of Data
/// (raw blob).
enum ValueType {
  /// Type of a null pointer, i.e. no such value, like JSON `undefined`.
  undefined,

  /// Equivalent to a JSON 'null'.
  Null,

  /// A `true` or `false` value.
  boolean,

  /// A numeric value, either integer or floating-point.
  number,

  /// A string.
  string,

  /// Binary data (no JSON equivalent).
  data,

  /// An array of values.
  array,

  /// A mapping of strings to values
  dict,
}

extension on FLValueType {
  ValueType toValueType() => ValueType.values[index];
}

/// The core Fleece data type is Value: a reference to a value in Fleece-encoded
/// data. A Value can represent any JSON type (plus binary data).
///
/// - Scalar data types -- numbers, booleans, null, strings, data -- can be
///   accessed using individual functions of the form `as...`; these return the
///   scalar value, or a default zero/false/null value if the value is not of
///   that type.
/// - Collections -- arrays and dictionaries -- have their own subclasses: Array
///   and Dict. To coerce an Value to a collection type, call [asArray] or
///   [asDict]. If the value is not of that type, null is returned. (Array and
///   Dict are documented fully in their own sections.)
class Value extends NativeResource<NativeObject<FLValue>> {
  static late final _bindings = CBLBindings.instance.fleece.value;

  /// Creates a [Value] based on a [pointer] to the the native value.
  ///
  /// Accessing immutable values is only allowed, while the enclosing container
  /// ([Doc], [MutableArray], [MutableDict] and other objects, holding Fleece
  /// data) has not been garbage collected.
  Value.fromPointer(
    Pointer<FLValue> pointer, {
    bool release = false,
    bool retain = false,
  }) : super(FleeceRefCountedObject(
          pointer.cast(),
          release: release,
          retain: retain,
        ));

  /// Looks up the Doc containing the Value, or null if the Value was created
  /// without a Doc.
  Doc? get doc {
    final pointer = _bindings.findDoc(native.pointerUnsafe);
    return pointer == nullptr ? null : Doc.fromPointer(pointer);
  }

  /// Returns the data type of an arbitrary Value.
  ValueType get type => _bindings.getType(native.pointerUnsafe).toValueType();

  /// Whether this value represents an `undefined` value.
  bool get isUndefined => type == ValueType.undefined;

  /// Whether this value represents null.
  bool get isNull => type == ValueType.Null;

  /// Returns true if the value is non-null and represents an integer.
  bool get isInteger => _bindings.isInteger(native.pointerUnsafe);

  /// Returns true if the value is non-null and represents a 64-bit
  /// floating-point number.
  bool get isDouble => _bindings.isDouble(native.pointerUnsafe);

  /// Returns a value coerced to boolean. This will be true unless the value is
  /// undefined, null, false, or zero.
  bool get asBool => _bindings.asBool(native.pointerUnsafe);

  /// Returns a value coerced to an integer. True and false are returned as 1
  /// and 0, and floating-point numbers are rounded. All other types are
  /// returned as 0.
  int get asInt => _bindings.asInt(native.pointerUnsafe);

  /// Returns a value coerced to a 64-bit floating point number. True and false
  /// are returned as 1.0 and 0.0, and integers are converted to float. All
  /// other types are returned as 0.0.
  double get asDouble => _bindings.asDouble(native.pointerUnsafe);

  /// Returns the exact contents of a string value, or null for all other types.
  String? get asString => _bindings.asString(native.pointerUnsafe);

  /// Returns the exact contents of a data value, or null for all other types.
  Uint8List? get asData => _bindings.asData(native.pointerUnsafe);

  /// If a Value represents an array, returns it as a [Array], else null.
  Array? get asArray => type == ValueType.array
      ? Array.fromPointer(native.pointerUnsafe.cast())
      : null;

  /// If a Value represents a dictionary, returns it as a [Dict], else null.
  Dict? get asDict => type == ValueType.dict
      ? Dict.fromPointer(native.pointerUnsafe.cast())
      : null;

  /// Returns a string representation of any scalar value. Data values are
  /// returned in raw form. Arrays and dictionaries don't have a representation
  /// and will return null.
  String? get scalarToString => _bindings.scalarToString(native.pointerUnsafe);

  /// Encodes a Fleece value as JSON (or a JSON fragment.) Any Data values will
  /// become base64-encoded JSON strings.
  String toJson({
    bool json5 = false,
    bool canonical = true,
  }) =>
      _bindings.toJSONX(native.pointerUnsafe, json5, canonical);

  Object? toObject() {
    switch (type) {
      case ValueType.undefined:
        throw UnsupportedError(
          'ValueType.undefined has no equivalent Dart type',
        );
      case ValueType.Null:
        return null;
      case ValueType.boolean:
        return asBool;
      case ValueType.number:
        return isInteger ? asInt : asDouble;
      case ValueType.string:
        return asString;
      case ValueType.array:
        return asArray!.toObject();
      case ValueType.dict:
        return asDict!.toObject();
      case ValueType.data:
        return asData;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Value &&
          _bindings.isEqual(native.pointerUnsafe, other.native.pointerUnsafe);

  @override
  int get hashCode {
    switch (type) {
      case ValueType.undefined:
      case ValueType.Null:
        return 0;
      case ValueType.boolean:
        return asBool.hashCode;
      case ValueType.number:
        return asInt.hashCode;
      case ValueType.string:
        return asString.hashCode;
      case ValueType.data:
        return asData.hashCode;
      case ValueType.array:
        return asArray.hashCode;
      case ValueType.dict:
        return asDict.hashCode;
    }
  }

  @override
  String toString() {
    switch (type) {
      case ValueType.undefined:
        return 'undefined';
      case ValueType.Null:
      case ValueType.boolean:
      case ValueType.number:
        return scalarToString!;
      case ValueType.string:
        return '"${asString!}"';
      case ValueType.array:
        return asArray.toString();
      case ValueType.dict:
        return asDict.toString();
      case ValueType.data:
        return '<DATA>';
    }
  }
}

// === Array ===================================================================

/// A Fleece array.
class Array extends Value with ListMixin<Value> {
  static late final _bindings = CBLBindings.instance.fleece.array;

  /// Creates an [Array] based on a [pointer] to the the native value.
  Array.fromPointer(
    Pointer<FLArray> pointer, {
    bool release = false,
    bool retain = false,
  }) : super.fromPointer(pointer.cast(), retain: retain, release: release);

  late final Pointer<FLArray> _arrayPointer = native.pointerUnsafe.cast();

  @override
  int get length => _bindings.count(_arrayPointer);

  @override
  set length(int length) => throw _immutableValueException();

  @override
  bool get isEmpty => _bindings.isEmpty(_arrayPointer);

  @override
  Value get first => this[0];

  @override
  Value get last => this[length - 1];

  /// If the array is mutable, returns it cast to [MutableArray], else null.
  MutableArray? get asMutable {
    final pointer = _bindings.asMutable(_arrayPointer);
    return pointer == null
        ? null
        : MutableArray.fromPointer(pointer, release: true, retain: true);
  }

  @override
  List<Object?> toObject() => map((element) => element.toObject()).toList();

  @override
  Value operator [](int index) =>
      Value.fromPointer(_bindings.get(_arrayPointer, index));

  @override
  void operator []=(int index, Object? value) =>
      throw _immutableValueException();

  @override
  int get hashCode => fold(0, (hashCode, value) => hashCode ^ value.hashCode);
}

class MutableArray extends Array {
  static late final _bindings = CBLBindings.instance.fleece.mutableArray;

  /// Creates a [MutableArray] based on a [pointer] to the the native value.
  MutableArray.fromPointer(
    Pointer<FLMutableArray> pointer, {
    required bool release,
    required bool retain,
  }) : super.fromPointer(pointer.cast(), retain: retain, release: release);

  /// Creates a new empty [MutableArray].
  factory MutableArray([Iterable<Object?>? from]) {
    final result = MutableArray.fromPointer(
      _bindings.create(),
      release: true,
      retain: false,
    );

    if (from != null) {
      result.addAll(from);
    }

    return result;
  }

  /// Creates a new [MutableArray] that's a copy of the source [Array].
  ///
  /// Copying an immutable Array is very cheap (only one small allocation)
  /// unless the [CopyFlag.copyImmutables] is set.
  ///
  /// Copying a mutable Array is cheap if it's a shallow copy, but if
  /// [CopyFlag.deepCopy] is true, nested mutable Arrays and [Dict]s are also
  /// copied, recursively; if [CopyFlag.copyImmutables] is also set, immutable
  /// values are also copied.
  factory MutableArray.mutableCopy(
    Array source, {
    Set<CopyFlag> flags = const {},
  }) =>
      MutableArray.fromPointer(
        _bindings.mutableCopy(
          source.native.pointerUnsafe.cast(),
          flags.toFLCopyFlags(),
        ),
        retain: false,
        release: true,
      );

  late final Pointer<FLMutableArray> _mutableArrayPointer =
      native.pointerUnsafe.cast();

  /// If the Array was created by [MutableArray.mutableCopy], returns the original
  /// source Array.
  Array? get source {
    final pointer = _bindings.getSource(_mutableArrayPointer);
    return pointer == nullptr ? null : Array.fromPointer(pointer);
  }

  /// Returns true if the [Array] has been changed from the source it was copied
  /// from.
  bool get isChanged => _bindings.isChanged(_mutableArrayPointer);

  @override
  set length(int length) => _bindings.resize(_mutableArrayPointer, length);

  @override
  set first(Object? value) {
    this[0] = value;
  }

  @override
  set last(Object? value) {
    this[length - 1] = value;
  }

  @override
  void operator []=(int index, Object? value) {
    RangeError.checkValidIndex(index, this);
    final slot = _bindings.set(_mutableArrayPointer, index);
    _setSlotValue(slot, value);
  }

  @override
  void add(Object? element) {
    final slot = _bindings.append(_mutableArrayPointer);
    _setSlotValue(slot, element);
  }

  @override
  void addAll(Iterable<Object?> iterable) {
    var i = length;
    for (final element in iterable) {
      assert(length == i || (throw ConcurrentModificationError(this)));
      add(element);
      i++;
    }
  }

  @override
  void removeRange(int start, int end) {
    RangeError.checkValidRange(start, end, length);
    _bindings.remove(_mutableArrayPointer, start, end - start);
  }

  /// Inserts a contiguous range of JSON `null` values into the array.
  ///
  /// [start] is the zero-based index of the first value to be inserted.
  /// [count] is the number of items to insert.
  void insertNulls(int start, int count) {
    RangeError.checkValidIndex(start, this, 'start');
    _bindings.insert(_mutableArrayPointer, start, count);
  }

  /// Convenience function for getting an dict-valued property in mutable form.
  ///
  /// - If the value for the [index] is not a dict, returns null.
  /// - If the value is a mutable dict, returns it.
  /// - If the value is an immutable dict, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableDict? mutableDict(int index) {
    final pointer = _bindings.getMutableDict(_mutableArrayPointer, index);
    return pointer == null
        ? null
        : MutableDict.fromPointer(pointer, release: true, retain: true);
  }

  /// Convenience function for getting a array-valued property in mutable form.
  ///
  /// - If the value for the [index] is not an array, returns null.
  /// - If the value is a mutable array, returns it.
  /// - If the value is an immutable array, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableArray? mutableArray(int index) {
    final pointer = _bindings.getMutableArray(_mutableArrayPointer, index);
    return pointer == null
        ? null
        : MutableArray.fromPointer(pointer, retain: true, release: true);
  }
}

// === Dict ====================================================================

/// A Fleece dictionary.
class Dict extends Value with MapMixin<String, Value> {
  static late final _bindings = CBLBindings.instance.fleece.dict;

  /// Creates a [Dict] based on a [pointer] to the the native value.
  Dict.fromPointer(
    Pointer<FLDict> pointer, {
    bool release = false,
    bool retain = false,
  }) : super.fromPointer(pointer.cast(), retain: retain, release: release);

  late final Pointer<FLDict> _dictPointer = native.pointerUnsafe.cast();

  /// Returns the number of items in a dictionary.
  @override
  int get length => _bindings.count(_dictPointer);

  /// Returns true if a dictionary is empty. Depending on the dictionary's
  /// representation, this can be faster than `count == 0`.
  @override
  bool get isEmpty => _bindings.isEmpty(_dictPointer);

  @override
  bool get isNotEmpty => !isEmpty;

  /// If the dictionary is mutable, returns it cast to [MutableDict], else null.
  MutableDict? get asMutable {
    final pointer = _bindings.asMutable(_dictPointer);
    return pointer == null
        ? null
        : MutableDict.fromPointer(pointer, release: true, retain: true);
  }

  @override
  late final Iterable<String> keys = _DictKeyIterable(this);

  @override
  Value operator [](Object? key) {
    assert(key is String, 'Dict key must be a non-null String');
    return Value.fromPointer(_bindings.get(_dictPointer, key as String));
  }

  @override
  void operator []=(String key, Object? value) =>
      throw _immutableValueException();

  @override
  void clear() => throw _immutableValueException();

  @override
  Value? remove(Object? key) => throw _immutableValueException();

  @override
  int get hashCode => entries.fold(0, (hashCode, entry) {
        return hashCode ^ entry.key.hashCode ^ entry.value.hashCode;
      });

  @override
  Map<String, Object?> toObject() =>
      Map.fromEntries(entries.map((e) => MapEntry(e.key, e.value.toObject())));
}

/// Iterable which iterates over the keys of a [Dict].
class _DictKeyIterable extends Iterable<String> {
  _DictKeyIterable(this.dict);

  final Dict dict;

  @override
  Iterator<String> get iterator => _DictKeyIterator(dict);
}

/// Iterator which iterates over the keys of a [Dict].
class _DictKeyIterator extends Iterator<String> {
  static late final _bindings = CBLBindings.instance.fleece.dictIterator;

  _DictKeyIterator(this.dict);

  final Dict dict;

  Pointer<DictIterator>? iterator;

  @override
  late String current;

  @override
  bool moveNext() {
    // Create the iterator if it does not exist yet.
    iterator ??= _bindings.begin(this, dict.native.pointerUnsafe.cast());

    // The iterator has no more elements.
    if (iterator!.ref.done) return false;

    // Advance to the next item.
    _bindings.next(iterator!);

    final keyString = iterator!.ref.keyString;

    // If iterator has no elements at all, slice is the kNullSlice.
    if (keyString == null) return false;

    // Update current with keyString.
    current = keyString;

    return true;
  }
}

/// A mutable Fleece [Dict].
class MutableDict extends Dict {
  static late final _bindings = CBLBindings.instance.fleece.mutableDict;

  /// Creates a [MutableDict] based on a [pointer] to the the native value.
  MutableDict.fromPointer(
    Pointer<FLMutableDict> pointer, {
    required bool release,
    required bool retain,
  }) : super.fromPointer(pointer.cast(), retain: retain, release: release);

  /// Creates a new empty [MutableDict].
  factory MutableDict([Map<String, Object?>? from]) {
    final result = MutableDict.fromPointer(
      _bindings.create(),
      release: true,
      retain: false,
    );

    if (from != null) {
      result.addAll(from);
    }

    return result;
  }

  /// Creates a new [MutableDict] that's a copy of the source [Dict].
  ///
  /// Copying an immutable [Dict] is very cheap (only one small allocation.) The
  /// [CopyFlag.deepCopy] is ignored.
  ///
  /// Copying a [MutableDict] is cheap if it's a shallow copy, but if [flags]
  /// contains [CopyFlag.deepCopy], nested mutable Dicts and [Array]s are also
  /// copied, recursively.
  factory MutableDict.mutableCopy(
    Dict source, {
    Set<CopyFlag> flags = const {},
  }) =>
      MutableDict.fromPointer(
        _bindings.mutableCopy(
          source.native.pointerUnsafe.cast(),
          flags.toFLCopyFlags(),
        ),
        release: true,
        retain: false,
      );

  late final Pointer<FLMutableDict> _mutableDictPointer =
      native.pointerUnsafe.cast();

  /// If the Dict was created by [MutableDict.mutableCopy], returns the original
  /// source Dict.
  Dict? get source {
    final pointer = _bindings.getSource(_mutableDictPointer);
    return pointer == nullptr ? null : Dict.fromPointer(pointer);
  }

  /// Returns true if the Dict has been changed from the source it was copied
  /// from.
  bool get isChanged => _bindings.isChanged(_mutableDictPointer);

  @override
  void operator []=(String key, Object? value) =>
      _setSlotValue(_bindings.set(_mutableDictPointer, key), value);

  @override
  void addAll(Map<String, Object?> other) {
    for (final key in other.keys) {
      this[key] = other[key];
    }
  }

  @override
  void clear() => _bindings.removeAll(_mutableDictPointer);

  @override
  Value? remove(Object? key) {
    assert(key is String);
    final value = this[key];

    _bindings.remove(_mutableDictPointer, key as String);

    return value;
  }

  /// Convenience function for getting an dict-valued property in mutable form.
  ///
  /// - If the value for the key is not an dict, returns null.
  /// - If the value is a mutable dict, returns it.
  /// - If the value is an immutable dict, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableDict? mutableDict(String key) {
    final pointer = _bindings.getMutableDict(_mutableDictPointer, key);
    return pointer == null
        ? null
        : MutableDict.fromPointer(pointer, release: true, retain: true);
  }

  /// Convenience function for getting a array-valued property in mutable form.
  ///
  /// - If the value for the key is not a array, returns null.
  /// - If the value is a mutable array, returns it.
  /// - If the value is an immutable array, this function makes a mutable copy,
  ///   assigns the copy as the property value, and returns the copy.
  MutableArray? mutableArray(String key) {
    final pointer = _bindings.getMutableArray(_mutableDictPointer, key);
    return pointer == null
        ? null
        : MutableArray.fromPointer(pointer, release: true, retain: true);
  }
}

// === SlotSetter ==============================================================

abstract class SlotSetter {
  static final _instances = <SlotSetter>[_DefaultSlotSetter()];

  static void register(SlotSetter setter) {
    if (!_instances.contains(setter)) {
      _instances.add(setter);
    }
  }

  static SlotSetter _findForValue(Object? value) {
    final setter = _instances.firstWhereOrNull((it) => it.canSetValue(value));

    if (setter == null) {
      throw ArgumentError.value(
        value,
        'value',
        'value is not compatible with Fleece',
      );
    }

    return setter;
  }

  bool canSetValue(Object? value);

  void setSlotValue(Pointer<FLSlot> slot, Object? value);
}

class _DefaultSlotSetter implements SlotSetter {
  late final _slotBindings = CBLBindings.instance.fleece.slot;

  @override
  bool canSetValue(Object? value) =>
      value == null ||
      value is bool ||
      value is int ||
      value is double ||
      value is String ||
      value is TypedData ||
      value is Iterable ||
      value is Map ||
      value is Value;

  @override
  void setSlotValue(Pointer<FLSlot> slot, Object? value) {
    value = _recursivelyConvertCollectionsToFleece(value);

    if (value == null) {
      _slotBindings.setNull(slot);
    } else if (value is bool) {
      _slotBindings.setBool(slot, value);
    } else if (value is int) {
      _slotBindings.setInt(slot, value);
    } else if (value is double) {
      _slotBindings.setDouble(slot, value);
    } else if (value is String) {
      _slotBindings.setString(slot, value);
    } else if (value is TypedData) {
      _slotBindings.setData(slot, value);
    } else if (value is Value) {
      _slotBindings.setValue(slot, value.native.pointerUnsafe);
    }
  }

  static Object? _recursivelyConvertCollectionsToFleece(Object? value) {
    // These collection types can be set directly though the `set...` methods of
    // FLSLot.
    if (value is Value || value is TypedData) return value;

    if (value is Map) {
      return MutableDict()..addAll(value.cast());
    } else if (value is Iterable) {
      return MutableArray()..addAll(value);
    } else {
      // value is a primitive.
      return value;
    }
  }
}

void _setSlotValue(Pointer<FLSlot> slot, Object? value) {
  SlotSetter._findForValue(value).setSlotValue(slot, value);
}

// === Misc ====================================================================

Object _immutableValueException() =>
    UnsupportedError('You cannot mutate an immutable Value.');
