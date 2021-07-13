import 'array.dart';
import 'blob.dart';
import 'dictionary.dart';

/// Readonly access to the data value wrapped by a [Fragment] object.
abstract class FragmentInterface {
  /// The value of this fragment.
  Object? get value;

  /// The value of this fragment as a [String].
  String? get string;

  /// The value of this fragment as an integer number.
  int get integer;

  /// The value of this fragment as a floating point number.
  double get float;

  /// The value of this fragment as a [num].
  num? get number;

  /// The value of this fragment as a [bool].
  bool get boolean;

  /// The value of this fragment as a [DateTime].
  DateTime? get date;

  /// The value of this fragment as a [Blob].
  Blob? get blob;

  /// The value of this fragment as an [Array].
  Array? get array;

  /// The value of this fragment as a [Dictionary].
  Dictionary? get dictionary;

  /// Whether the value of this fragment exists.
  bool get exists;
}

/// Read and write access to the data value wrapped by a [Fragment] object.
abstract class MutableFragmentInterface implements FragmentInterface {
  /// Sets the value of this fragment.
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  set value(Object? value);
  set string(String? value);
  set integer(int value);
  set float(double value);
  set number(num? value);
  set boolean(bool value);
  set date(DateTime? value);
  set blob(Blob? value);
  set array(Array? value);
  set dictionary(Dictionary? value);
}

/// Provides subscript access to [Fragment] objects by index.
abstract class ArrayFragment {
  /// Returns a [Fragment] for the value at the given [index].
  Fragment operator [](int index);
}

/// Provides subscript access to [MutableFragment] objects by index.
abstract class MutableArrayFragment {
  /// Returns a [MutableFragment] for the value at the given [index].
  MutableFragment operator [](int index);
}

/// Provides subscript access to [Fragment] objects by key.
abstract class DictionaryFragment {
  /// Returns a [Fragment] for the value at the given [key].
  Fragment operator [](String key);
}

/// Provides subscript access to [MutableFragment] objects by key.
abstract class MutableDictionaryFragment {
  /// Returns a [MutableFragment] for the value at the given [key].
  MutableFragment operator [](String key);
}

/// Provides readonly access to data value.
///
/// [Fragment] also provides subscript access by either key or index to the
/// nested values which are wrapped by [Fragment] objects.
abstract class Fragment
    implements FragmentInterface, ArrayFragment, DictionaryFragment {
  Fragment operator [](Object indexOrKey);
}

class FragmentImpl implements Fragment {
  FragmentImpl._empty();

  FragmentImpl.fromArray(Array array, {required int index})
      : _parent = array,
        _index = index;

  FragmentImpl.fromDictionary(Dictionary dictionary, {required String key})
      : _parent = dictionary,
        _key = key;

  static final _emptyInstance = FragmentImpl._empty();

  dynamic _parent;
  int _index = 0;
  String? _key;

  @override
  Object? get value {
    if (_key != null) {
      return (_parent as Dictionary).value(_key!);
    } else {
      return (_parent as Array).value(_index);
    }
  }

  @override
  String? get string {
    if (_key != null) {
      return (_parent as Dictionary).string(_key!);
    } else {
      return (_parent as Array).string(_index);
    }
  }

  @override
  int get integer {
    if (_key != null) {
      return (_parent as Dictionary).integer(_key!);
    } else {
      return (_parent as Array).integer(_index);
    }
  }

  @override
  double get float {
    if (_key != null) {
      return (_parent as Dictionary).float(_key!);
    } else {
      return (_parent as Array).float(_index);
    }
  }

  @override
  num? get number {
    if (_key != null) {
      return (_parent as Dictionary).number(_key!);
    } else {
      return (_parent as Array).number(_index);
    }
  }

  @override
  bool get boolean {
    if (_key != null) {
      return (_parent as Dictionary).boolean(_key!);
    } else {
      return (_parent as Array).boolean(_index);
    }
  }

  @override
  DateTime? get date {
    if (_key != null) {
      return (_parent as Dictionary).date(_key!);
    } else {
      return (_parent as Array).date(_index);
    }
  }

