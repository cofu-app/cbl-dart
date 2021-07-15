import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../fleece/fleece.dart';
import '../fleece/integration/integration.dart';
import 'array.dart';
import 'blob.dart';
import 'common.dart';
import 'fragment.dart';

/// Defines a set of methods for readonly accessing [Dictionary] data.
abstract class DictionaryInterface implements DictionaryFragment {
  /// The number of entries in this dictionary.
  int get length;

  /// The keys of the entries in this dictionary.
  List<String> get keys;

  /// Returns the value for the given [key].
  ///
  /// Returns `null` if the element is `null` or the there is no entry with the
  /// given [key].
  Object? value(String key);

  /// Returns the value for the given [key] as a [String].
  ///
  /// {@template cbl.DictionaryInterface.typedNullableGetter}
  /// Returns `null` if the a value for the given [key] does not exists, is not
  /// a of the expected typ or it is `null`.
  /// {@endtemplate}
  String? string(String key);

  /// Returns the value for the given [key] as an integer number.
  ///
  /// {@template cbl.DictionaryInterface.typedDefaultedGetter}
  /// Returns a default value (integer: `0`, double: `0.0`, boolean: `false`)
  /// if the value is not a of the expected typ, is `null` or does not exist
  /// for the given [key].
  /// {@endtemplate}
  int integer(String key);

  /// Returns the value for the given [key] as a floating point number.
  ///
  /// {@macro cbl.DictionaryInterface.typedDefaultedGetter}
  double float(String key);

  /// Returns the value for the given [key] as a [num].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter}
  num? number(String key);

  /// Returns the value for the given [key] as a [bool].
  ///
  /// {@macro cbl.DictionaryInterface.typedDefaultedGetter}
  bool boolean(String key);

  /// Returns the value for the given [key] as a [DateTime].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter}
  DateTime? date(String key);

  /// Returns the value for the given [key] as a [Blob].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter
  Blob? blob(String key);

  /// Returns the value for the given [key] as an [Array].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter
  Array? array(String key);

  /// Returns the value for the given [key] as a [Dictionary].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter
  Dictionary? dictionary(String key);

  /// Returns whether an entry with the given [key] exists in this dictionary.
  bool contains(String key);

  /// Deeply converts this dictionary into a representation of plain Dart
  /// objects and returns it.
  ///
  /// {@macro cbl.ArrayInterface.toPrimitiveObjectConversion}
  Map<String, dynamic> toMap();
}

/// Provides readonly access to dictionary data.
@immutable
abstract class Dictionary
    implements DictionaryInterface, Iterable<MapEntry<String, Object?>> {
  /// Returns a mutable copy of this dictionary.
  MutableDictionary toMutable();
}

/// Defines a set of methods for getting and setting dictionary data.
abstract class MutableDictionaryInterface
    implements DictionaryInterface, MutableDictionaryFragment {
  /// Sets a [value] for the given [key].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  void setValue(Object? value, {required String key});

  /// Sets a [String] for the given [key].
  void setString(String? value, {required String key});

  /// Sets an integer number for the given [key].
  void setInteger(int value, {required String key});

  /// Sets a floating point number for the given [key].
  void setFloat(double value, {required String key});

  /// Sets a [num] for the given [key].
  void setNumber(num? value, {required String key});

  /// Sets a [bool] for the given [key].
  void setBoolean(bool value, {required String key});

  /// Sets a [DateTime] for the given [key].
  void setDate(DateTime? value, {required String key});

  /// Sets a [Blob] for the given [key].
  void setBlob(Blob? value, {required String key});

  /// Sets an [Array] for the given [key].
  void setArray(Array? value, {required String key});

  /// Sets a [Dictionary] for the given [key].
  void setDictionary(Dictionary? value, {required String key});

  /// Replaces the entries of this dictionary with those of the given [Map].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  void setData(Map<String, Object?> data);

  /// Removes the entry with the given [key].
  void removeValue(String key);

  /// Returns the value for the given [key] as an [MutableArray].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter
  @override
  MutableArray? array(String key);

  /// Returns the value for the given [key] as a [MutableDictionary].
  ///
  /// {@macro cbl.DictionaryInterface.typedNullableGetter
  @override
  MutableDictionary? dictionary(String key);
}

