import 'dart:collection';

import 'array.dart';
import 'blob.dart';
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

  /// Deeply converts this dictionary into a simple JSON representation and
  /// returns it.
  ///
  /// {@macro cbl.ArrayInterface.toPrimitiveObjectConversion}
  Map<String, dynamic> toMap();
}

/// Provides readonly access to dictionary data.
abstract class Dictionary
    implements DictionaryInterface, Iterable<MapEntry<String, Object?>> {
  /// Returns a mutable copy of this dictionary.
  MutableDictionary toMutable();
}

abstract class DictionaryImpl
    with IterableMixin<MapEntry<String, Object?>>
    implements Dictionary {
  @override
  Iterator<MapEntry<String, Object?>> get iterator =>
      throw UnimplementedError();

  @override
  bool operator ==(Object object) => throw UnimplementedError();

  @override
  int get hashCode => throw UnimplementedError();
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
  factory MutableDictionary([Map<String, Object?>? data]) =>
      throw UnimplementedError();
}

abstract class MutableDictionaryImpl extends DictionaryImpl
    implements MutableDictionary {}