  @override
  Blob? get blob {
    if (_key != null) {
      return (_parent as Dictionary).blob(_key!);
    } else {
      return (_parent as Array).blob(_index);
    }
  }

  @override
  Array? get array {
    if (_key != null) {
      return (_parent as Dictionary).array(_key!);
    } else {
      return (_parent as Array).array(_index);
    }
  }

  @override
  Dictionary? get dictionary {
    if (_key != null) {
      return (_parent as Dictionary).dictionary(_key!);
    } else {
      return (_parent as Array).dictionary(_index);
    }
  }

  @override
  bool get exists => value != null;

  @override
  Fragment operator [](final Object indexOrKey) =>
      _updateSubscript(indexOrKey) ? this : _emptyInstance;

  bool _updateSubscript(Object indexOrKey) {
    if (indexOrKey is! int && indexOrKey is! String) {
      throw ArgumentError.value(
        indexOrKey,
        'indexOrKey',
        'must be of type int or String',
      );
    }

    final value = this.value;

    if (value is Array && indexOrKey is int) {
      if (value.length >= indexOrKey) {
        return false;
      }
      _parent = value;
      _index = indexOrKey;
      _key = null;
      return true;
    }

    if (value is Dictionary && indexOrKey is String) {
      _parent = value;
      _key = indexOrKey;
      return true;
    }

    return false;
  }
}

/// Provides read and write access to data value.
///
/// [MutableFragment] also provides subscript access by either key or index to
/// the nested values which are wrapped by [MutableFragment] objects.
abstract class MutableFragment
    implements
        Fragment,
        MutableFragmentInterface,
        MutableArrayFragment,
        MutableDictionaryFragment {
  MutableFragment operator [](Object indexOrKey);
}

class MutableFragmentImpl extends FragmentImpl implements MutableFragment {
  MutableFragmentImpl._empty() : super._empty();

  MutableFragmentImpl.fromArray(MutableArray array, {required int index})
      : super.fromArray(array, index: index);

  MutableFragmentImpl.fromDictionary(
    MutableDictionary dictionary, {
    required String key,
  }) : super.fromDictionary(dictionary, key: key);

  static final _emptyInstance = MutableFragmentImpl._empty();

  @override
  set value(Object? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setValue(value, key: _key!);
    } else {
      (_parent as MutableArray).setValue(value, at: _index);
    }
  }

  @override
  set string(String? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setString(value, key: _key!);
    } else {
      (_parent as MutableArray).setString(value, at: _index);
    }
  }

  @override
  set integer(int value) {
    if (_key != null) {
      (_parent as MutableDictionary).setInteger(value, key: _key!);
    } else {
      (_parent as MutableArray).setInteger(value, at: _index);
    }
  }

  @override
  set float(double value) {
    if (_key != null) {
      (_parent as MutableDictionary).setFloat(value, key: _key!);
    } else {
      (_parent as MutableArray).setFloat(value, at: _index);
    }
  }

  @override
  set number(num? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setNumber(value, key: _key!);
    } else {
      (_parent as MutableArray).setNumber(value, at: _index);
    }
  }

  @override
  set boolean(bool value) {
    if (_key != null) {
      (_parent as MutableDictionary).setBoolean(value, key: _key!);
    } else {
      (_parent as MutableArray).setBoolean(value, at: _index);
    }
  }

  @override
  set date(DateTime? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setDate(value, key: _key!);
    } else {
      (_parent as MutableArray).setDate(value, at: _index);
    }
  }

  @override
  set blob(Blob? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setBlob(value, key: _key!);
    } else {
      (_parent as MutableArray).setBlob(value, at: _index);
    }
  }

  @override
  set array(Array? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setArray(value, key: _key!);
    } else {
      (_parent as MutableArray).setArray(value, at: _index);
    }
  }

  @override
  set dictionary(Dictionary? value) {
    if (_key != null) {
      (_parent as MutableDictionary).setDictionary(value, key: _key!);
    } else {
      (_parent as MutableArray).setDictionary(value, at: _index);
    }
  }

  @override
  MutableFragment operator [](final Object indexOrKey) =>
      _updateSubscript(indexOrKey) ? this : _emptyInstance;
}