/// Provides access to dictionary data.
abstract class MutableDictionary
    implements Dictionary, MutableDictionaryInterface {
  /// Creates a [MutableDictionary], optionally initialized with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDictionary([Map<String, Object?>? data]) {
    final dictionary = MutableDictionaryImpl(MDict());
    if (data != null) {
      dictionary.setData(data);
    }
    return dictionary;
  }
}

class DictionaryImpl
    with IterableMixin<MapEntry<String, Object?>>
    implements Dictionary, MCollectionWrapper, FleeceEncodable {
  DictionaryImpl(this._dict);

  final MDict _dict;

  @override
  int get length => _dict.length;

  @override
  List<String> get keys => _dict.iterable.map((entry) => entry.key).toList();

  T? _getAs<T>(String key) => coerceObject(_dict.get(key)?.asNative(_dict));

  T _getAsWithDefault<T>(String key, T defaultValue) =>
      _getAs(key) ?? defaultValue;

  @override
  Object? value(String key) => _getAs(key);

  @override
  String? string(String key) => _getAs(key);

  @override
  int integer(String key) => _getAsWithDefault(key, 0);

  @override
  double float(String key) => _getAsWithDefault(key, 0);

  @override
  num? number(String key) => _getAs(key);

  @override
  bool boolean(String key) => _getAsWithDefault(key, false);

  @override
  DateTime? date(String key) => _getAs(key);

  @override
  Blob? blob(String key) => _getAs(key);

  @override
  Array? array(String key) => _getAs(key);

  @override
  Dictionary? dictionary(String key) => _getAs(key);

  @override
  Map<String, dynamic> toMap() =>
      toPrimitiveObject(this) as Map<String, dynamic>;

  @override
  Fragment operator [](String key) =>
      FragmentImpl.fromDictionary(this, key: key);

  @override
  MutableDictionary toMutable() =>
      MutableDictionaryImpl(MDict.asCopy(_dict, isMutable: true));

  @override
  MCollection get mCollection => _dict;

  @override
  void encodeTo(FleeceEncoder encoder) => _dict.encodeTo(encoder);

  @override
  Iterator<MapEntry<String, Object?>> get iterator => _dict.iterable
      .map((entry) => MapEntry(
            entry.key,
            entry.value.asNative(_dict),
          ))
      .iterator;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DictionaryImpl &&
          runtimeType == other.runtimeType &&
          const DeepCollectionEquality().equals(this, other);

  @override
  int get hashCode => const DeepCollectionEquality().hash(this);
}

class MutableDictionaryImpl extends DictionaryImpl
    implements MutableDictionary {
  MutableDictionaryImpl(MDict dictionary) : super(dictionary);

  @override
  void setValue(Object? value, {required String key}) {
    value = toCblObject(value);
    if (valueWouldChange(value, _dict.get(key), _dict)) {
      _dict.set(key, value);
    }
  }

  @override
  void setString(String? value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setInteger(int value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setFloat(double value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setNumber(num? value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setBoolean(bool value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setDate(DateTime? value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setBlob(Blob? value, {required String key}) => setValue(value, key: key);

  @override
  void setArray(Array? value, {required String key}) =>
      setValue(value, key: key);

  @override
  void setDictionary(Dictionary? value, {required String key}) =>
      setValue(value, key: key);

  // === Replace ===============================================================

  @override
  void setData(Map<String, Object?> data) {
    _dict.clear();
    data.entries.forEach((entry) {
      _dict.set(entry.key, toCblObject(entry.value));
    });
  }

  // === Remove ================================================================

  @override
  void removeValue(String key) => _dict.remove(key);

  // === Mutable containers ====================================================

  @override
  MutableArray? array(String key) => super.array(key) as MutableArray?;

  @override
  MutableDictionary? dictionary(String key) =>
      super.dictionary(key) as MutableDictionary?;

  // === MutableArrayFragment ==================================================

  @override
  MutableFragment operator [](String key) =>
      MutableFragmentImpl.fromDictionary(this, key: key);

  // === Dictionary ============================================================

  @override
  MutableDictionary toMutable() => this;
}
