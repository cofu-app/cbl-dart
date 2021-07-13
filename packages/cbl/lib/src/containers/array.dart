import 'dart:collection';

import 'blob.dart';
import 'dictionary.dart';
import 'fragment.dart';

/// Defines a set of methods for readonly accessing array data.
abstract class ArrayInterface implements ArrayFragment {
  /// The number of elements in this array.
  int get length;

  /// Returns the element at the given [index].
  ///
  /// Returns `null` if the element is `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  Object? value(int index);

  /// Returns the element at the given [index] as a [String].
  ///
  /// {@template cbl.ArrayInterface.typedNullableGetter}
  /// Returns `null` if the element is not a of the expected typ or it is
  /// `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  /// {@endtemplate}
  String? string(int index);

  /// Returns the element at the given [index] as an integer number.
  ///
  /// {@template cbl.ArrayInterface.typedDefaultedGetter}
  /// Returns a default value (integer: `0`, double: `0.0`, boolean: `false`)
  /// if the element is not of the expected type or is `null`.
  ///
  /// Throws a [RangeError] if the [index] is ouf of range.
  /// {@endtemplate}
  int integer(int index);

  /// Returns the element at the given [index] as an floating point number.
  ///
  /// {@macro cbl.ArrayInterface.typedDefaultedGetter}
  double float(int index);

  /// Returns the element at the given [index] as a [num].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  num? number(int index);

  /// Returns the element at the given [index] as a [bool].
  ///
  /// {@macro cbl.ArrayInterface.typedDefaultedGetter}
  bool boolean(int index);

  /// Returns the element at the given [index] as a [Blob].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Blob? blob(int index);

  /// Returns the element at the given [index] as a [DateTime].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  DateTime? date(int index);

  /// Returns the element at the given [index] as an [Array].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Array? array(int index);

  /// Returns the element at the given [index] as a [Dictionary].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  Dictionary? dictionary(int index);

  /// Deeply converts this array into a simple JSON representation and returns
  /// it.
  ///
  /// {@template cbl.ArrayInterface.toPrimitiveObjectConversion}
  /// ## Type conversion
  ///
  /// Values of type:
  ///  - [int], [double], [bool], `null` and [String] are not converted.
  ///  - [DateTime] TODO
  ///  - [Blob] TODO
  ///  - [Array] are converted to a list of type `List<Object?>` where each
  ///    element has been recursively converted.
  ///  - [Dictionary]s are converted to a map of type `Map<String, dynamic>`
  ///    where each value has been recursively converted.
  /// {@endtemplate}
  List<Object?> toList();
}

/// Provides readonly access to array data.
abstract class Array implements ArrayInterface, Iterable<Object?> {
  /// Returns a mutable copy of this array.
  MutableArray toMutable();
}

abstract class ArrayImpl with IterableMixin<Object?> implements Array {
  @override
  Iterator<Object?> get iterator => throw UnimplementedError();

  @override
  bool operator ==(Object object) => throw UnimplementedError();

  @override
  int get hashCode => throw UnimplementedError();
}

/// Defines a set of methods for getting and setting array data.
abstract class MutableArrayInterface
    implements ArrayInterface, MutableArrayFragment {
  /// Sets a [value] [at] the given index.
  ///
  /// {@template cbl.MutableArray.allowedValueTypes}
  ///
  /// {@template cbl.MutableArrayInterface.setter}
  /// Throws a [RangeError] if the index is ouf of range.
  /// {@endtemplate}
  void setValue(Object? value, {required int at});

  /// Sets a [String] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setString(String? value, {required int at});

  /// Sets a [num] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setNumber(num? value, {required int at});

  /// Sets an integer number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setInteger(int value, {required int at});

  /// Sets a floating point number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setFloat(double value, {required int at});

  /// Sets a [bool] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setBoolean(bool value, {required int at});

  /// Sets a [DateTime] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setDate(DateTime? value, {required int at});

  /// Sets a [Blob] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setBlob(Blob? value, {required int at});

  /// Sets an [Array] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setArray(Array? value, {required int at});

  /// Sets a [Dictionary] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.setter}
  void setDictionary(Dictionary? value, {required int at});

  /// Adds a [value] at the end of this array.
  ///
  /// {@template cbl.MutableArray.allowedValueTypes}
  void addValue(Object? value);

  /// Adds a [String] at the end of this array.
  void addString(String? value);

  /// Adds a [num] at the end of this array.
  void addNumber(num? value);

  /// Adds a integer number at the end of this array.
  void addInteger(int value);

  /// Adds a floating point number at the end of this array.
  void addFloat(double value);

  /// Adds a [Blob] at the end of this array.
  void addBlob(Blob? value);

  /// Adds a [bool] at the end of this array.
  void addBoolean(bool value);

  /// Adds a [DateTime] at the end of this array.
  void addDate(DateTime? value);

  /// Adds an [Array] at the end of this array.
  void addArray(Array? value);

  /// Adds a [Dictionary] at the end of this array.
  void addDictionary(Dictionary? value);

  /// Inserst a [value] [at] the given index.
  ///
  /// {@template cbl.MutableArray.allowedValueTypes}
  ///
  /// {@template cbl.MutableArrayInterface.inserter}
  /// Throws a [RangeError] if the index is ouf of range.
  /// {@endtemplate}
  void insertValue(Object? value, {required int at});

  /// Inserts a [String] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertString(String? value, {required int at});

  /// Inserts a [num] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertNumber(num? value, {required int at});

  /// Inserts an integer number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertInteger(int value, {required int at});

  /// Inserts a floating point number [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertFloat(double value, {required int at});

  /// Inserts a [bool] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertBoolean(bool value, {required int at});

  /// Inserts a [DateTime] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertDate(DateTime? value, {required int at});

  /// Inserts a [Blob] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertBlob(Blob? value, {required int at});

  /// Inserts an [Array] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertArray(Array? value, {required int at});

  /// Inserts a [Dictionary] [at] the given index.
  ///
  /// {@macro cbl.MutableArrayInterface.inserter}
  void insertDictionary(Dictionary? value, {required int at});

  /// Replaces the elements of this array with those of the given [Iterable].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  void setData(Iterable<Object?> data);

  /// Removes the value at the given [index].
  void removeValue(int index);

  /// Returns the element at the given [index] as a [MutableArray].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  @override
  MutableArray? array(int index);

  /// Returns the element at the given [index] as a [MutableDictionary].
  ///
  /// {@macro cbl.ArrayInterface.typedNullableGetter}
  @override
  MutableDictionary? dictionary(int index);
}

/// Provides access to array data.
abstract class MutableArray implements Array, MutableArrayInterface {
  /// Creates a [MutableArray], optionally initialized with [data].
  ///
  /// {@template cbl.MutableArray.allowedValueTypes}
  /// Allowed value types are [Iterable], [Array], [Blob], [DateTime],
  /// [Map<String, Object?>], [Dictionary], `null`, number types, and [String].
  ///
  /// The collections must contain only the above types.
  /// {@endtemplate}
  factory MutableArray([Iterable<Object?>? data]) => throw UnimplementedError();
}

abstract class MutableArrayImpl extends ArrayImpl implements MutableArray {}
