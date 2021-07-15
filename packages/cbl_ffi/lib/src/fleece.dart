import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'base.dart';
import 'bindings.dart';
import 'utils.dart';

// === Common ==================================================================

class FLCopyFlag extends Option {
  const FLCopyFlag._(String name, int bits) : super(name, bits);

  static const deepCopy = FLCopyFlag._('deepCopy', 1);
  static const copyImmutables = FLCopyFlag._('copyImmutables', 2);

  static const values = [deepCopy, copyImmutables];
}

// === Error ===================================================================

enum FLErrorCode {
  noError,
  memoryError,
  outOfRange,
  invalidData,
  encodeError,
  jsonError,
  unknownValue,
  internalError,
  notFound,
  sharedKeysStateError,
  posixError,
  unsupported,
}

extension FLErrorCodeIntExt on int {
  FLErrorCode toFleeceErrorCode() {
    assert(this >= 0 && this <= 12);
    return FLErrorCode.values[this];
  }
}

late final _globalFleeceErrorCode =
    CBLBindings.instance.fleece._globalFleeceErrorCode;

void _checkFleeceError() {
  final code = _globalFleeceErrorCode.value.toFleeceErrorCode();
  if (code != FLErrorCode.noError) {
    throw CBLErrorException(CBLErrorDomain.fleece, code, 'Fleece error');
  }
}

extension _FleeceErrorExt<T> on T {
  T checkFleeceError() {
    final self = this;
    if (this == nullptr || self is FLSliceResult && self.buf == nullptr) {
      _checkFleeceError();
    }
    return this;
  }
}

// === Slice ===================================================================

class FLSlice extends Struct {
  external Pointer<Uint8> buf;

  // TODO: use correct type
  // This is actually a size_t, but Dart FFI does not support it yet.
  // See https://github.com/dart-lang/sdk/issues/36140.
  // We work around this by translating between an actual FLSlice(Result)
  // and this fixed size struct. Also applies to FLSliceResult, FLString and
  // FLStringResult.
  @Uint64()
  external int size;
}

extension FLSliceExt on FLSlice {
  bool get isNull => buf == nullptr;
  Uint8List? toUint8List() =>
      isNull ? null : Uint8List.fromList(buf.asTypedList(size));
}

class FLSliceResult extends Struct {
  external Pointer<Uint8> buf;

  @Uint64()
  external int size;
}

extension FLResultSliceExt on FLSliceResult {
  bool get isNull => buf == nullptr;
  Uint8List? toUint8List() =>
      isNull ? null : Uint8List.fromList(buf.asTypedList(size));
}

class FLString extends Struct {
  external Pointer<Uint8> buf;

  @Uint64()
  external int size;
}

extension FLStringExt on FLString {
  bool get isNull => buf == nullptr;
  String? toDartString() =>
      isNull ? null : buf.cast<Utf8>().toDartString(length: size);
}

class FLStringResult extends Struct {
  external Pointer<Uint8> buf;

  @Uint64()
  external int size;
}

extension FLStringResultExt on FLStringResult {
  bool get isNull => buf == nullptr;
  String? toDartStringAndRelease() {
    if (isNull) {
      return null;
    }

    final result = buf.cast<Utf8>().toDartString(length: size);

    CBLBindings.instance.fleece.slice.releaseStringResult(this);

    return result;
  }
}

late final nullFLSlice = CBLBindings.instance.fleece.slice.nullSlice;
late final nullFLString =
    CBLBindings.instance.fleece.slice.nullSlice.cast<FLString>();
late final globalFLSlice = CBLBindings.instance.fleece.slice.globalSlice;
late final globalFLSliceResult =
    CBLBindings.instance.fleece.slice.globalSliceResult;
late final globalFLString =
    CBLBindings.instance.fleece.slice.globalSlice.cast<FLString>();

extension TypedDataFLSliceExt on TypedData {
  Pointer<FLSlice> copyToGlobalSliceInArena() {
    final buf = zoneArena.allocate<Uint8>(lengthInBytes);

    buf.asTypedList(lengthInBytes).setAll(0, buffer.asUint8List());

    globalFLSlice.ref
      ..buf = buf
      ..size = lengthInBytes;

    return globalFLSlice;
  }
}

typedef CBLDart_FLSlice_Equal_C = Uint8 Function(FLSlice a, FLSlice b);
typedef CBLDart_FLSlice_Equal = int Function(FLSlice a, FLSlice b);

typedef CBLDart_FLSlice_Compare_C = Int64 Function(FLSlice a, FLSlice b);
typedef CBLDart_FLSlice_Compare = int Function(FLSlice a, FLSlice b);

typedef CBLDart_FLSliceResult_New_C = FLSliceResult Function(Uint64 size);
typedef CBLDart_FLSliceResult_New = FLSliceResult Function(int size);

typedef CBLDart_FLSlice_Copy_C = FLSliceResult Function(FLSlice slice);
typedef CBLDart_FLSlice_Copy = FLSliceResult Function(FLSlice slice);

typedef CBLDart_FLSliceResult_BindToDartObject_C = Void Function(
  Handle object,
  FLSliceResult slice,
  Uint8 retain,
);
typedef CBLDart_FLSliceResult_BindToDartObject = void Function(
  Object object,
  FLSliceResult slice,
  int retain,
);

typedef CBLDart_FLSliceResult_Release_C = Void Function(FLSliceResult);
typedef CBLDart_FLSliceResult_Release = void Function(FLSliceResult);
typedef CBLDart_FLStringResult_Release_C = Void Function(FLStringResult);
typedef CBLDart_FLStringResult_Release = void Function(FLStringResult);

class SliceBindings extends Bindings {
  SliceBindings(Bindings parent) : super(parent) {
    _equal = libs.cblDart
        .lookupFunction<CBLDart_FLSlice_Equal_C, CBLDart_FLSlice_Equal>(
      'CBLDart_FLSlice_Equal',
    );
    _compare = libs.cblDart
        .lookupFunction<CBLDart_FLSlice_Compare_C, CBLDart_FLSlice_Compare>(
      'CBLDart_FLSlice_Compare',
    );
    _new = libs.cblDart
        .lookupFunction<CBLDart_FLSliceResult_New_C, CBLDart_FLSliceResult_New>(
      'CBLDart_FLSliceResult_New',
    );
    _copy = libs.cblDart
        .lookupFunction<CBLDart_FLSlice_Copy_C, CBLDart_FLSlice_Copy>(
      'CBLDart_FLSlice_Copy',
    );
    _bindToDartObject = libs.cblDart.lookupFunction<
        CBLDart_FLSliceResult_BindToDartObject_C,
        CBLDart_FLSliceResult_BindToDartObject>(
      'CBLDart_FLSliceResult_BindToDartObject',
    );
    _releaseSliceResult = libs.cblDart.lookupFunction<
        CBLDart_FLSliceResult_Release_C, CBLDart_FLSliceResult_Release>(
      'CBLDart_FLSliceResult_Release',
    );
    _releaseStringResult = libs.cblDart.lookupFunction<
        CBLDart_FLStringResult_Release_C, CBLDart_FLStringResult_Release>(
      'CBLDart_FLSliceResult_Release',
    );
  }

  late final Pointer<FLSlice> nullSlice = malloc()
    ..ref.buf = nullptr
    ..ref.size = 0;
  late final Pointer<FLSlice> globalSlice = malloc();
  late final Pointer<FLSliceResult> globalSliceResult = globalSlice.cast();

  late final CBLDart_FLSlice_Equal _equal;
  late final CBLDart_FLSlice_Compare _compare;

  late final CBLDart_FLSliceResult_New _new;
  late final CBLDart_FLSlice_Copy _copy;
  late final CBLDart_FLSliceResult_BindToDartObject _bindToDartObject;
  late final CBLDart_FLSliceResult_Release _releaseSliceResult;
  late final CBLDart_FLStringResult_Release _releaseStringResult;

  bool equal(FLSlice a, FLSlice b) {
    return _equal(a, b).toBool();
  }

  int compare(FLSlice a, FLSlice b) {
    return _compare(a, b);
  }

  FLSliceResult create(int size) {
    return _new(size);
  }

  FLSliceResult copy(FLSlice slice) {
    return _copy(slice);
  }

  void bindToDartObject(Object object, FLSliceResult sliceResult, bool retain) {
    _bindToDartObject(object, sliceResult, retain.toInt());
  }

  void releaseSliceResult(FLSliceResult result) {
    _releaseSliceResult(result);
  }

  void releaseStringResult(FLStringResult result) {
    _releaseStringResult(result);
  }

  @override
  void dispose() {
    malloc.free(nullSlice);
    malloc.free(globalSlice);
    super.dispose();
  }
}

// === Slot ====================================================================

class FLSlot extends Opaque {}

typedef FLSlot_SetNull_C = Void Function(Pointer<FLSlot> slot);
typedef FLSlot_SetNull = void Function(Pointer<FLSlot> slot);

typedef FLSlot_SetBool_C = Void Function(Pointer<FLSlot> slot, Uint8 value);
typedef FLSlot_SetBool = void Function(Pointer<FLSlot> slot, int value);

typedef FLSlot_SetInt_C = Void Function(Pointer<FLSlot> slot, Int64 value);
typedef FLSlot_SetInt = void Function(Pointer<FLSlot> slot, int value);

typedef FLSlot_SetDouble_C = Void Function(Pointer<FLSlot> slot, Double value);
typedef FLSlot_SetDouble = void Function(Pointer<FLSlot> slot, double value);

typedef CBLDart_FLSlot_SetString_C = Void Function(
  Pointer<FLSlot> slot,
  FLString value,
);
typedef CBLDart_FLSlot_SetString = void Function(
  Pointer<FLSlot> slot,
  FLString value,
);

typedef FLSlot_SetData_C = Void Function(
  Pointer<FLSlot> slot,
  FLSlice value,
);
typedef FLSlot_SetData = void Function(
  Pointer<FLSlot> slot,
  FLSlice value,
);

typedef FLSlot_SetValue_C = Void Function(
  Pointer<FLSlot> slot,
  Pointer<FLValue> value,
);
typedef FLSlot_SetValue = void Function(
  Pointer<FLSlot> slot,
  Pointer<FLValue> value,
);

class SlotBindings extends Bindings {
  SlotBindings(Bindings parent) : super(parent) {
    _setNull = libs.cbl.lookupFunction<FLSlot_SetNull_C, FLSlot_SetNull>(
      'FLSlot_SetNull',
    );
    _setBool = libs.cbl.lookupFunction<FLSlot_SetBool_C, FLSlot_SetBool>(
      'FLSlot_SetBool',
    );
    _setInt = libs.cbl.lookupFunction<FLSlot_SetInt_C, FLSlot_SetInt>(
      'FLSlot_SetInt',
    );
    _setDouble = libs.cbl.lookupFunction<FLSlot_SetDouble_C, FLSlot_SetDouble>(
      'FLSlot_SetDouble',
    );
    _setString = libs.cblDart
        .lookupFunction<CBLDart_FLSlot_SetString_C, CBLDart_FLSlot_SetString>(
      'CBLDart_FLSlot_SetString',
    );
    _setData = libs.cblDart.lookupFunction<FLSlot_SetData_C, FLSlot_SetData>(
      'FLSlot_SetData',
    );
    _setValue = libs.cbl.lookupFunction<FLSlot_SetValue_C, FLSlot_SetValue>(
      'FLSlot_SetValue',
    );
  }

  late final FLSlot_SetNull _setNull;
  late final FLSlot_SetBool _setBool;
  late final FLSlot_SetInt _setInt;
  late final FLSlot_SetDouble _setDouble;
  late final CBLDart_FLSlot_SetString _setString;
  late final FLSlot_SetData _setData;
  late final FLSlot_SetValue _setValue;

  void setNull(Pointer<FLSlot> slot) {
    _setNull(slot);
  }

  void setBool(Pointer<FLSlot> slot, bool value) {
    _setBool(slot, value.toInt());
  }

  void setInt(Pointer<FLSlot> slot, int value) {
    _setInt(slot, value);
  }

  void setDouble(Pointer<FLSlot> slot, double value) {
    _setDouble(slot, value);
  }

  void setString(Pointer<FLSlot> slot, String value) {
    stringTable
        .autoFree(() => _setString(slot, stringTable.flString(value).ref));
  }

  void setData(Pointer<FLSlot> slot, TypedData value) {
    withZoneArena(() => _setData(slot, value.copyToGlobalSliceInArena().ref));
  }

  void setValue(Pointer<FLSlot> slot, Pointer<FLValue> value) {
    _setValue(slot, value);
  }
}

// === Doc =====================================================================

class FLDoc extends Opaque {}

typedef CBLDart_FLDoc_FromResultData_C = Pointer<FLDoc> Function(
  FLSliceResult data,
  Uint8 trust,
  Pointer<Void> sharedKeys,
  FLSlice externalData,
);
typedef CBLDart_FLDoc_FromResultData = Pointer<FLDoc> Function(
  FLSliceResult data,
  int trust,
  Pointer<Void> sharedKeys,
  FLSlice externalData,
);

typedef CBLDart_FLDoc_FromJSON = Pointer<FLDoc> Function(
  FLString json,
  Pointer<Uint32> errorOut,
);

typedef CBLDart_FLDoc_BindToDartObject_C = Void Function(
  Handle object,
  Pointer<FLDoc> doc,
);
typedef CBLDart_FLDoc_BindToDartObject = void Function(
  Object object,
  Pointer<FLDoc> doc,
);

typedef FLDoc_GetRoot = Pointer<FLValue> Function(Pointer<FLDoc> doc);

class DocBindings extends Bindings {
  DocBindings(Bindings parent) : super(parent) {
    _fromResultData = libs.cblDart.lookupFunction<
        CBLDart_FLDoc_FromResultData_C, CBLDart_FLDoc_FromResultData>(
      'CBLDart_FLDoc_FromResultData',
    );
    _fromJSON = libs.cblDart
        .lookupFunction<CBLDart_FLDoc_FromJSON, CBLDart_FLDoc_FromJSON>(
      'CBLDart_FLDoc_FromJSON',
    );
    _bindToDartObject = libs.cblDart.lookupFunction<
        CBLDart_FLDoc_BindToDartObject_C, CBLDart_FLDoc_BindToDartObject>(
      'CBLDart_FLDoc_BindToDartObject',
    );
    _getRoot = libs.cbl.lookupFunction<FLDoc_GetRoot, FLDoc_GetRoot>(
      'FLDoc_GetRoot',
    );
  }

  late final CBLDart_FLDoc_FromResultData _fromResultData;
  late final CBLDart_FLDoc_FromJSON _fromJSON;
  late final CBLDart_FLDoc_BindToDartObject _bindToDartObject;
  late final FLDoc_GetRoot _getRoot;

  Pointer<FLDoc>? fromResultData(
    FLSliceResult data,
    FLTrust trust,
  ) {
    return _fromResultData(
      data,
      trust.toInt(),
      nullptr,
      nullFLSlice.ref,
    ).toNullable();
  }

  Pointer<FLDoc> fromJson(String json) {
    return stringTable.autoFree(() {
      return _fromJSON(stringTable.flString(json).ref, _globalFleeceErrorCode)
          .checkFleeceError();
    });
  }

  void bindToDartObject(Object object, Pointer<FLDoc> doc) {
    _bindToDartObject(object, doc);
  }

  Pointer<FLValue> getRoot(Pointer<FLDoc> doc) {
    return _getRoot(doc);
  }
}

// === Value ===================================================================

class FLValue extends Opaque {}

enum FLValueType {
  undefined,
  Null,
  boolean,
  number,
  string,
  data,
  array,
  dict,
}

extension on int {
  FLValueType toFLValueType() {
    assert(this >= -1 && this <= 6);
    return FLValueType.values[this + 1];
  }
}

typedef CBLDart_FLValue_BindToDartObject_C = Void Function(
  Handle object,
  Pointer<FLValue> value,
  Uint8 retain,
);
typedef CBLDart_FLValue_BindToDartObject = void Function(
  Object object,
  Pointer<FLValue> value,
  int retain,
);

typedef FLValue_FindDoc = Pointer<FLDoc> Function(Pointer<FLValue>);

typedef FLValue_GetType_C = Int8 Function(Pointer<FLValue> value);
typedef FLValue_GetType = int Function(Pointer<FLValue> value);

typedef FLValue_IsInteger_C = Uint8 Function(Pointer<FLValue> value);
typedef FLValue_IsInteger = int Function(Pointer<FLValue> value);

typedef FLValue_IsDouble_C = Uint8 Function(Pointer<FLValue> value);
typedef FLValue_IsDouble = int Function(Pointer<FLValue> value);

typedef FLValue_AsBool_C = Uint8 Function(Pointer<FLValue> value);
typedef FLValue_AsBool = int Function(Pointer<FLValue> value);

typedef FLValue_AsInt_C = Int64 Function(Pointer<FLValue> value);
typedef FLValue_AsInt = int Function(Pointer<FLValue> value);

typedef FLValue_AsDouble_C = Double Function(Pointer<FLValue> value);
typedef FLValue_AsDouble = double Function(Pointer<FLValue> value);

typedef CBLDart_FLValue_AsString_C = FLString Function(Pointer<FLValue> value);
typedef CBLDart_FLValue_AsString = FLString Function(Pointer<FLValue> value);

typedef CBLDart_FLValue_AsData_C = FLSlice Function(Pointer<FLValue> value);
typedef CBLDart_FLValue_AsData = FLSlice Function(Pointer<FLValue> value);

typedef CBLDart_FLValue_ToString_C = FLStringResult Function(
  Pointer<FLValue> value,
);
typedef CBLDart_FLValue_ToString = FLStringResult Function(
  Pointer<FLValue> value,
);

typedef FLValue_IsEqual_C = Uint8 Function(
  Pointer<FLValue> v1,
  Pointer<FLValue> v2,
);
typedef FLValue_IsEqual = int Function(
  Pointer<FLValue> v1,
  Pointer<FLValue> v2,
);

typedef CBLDart_FLValue_ToJSONX_C = FLStringResult Function(
  Pointer<FLValue> value,
  Uint8 json5,
  Uint8 canonicalForm,
);
typedef CBLDart_FLValue_ToJSONX = FLStringResult Function(
  Pointer<FLValue> value,
  int json5,
  int canonicalForm,
);

class ValueBindings extends Bindings {
  ValueBindings(Bindings parent) : super(parent) {
    _bindToDartObject = libs.cblDart.lookupFunction<
        CBLDart_FLValue_BindToDartObject_C, CBLDart_FLValue_BindToDartObject>(
      'CBLDart_FLValue_BindToDartObject',
    );
    _findDoc = libs.cbl.lookupFunction<FLValue_FindDoc, FLValue_FindDoc>(
      'FLValue_FindDoc',
    );
    _getType = libs.cbl.lookupFunction<FLValue_GetType_C, FLValue_GetType>(
      'FLValue_GetType',
    );
    _isInteger =
        libs.cbl.lookupFunction<FLValue_IsInteger_C, FLValue_IsInteger>(
      'FLValue_IsInteger',
    );
    _isDouble = libs.cbl.lookupFunction<FLValue_IsDouble_C, FLValue_IsDouble>(
      'FLValue_IsDouble',
    );
    _asBool = libs.cbl.lookupFunction<FLValue_AsBool_C, FLValue_AsBool>(
      'FLValue_AsBool',
    );
    _asInt = libs.cbl.lookupFunction<FLValue_AsInt_C, FLValue_AsInt>(
      'FLValue_AsInt',
    );
    _asDouble = libs.cbl.lookupFunction<FLValue_AsDouble_C, FLValue_AsDouble>(
      'FLValue_AsDouble',
    );
    _asString = libs.cblDart
        .lookupFunction<CBLDart_FLValue_AsString_C, CBLDart_FLValue_AsString>(
      'CBLDart_FLValue_AsString',
    );
    _asData = libs.cblDart
        .lookupFunction<CBLDart_FLValue_AsData_C, CBLDart_FLValue_AsData>(
      'CBLDart_FLValue_AsData',
    );
    _scalarToString = libs.cblDart
        .lookupFunction<CBLDart_FLValue_ToString_C, CBLDart_FLValue_ToString>(
      'CBLDart_FLValue_ToString',
    );
    _isEqual = libs.cbl.lookupFunction<FLValue_IsEqual_C, FLValue_IsEqual>(
      'FLValue_IsEqual',
    );
    _toJson = libs.cblDart
        .lookupFunction<CBLDart_FLValue_ToJSONX_C, CBLDart_FLValue_ToJSONX>(
      'CBLDart_FLValue_ToJSONX',
    );
  }

  late final CBLDart_FLValue_BindToDartObject _bindToDartObject;
  late final FLValue_FindDoc _findDoc;
  late final FLValue_GetType _getType;
  late final FLValue_IsInteger _isInteger;
  late final FLValue_IsDouble _isDouble;
  late final FLValue_AsBool _asBool;
  late final FLValue_AsInt _asInt;
  late final FLValue_AsDouble _asDouble;
  late final CBLDart_FLValue_AsString _asString;
  late final CBLDart_FLValue_AsData _asData;
  late final CBLDart_FLValue_ToString _scalarToString;
  late final FLValue_IsEqual _isEqual;
  late final CBLDart_FLValue_ToJSONX _toJson;

  void bindToDartObject(Object object, Pointer<FLValue> value, bool retain) {
    _bindToDartObject(object, value, retain.toInt());
  }

  Pointer<FLDoc> findDoc(Pointer<FLValue> value) {
    return _findDoc(value);
  }

  FLValueType getType(Pointer<FLValue> value) {
    return _getType(value).toFLValueType();
  }

  bool isInteger(Pointer<FLValue> value) {
    return _isInteger(value).toBool();
  }

  bool isDouble(Pointer<FLValue> value) {
    return _isDouble(value).toBool();
  }

  bool asBool(Pointer<FLValue> value) {
    return _asBool(value).toBool();
  }

  int asInt(Pointer<FLValue> value) {
    return _asInt(value);
  }

  double asDouble(Pointer<FLValue> value) {
    return _asDouble(value);
  }

  String? asString(Pointer<FLValue> value) {
    return _asString(value).toDartString();
  }

  Uint8List? asData(Pointer<FLValue> value) {
    return _asData(value).toUint8List();
  }

  String? scalarToString(Pointer<FLValue> value) {
    return _scalarToString(value).toDartStringAndRelease();
  }

  bool isEqual(Pointer<FLValue> a, Pointer<FLValue> b) {
    return _isEqual(a, b).toBool();
  }

  String toJSONX(
    Pointer<FLValue> value,
    bool json5,
    bool canonicalForm,
  ) {
    return _toJson(value, json5.toInt(), canonicalForm.toInt())
        .toDartStringAndRelease()!;
  }
}

// === Array ===================================================================

class FLArray extends Opaque {}

typedef FLArray_Count_C = Uint32 Function(Pointer<FLArray> array);
typedef FLArray_Count = int Function(Pointer<FLArray> array);

typedef FLArray_IsEmpty_C = Uint8 Function(Pointer<FLArray> array);
typedef FLArray_IsEmpty = int Function(Pointer<FLArray> array);

typedef FLArray_AsMutable = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
);

typedef FLArray_Get_C = Pointer<FLValue> Function(
  Pointer<FLArray> array,
  Uint32 index,
);
typedef FLArray_Get = Pointer<FLValue> Function(
  Pointer<FLArray> array,
  int index,
);

class ArrayBindings extends Bindings {
  ArrayBindings(Bindings parent) : super(parent) {
    _count = libs.cbl.lookupFunction<FLArray_Count_C, FLArray_Count>(
      'FLArray_Count',
    );
    _isEmpty = libs.cbl.lookupFunction<FLArray_IsEmpty_C, FLArray_IsEmpty>(
      'FLArray_IsEmpty',
    );
    _asMutable = libs.cbl.lookupFunction<FLArray_AsMutable, FLArray_AsMutable>(
      'FLArray_AsMutable',
    );
    _get = libs.cbl.lookupFunction<FLArray_Get_C, FLArray_Get>(
      'FLArray_Get',
    );
  }

  late final FLArray_Count _count;
  late final FLArray_IsEmpty _isEmpty;
  late final FLArray_AsMutable _asMutable;
  late final FLArray_Get _get;

  int count(Pointer<FLArray> array) {
    return _count(array);
  }

  bool isEmpty(Pointer<FLArray> array) {
    return _isEmpty(array).toBool();
  }

  Pointer<FLMutableArray>? asMutable(Pointer<FLArray> array) {
    return _asMutable(array).toNullable();
  }

  Pointer<FLValue> get(Pointer<FLArray> array, int index) {
    return _get(array, index);
  }
}

// === MutabelArray ============================================================

class FLMutableArray extends Opaque {}

typedef FLArray_MutableCopy_C = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
  Uint32 flags,
);
typedef FLArray_MutableCopy = Pointer<FLMutableArray> Function(
  Pointer<FLArray> array,
  int flags,
);

typedef FLMutableArray_New = Pointer<FLMutableArray> Function();

typedef FLMutableArray_GetSource = Pointer<FLArray> Function(
  Pointer<FLMutableArray> array,
);

typedef FLMutableArray_IsChanged_C = Uint8 Function(
  Pointer<FLMutableArray> array,
);
typedef FLMutableArray_IsChanged = int Function(
  Pointer<FLMutableArray> array,
);

typedef FLMutableArray_Set_C = Pointer<FLSlot> Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef FLMutableArray_Set = Pointer<FLSlot> Function(
  Pointer<FLMutableArray> array,
  int index,
);

typedef FLMutableArray_Append = Pointer<FLSlot> Function(
  Pointer<FLMutableArray> array,
);

typedef FLMutableArray_Insert_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 firstIndex,
  Uint32 count,
);
typedef FLMutableArray_Insert = void Function(
  Pointer<FLMutableArray> array,
  int firstIndex,
  int count,
);

typedef FLMutableArray_Remove_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 firstIndex,
  Uint32 count,
);
typedef FLMutableArray_Remove = void Function(
  Pointer<FLMutableArray> array,
  int firstIndex,
  int count,
);

typedef FLMutableArray_Resize_C = Void Function(
  Pointer<FLMutableArray> array,
  Uint32 size,
);
typedef FLMutableArray_Resize = void Function(
  Pointer<FLMutableArray> array,
  int size,
);

typedef FLMutableArray_GetMutableArray_C = Pointer<FLMutableArray> Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef FLMutableArray_GetMutableArray = Pointer<FLMutableArray> Function(
  Pointer<FLMutableArray> array,
  int index,
);

typedef FLMutableArray_GetMutableDict_C = Pointer<FLMutableDict> Function(
  Pointer<FLMutableArray> array,
  Uint32 index,
);
typedef FLMutableArray_GetMutableDict = Pointer<FLMutableDict> Function(
  Pointer<FLMutableArray> array,
  int index,
);

class MutableArrayBindings extends Bindings {
  MutableArrayBindings(Bindings parent) : super(parent) {
    _mutableCopy =
        libs.cbl.lookupFunction<FLArray_MutableCopy_C, FLArray_MutableCopy>(
      'FLArray_MutableCopy',
    );
    _new = libs.cbl.lookupFunction<FLMutableArray_New, FLMutableArray_New>(
      'FLMutableArray_New',
    );
    _getSource = libs.cbl
        .lookupFunction<FLMutableArray_GetSource, FLMutableArray_GetSource>(
      'FLMutableArray_GetSource',
    );
    _isChanged = libs.cbl
        .lookupFunction<FLMutableArray_IsChanged_C, FLMutableArray_IsChanged>(
      'FLMutableArray_IsChanged',
    );
    _set = libs.cbl.lookupFunction<FLMutableArray_Set_C, FLMutableArray_Set>(
      'FLMutableArray_Set',
    );
    _append =
        libs.cbl.lookupFunction<FLMutableArray_Append, FLMutableArray_Append>(
      'FLMutableArray_Append',
    );
    _insert =
        libs.cbl.lookupFunction<FLMutableArray_Insert_C, FLMutableArray_Insert>(
      'FLMutableArray_Insert',
    );
    _remove =
        libs.cbl.lookupFunction<FLMutableArray_Remove_C, FLMutableArray_Remove>(
      'FLMutableArray_Remove',
    );
    _resize =
        libs.cbl.lookupFunction<FLMutableArray_Resize_C, FLMutableArray_Resize>(
      'FLMutableArray_Resize',
    );
    _getMutableArray = libs.cbl.lookupFunction<FLMutableArray_GetMutableArray_C,
        FLMutableArray_GetMutableArray>(
      'FLMutableArray_GetMutableArray',
    );
    _getMutableDict = libs.cbl.lookupFunction<FLMutableArray_GetMutableDict_C,
        FLMutableArray_GetMutableDict>(
      'FLMutableArray_GetMutableDict',
    );
  }

  late final FLArray_MutableCopy _mutableCopy;
  late final FLMutableArray_New _new;
  late final FLMutableArray_GetSource _getSource;
  late final FLMutableArray_IsChanged _isChanged;
  late final FLMutableArray_Set _set;
  late final FLMutableArray_Append _append;
  late final FLMutableArray_Insert _insert;
  late final FLMutableArray_Remove _remove;
  late final FLMutableArray_Resize _resize;
  late final FLMutableArray_GetMutableArray _getMutableArray;
  late final FLMutableArray_GetMutableDict _getMutableDict;

  Pointer<FLMutableArray> mutableCopy(
    Pointer<FLArray> array,
    Set<FLCopyFlag> flags,
  ) {
    return _mutableCopy(array, flags.toCFlags());
  }

  Pointer<FLMutableArray> create() {
    return _new();
  }

  Pointer<FLArray> getSource(Pointer<FLMutableArray> array) {
    return _getSource(array);
  }

  bool isChanged(Pointer<FLMutableArray> array) {
    return _isChanged(array).toBool();
  }

  Pointer<FLSlot> set(Pointer<FLMutableArray> array, int index) {
    return _set(array, index);
  }

  Pointer<FLSlot> append(Pointer<FLMutableArray> array) {
    return _append(array);
  }

  void insert(Pointer<FLMutableArray> array, int index, int count) {
    return _insert(array, index, count);
  }

  void remove(Pointer<FLMutableArray> array, int firstIndex, int count) {
    return _remove(array, firstIndex, count);
  }

  void resize(Pointer<FLMutableArray> array, int size) {
    return _resize(array, size);
  }

  Pointer<FLMutableArray>? getMutableArray(
    Pointer<FLMutableArray> array,
    int index,
  ) {
    return _getMutableArray(array, index).toNullable();
  }

  Pointer<FLMutableDict>? getMutableDict(
    Pointer<FLMutableArray> array,
    int index,
  ) {
    return _getMutableDict(array, index).toNullable();
  }
}

// === Dict ====================================================================

class FLDict extends Opaque {}

typedef FLDict_Count_C = Uint32 Function(Pointer<FLDict> dict);
typedef FLDict_Count = int Function(Pointer<FLDict> dict);

typedef FLDict_IsEmpty_C = Uint8 Function(Pointer<FLDict> dict);
typedef FLDict_IsEmpty = int Function(Pointer<FLDict> dict);

typedef FLDict_AsMutable = Pointer<FLMutableDict> Function(
  Pointer<FLDict> dict,
);

typedef FLDict_Get = Pointer<FLValue> Function(
  Pointer<FLDict> dict,
  FLString key,
);

class DictBindings extends Bindings {
  DictBindings(Bindings parent) : super(parent) {
    _get = libs.cblDart
        .lookupFunction<FLDict_Get, FLDict_Get>('CBLDart_FLDict_Get');
    _count =
        libs.cbl.lookupFunction<FLDict_Count_C, FLDict_Count>('FLDict_Count');
    _isEmpty = libs.cbl.lookupFunction<FLDict_IsEmpty_C, FLDict_IsEmpty>(
      'FLDict_IsEmpty',
    );
    _asMutable = libs.cbl.lookupFunction<FLDict_AsMutable, FLDict_AsMutable>(
      'FLDict_AsMutable',
    );
  }

  late final FLDict_Get _get;
  late final FLDict_Count _count;
  late final FLDict_IsEmpty _isEmpty;
  late final FLDict_AsMutable _asMutable;

  Pointer<FLValue> get(Pointer<FLDict> dict, String key) {
    return stringTable
        .autoFree(() => _get(dict, stringTable.flString(key).ref));
  }

  int count(Pointer<FLDict> dict) {
    return _count(dict);
  }

  bool isEmpty(Pointer<FLDict> dict) {
    return _isEmpty(dict).toBool();
  }

  Pointer<FLMutableDict>? asMutable(Pointer<FLDict> dict) {
    return _asMutable(dict).toNullable();
  }
}

class DictIterator extends Struct {
  // ignore: unused_element
  external Pointer<Void> get _iterator;
  external FLString get _keyString;
  @Uint8()
  external int get _done;
}

extension DictIteratorExt on DictIterator {
  String? get keyString => _keyString.toDartString();
  bool get done => _done.toBool();
}

typedef CBLDart_FLDictIterator_Begin_C = Pointer<DictIterator> Function(
  Handle object,
  Pointer<FLDict> dict,
);
typedef CBLDart_FLDictIterator_Begin = Pointer<DictIterator> Function(
  Object object,
  Pointer<FLDict> dict,
);

typedef CBLDart_FLDictIterator_Next_C = Void Function(
  Pointer<DictIterator> iterator,
);
typedef CBLDart_FLDictIterator_Next = void Function(
  Pointer<DictIterator> iterator,
);

class DictIteratorBindings extends Bindings {
  DictIteratorBindings(Bindings parent) : super(parent) {
    _begin = libs.cblDart.lookupFunction<CBLDart_FLDictIterator_Begin_C,
        CBLDart_FLDictIterator_Begin>(
      'CBLDart_FLDictIterator_Begin',
    );
    _next = libs.cblDart.lookupFunction<CBLDart_FLDictIterator_Next_C,
        CBLDart_FLDictIterator_Next>(
      'CBLDart_FLDictIterator_Next',
    );
  }

  late final CBLDart_FLDictIterator_Begin _begin;
  late final CBLDart_FLDictIterator_Next _next;

  Pointer<DictIterator> begin(Object object, Pointer<FLDict> dict) {
    return _begin(object, dict);
  }

  void next(Pointer<DictIterator> iterator) {
    _next(iterator);
  }
}

// === MutableDict =============================================================

class FLMutableDict extends Opaque {}

typedef FLDict_MutableCopy_C = Pointer<FLMutableDict> Function(
  Pointer<FLDict> source,
  Uint32 flags,
);
typedef FLDict_MutableCopy = Pointer<FLMutableDict> Function(
  Pointer<FLDict> source,
  int flags,
);

typedef FLMutableDict_New = Pointer<FLMutableDict> Function();

typedef FLMutableDict_GetSource = Pointer<FLDict> Function(
  Pointer<FLMutableDict> dict,
);

typedef FLMutableDict_IsChanged_C = Uint8 Function(Pointer<FLMutableDict> dict);
typedef FLMutableDict_IsChanged = int Function(Pointer<FLMutableDict> dict);

typedef CBLDart_FLMutableDict_Set = Pointer<FLSlot> Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef CBLDart_FLMutableDict_Remove_C = Void Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);
typedef CBLDart_FLMutableDict_Remove = void Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef FLMutableDict_RemoveAll_C = Void Function(Pointer<FLMutableDict> dict);
typedef FLMutableDict_RemoveAll = void Function(Pointer<FLMutableDict> dict);

typedef CBLDart_FLMutableDict_GetMutableArray = Pointer<FLMutableArray>
    Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

typedef CBLDart_FLMutableDict_GetMutableDict = Pointer<FLMutableDict> Function(
  Pointer<FLMutableDict> dict,
  FLString key,
);

class MutableDictBindings extends Bindings {
  MutableDictBindings(Bindings parent) : super(parent) {
    _mutableCopy =
        libs.cbl.lookupFunction<FLDict_MutableCopy_C, FLDict_MutableCopy>(
      'FLDict_MutableCopy',
    );
    _new = libs.cbl.lookupFunction<FLMutableDict_New, FLMutableDict_New>(
      'FLMutableDict_New',
    );
    _getSource = libs.cbl
        .lookupFunction<FLMutableDict_GetSource, FLMutableDict_GetSource>(
      'FLMutableDict_GetSource',
    );
    _isChanged = libs.cbl
        .lookupFunction<FLMutableDict_IsChanged_C, FLMutableDict_IsChanged>(
      'FLMutableDict_IsChanged',
    );
    _set = libs.cblDart
        .lookupFunction<CBLDart_FLMutableDict_Set, CBLDart_FLMutableDict_Set>(
      'CBLDart_FLMutableDict_Set',
    );
    _remove = libs.cblDart.lookupFunction<CBLDart_FLMutableDict_Remove_C,
        CBLDart_FLMutableDict_Remove>(
      'CBLDart_FLMutableDict_Remove',
    );
    _removeAll = libs.cbl
        .lookupFunction<FLMutableDict_RemoveAll_C, FLMutableDict_RemoveAll>(
      'FLMutableDict_RemoveAll',
    );
    _getMutableArray = libs.cblDart.lookupFunction<
        CBLDart_FLMutableDict_GetMutableArray,
        CBLDart_FLMutableDict_GetMutableArray>(
      'CBLDart_FLMutableDict_GetMutableArray',
    );
    _getMutableDict = libs.cblDart.lookupFunction<
        CBLDart_FLMutableDict_GetMutableDict,
        CBLDart_FLMutableDict_GetMutableDict>(
      'CBLDart_FLMutableDict_GetMutableDict',
    );
  }

  late final FLDict_MutableCopy _mutableCopy;
  late final FLMutableDict_New _new;
  late final FLMutableDict_GetSource _getSource;
  late final FLMutableDict_IsChanged _isChanged;
  late final CBLDart_FLMutableDict_Set _set;
  late final CBLDart_FLMutableDict_Remove _remove;
  late final FLMutableDict_RemoveAll _removeAll;
  late final CBLDart_FLMutableDict_GetMutableArray _getMutableArray;
  late final CBLDart_FLMutableDict_GetMutableDict _getMutableDict;

  Pointer<FLMutableDict> mutableCopy(
    Pointer<FLDict> source,
    Set<FLCopyFlag> flags,
  ) {
    return _mutableCopy(source, flags.toCFlags());
  }

  Pointer<FLMutableDict> create() {
    return _new();
  }

  Pointer<FLDict> getSource(Pointer<FLMutableDict> dict) {
    return _getSource(dict);
  }

  bool isChanged(Pointer<FLMutableDict> dict) {
    return _isChanged(dict).toBool();
  }

  Pointer<FLSlot> set(Pointer<FLMutableDict> dict, String key) {
    return stringTable
        .autoFree(() => _set(dict, stringTable.flString(key).ref));
  }

  void remove(Pointer<FLMutableDict> dict, String key) {
    stringTable.autoFree(() => _remove(dict, stringTable.flString(key).ref));
  }

  void removeAll(Pointer<FLMutableDict> dict) {
    _removeAll(dict);
  }

  Pointer<FLMutableArray>? getMutableArray(
    Pointer<FLMutableDict> array,
    String key,
  ) {
    return stringTable.autoFree(() {
      return _getMutableArray(array, stringTable.flString(key).ref)
          .toNullable();
    });
  }

  Pointer<FLMutableDict>? getMutableDict(
    Pointer<FLMutableDict> array,
    String key,
  ) {
    return stringTable.autoFree(() {
      return _getMutableDict(array, stringTable.flString(key).ref).toNullable();
    });
  }
}

// === Decoder =================================================================

enum FLTrust {
  untrusted,
  trusted,
}

extension on FLTrust {
  int toInt() => index;
}

class CBLDart_LoadedFLValue extends Struct {
  @Int8()
  external int _type;
  @Uint8()
  external int _isInteger;
  @Uint32()
  external int collectionSize;
  @Uint8()
  external int _asBool;
  @Int64()
  external int asInt;
  @Double()
  external double asDouble;
  external FLString asString;
  external FLSlice asData;
  external Pointer<FLValue> asValue;
}

// ignore: camel_case_extensions
extension CBLDart_LoadedFLValueExt on CBLDart_LoadedFLValue {
  FLValueType get type => _type.toFLValueType();
  bool get isInteger => _isInteger.toBool();
  bool get asBool => _asBool.toBool();
}

late final Pointer<CBLDart_LoadedFLValue> globalLoadedFLValue =
    CBLBindings.instance.fleece.decoder._globalLoadedFLValue;

typedef CBLDart_FLData_Dump_C = FLStringResult Function(FLSlice slice);
typedef CBLDart_FLData_Dump = FLStringResult Function(FLSlice slice);

typedef CBLDart_FLData_ConvertJSON_C = FLSliceResult Function(
  FLSlice json,
  Pointer<Uint32> errorOut,
);
typedef CBLDart_FLData_ConvertJSON = FLSliceResult Function(
  FLSlice json,
  Pointer<Uint32> errorOut,
);

typedef CBLDart_FLValue_FromData_C = Uint8 Function(
  FLSlice data,
  Uint8 trust,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef CBLDart_FLValue_FromData = int Function(
  FLSlice data,
  int trust,
  Pointer<CBLDart_LoadedFLValue> out,
);

typedef CBLDart_GetLoadedFLValue_C = Void Function(
  Pointer<FLValue> value,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef CBLDart_GetLoadedFLValue = void Function(
  Pointer<FLValue> value,
  Pointer<CBLDart_LoadedFLValue> out,
);

typedef CBLDart_FLArray_GetLoadedFLValue_C = Void Function(
  Pointer<FLArray> array,
  Uint32 index,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef CBLDart_FLArray_GetLoadedFLValue = void Function(
  Pointer<FLArray> array,
  int index,
  Pointer<CBLDart_LoadedFLValue> out,
);

typedef CBLDart_FLDict_GetLoadedFLValue_C = Void Function(
  Pointer<FLDict> dict,
  FLString key,
  Pointer<CBLDart_LoadedFLValue> out,
);
typedef CBLDart_FLDict_GetLoadedFLValue = void Function(
  Pointer<FLDict> dict,
  FLString key,
  Pointer<CBLDart_LoadedFLValue> out,
);

class CBLDart_FLDictIterator2 extends Struct {
  @Uint8()
  external int _isDone;
  // ignore: unused_field
  external Pointer<FLString> _keyOut;
  // ignore: unused_field
  external Pointer<CBLDart_LoadedFLValue> _valueOut;
  // ignore: unused_field
  external Pointer<Void> _iterator;
}

// ignore: camel_case_extensions
extension CBLDart_FLDictIterator2Ext on CBLDart_FLDictIterator2 {
  bool get isDone => _isDone.toBool();
}

typedef CBLDart_FLDictIterator2_Begin_C = Pointer<CBLDart_FLDictIterator2>
    Function(
  Handle object,
  Pointer<FLDict> dict,
  Pointer<FLString> keyOut,
  Pointer<CBLDart_LoadedFLValue> valueOut,
);
typedef CBLDart_FLDictIterator2_Begin = Pointer<CBLDart_FLDictIterator2>
    Function(
  Object object,
  Pointer<FLDict> dict,
  Pointer<FLString> keyOut,
  Pointer<CBLDart_LoadedFLValue> valueOut,
);

typedef CBLDart_FLDictIterator2_Next_C = Void Function(
  Pointer<CBLDart_FLDictIterator2> iterator,
);
typedef CBLDart_FLDictIterator2_Next = void Function(
  Pointer<CBLDart_FLDictIterator2> iterator,
);

class FleeceDecoderBindings extends Bindings {
  FleeceDecoderBindings(Bindings parent) : super(parent) {
    _dumpData =
        libs.cblDart.lookupFunction<CBLDart_FLData_Dump_C, CBLDart_FLData_Dump>(
      'CBLDart_FLData_Dump',
    );
    _getLoadedFLValueFromData = libs.cblDart
        .lookupFunction<CBLDart_FLValue_FromData_C, CBLDart_FLValue_FromData>(
      'CBLDart_FLValue_FromData',
    );
    _getLoadedFLValue = libs.cblDart
        .lookupFunction<CBLDart_GetLoadedFLValue_C, CBLDart_GetLoadedFLValue>(
      'CBLDart_GetLoadedFLValue',
    );
    _getLoadedFLValueFromArray = libs.cblDart.lookupFunction<
        CBLDart_FLArray_GetLoadedFLValue_C, CBLDart_FLArray_GetLoadedFLValue>(
      'CBLDart_FLArray_GetLoadedFLValue',
    );
    _getLoadedFLValueFromDict = libs.cblDart.lookupFunction<
        CBLDart_FLDict_GetLoadedFLValue_C, CBLDart_FLDict_GetLoadedFLValue>(
      'CBLDart_FLDict_GetLoadedFLValue',
    );
    _dictIteratorBegin = libs.cblDart.lookupFunction<
        CBLDart_FLDictIterator2_Begin_C, CBLDart_FLDictIterator2_Begin>(
      'CBLDart_FLDictIterator2_Begin',
    );
    _dictIteratorNext = libs.cblDart.lookupFunction<
        CBLDart_FLDictIterator2_Next_C, CBLDart_FLDictIterator2_Next>(
      'CBLDart_FLDictIterator2_Next',
    );
  }

  final Pointer<CBLDart_LoadedFLValue> _globalLoadedFLValue = malloc();

  late final CBLDart_FLData_Dump _dumpData;
  late final CBLDart_FLValue_FromData _getLoadedFLValueFromData;
  late final CBLDart_GetLoadedFLValue _getLoadedFLValue;
  late final CBLDart_FLArray_GetLoadedFLValue _getLoadedFLValueFromArray;
  late final CBLDart_FLDict_GetLoadedFLValue _getLoadedFLValueFromDict;
  late final CBLDart_FLDictIterator2_Begin _dictIteratorBegin;
  late final CBLDart_FLDictIterator2_Next _dictIteratorNext;

  String dumpData(FLSlice data) {
    return _dumpData(data).toDartStringAndRelease()!;
  }

  bool getLoadedFLValueFromData(FLSlice data, FLTrust trust) {
    return _getLoadedFLValueFromData(
      data,
      trust.toInt(),
      _globalLoadedFLValue,
    ).toBool();
  }

  void getLoadedValue(Pointer<FLValue> value) {
    _getLoadedFLValue(value, _globalLoadedFLValue);
  }

  void getLoadedValueFromArray(
    Pointer<FLArray> array,
    int index,
  ) {
    _getLoadedFLValueFromArray(array, index, _globalLoadedFLValue);
  }

  void getLoadedValueFromDict(
    Pointer<FLDict> array,
    String key,
  ) {
    stringTable.autoFree(() {
      _getLoadedFLValueFromDict(
        array,
        stringTable.flString(key).ref,
        _globalLoadedFLValue,
      );
    });
  }

  Pointer<CBLDart_FLDictIterator2> dictIteratorBegin(
    Object object,
    Pointer<FLDict> dict,
    Pointer<FLString> keyOut,
    Pointer<CBLDart_LoadedFLValue> valueOut,
  ) {
    return _dictIteratorBegin(object, dict, keyOut, valueOut);
  }

  void dictIteratorNext(Pointer<CBLDart_FLDictIterator2> iterator) {
    _dictIteratorNext(iterator);
  }

  @override
  void dispose() {
    malloc.free(_globalLoadedFLValue);
    super.dispose();
  }
}

// === Encoder =================================================================

/// Output formats a Fleece encoder can generate.
enum FLEncoderFormat {
  /// Fleece encoding
  fleece,

  /// JSON encoding
  json,

  /// [JSON5](http://json5.org); an extension of JSON with a more readable
  /// syntax.
  json5,
}

extension on FLEncoderFormat {
  int toInt() => index;
}

class FLEncoder extends Opaque {}

typedef CBLDart_FLEncoder_New_C = Pointer<FLEncoder> Function(
  Handle object,
  Uint8 format,
  Uint64 reserveSize,
  Uint8 uniqueStrings,
);
typedef CBLDart_FLEncoder_New = Pointer<FLEncoder> Function(
  Object object,
  int format,
  int reserveSize,
  int uniqueStrings,
);

typedef FLEncoder_Reset_C = Void Function(Pointer<FLEncoder> encoder);
typedef FLEncoder_Reset = void Function(Pointer<FLEncoder> encoder);

typedef CBLDart_FLEncoder_WriteArrayValue_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLArray> array,
  Uint32 index,
);
typedef CBLDart_FLEncoder_WriteArrayValue = int Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLArray> array,
  int index,
);

typedef FLEncoder_WriteValue_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLValue> value,
);
typedef FLEncoder_WriteValue = int Function(
  Pointer<FLEncoder> encoder,
  Pointer<FLValue> value,
);

typedef FLEncoder_WriteNull_C = Uint8 Function(Pointer<FLEncoder> encoder);
typedef FLEncoder_WriteNull = int Function(Pointer<FLEncoder> encoder);

typedef FLEncoder_WriteBool_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Uint8 value,
);
typedef FLEncoder_WriteBool = int Function(
  Pointer<FLEncoder> encoder,
  int value,
);

typedef FLEncoder_WriteInt_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Int64 value,
);
typedef FLEncoder_WriteInt = int Function(
  Pointer<FLEncoder> encoder,
  int value,
);

typedef FLEncoder_WriteDouble_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Double value,
);
typedef FLEncoder_WriteDouble = int Function(
  Pointer<FLEncoder> encoder,
  double value,
);

typedef CBLDart_FLEncoder_WriteString_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);
typedef CBLDart_FLEncoder_WriteString = int Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);

typedef CBLDart_FLEncoder_WriteData_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  FLSlice value,
);
typedef CBLDart_FLEncoder_WriteData = int Function(
  Pointer<FLEncoder> encoder,
  FLSlice value,
);

typedef CBLDart_FLEncoder_WriteJSON_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);
typedef CBLDart_FLEncoder_WriteJSON = int Function(
  Pointer<FLEncoder> encoder,
  FLString value,
);

typedef CBLDart_FLEncoder_BeginArray_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Uint64 reserveCount,
);
typedef CBLDart_FLEncoder_BeginArray = int Function(
  Pointer<FLEncoder> encoder,
  int reserveCount,
);

typedef FLEncoder_EndArray_C = Uint8 Function(Pointer<FLEncoder> encoder);
typedef FLEncoder_EndArray = int Function(Pointer<FLEncoder> encoder);

typedef CBLDart_FLEncoder_BeginDict_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  Uint64 reserveCount,
);
typedef CBLDart_FLEncoder_BeginDict = int Function(
  Pointer<FLEncoder> encoder,
  int reserveCount,
);

typedef CBLDart_FLEncoder_WriteKey_C = Uint8 Function(
  Pointer<FLEncoder> encoder,
  FLString key,
);
typedef CBLDart_FLEncoder_WriteKey = int Function(
  Pointer<FLEncoder> encoder,
  FLString key,
);

typedef FLEncoder_EndDict_C = Uint8 Function(Pointer<FLEncoder> encoder);
typedef FLEncoder_EndDict = int Function(Pointer<FLEncoder> encoder);

typedef FLEncoder_Finish_C = FLSliceResult Function(
  Pointer<FLEncoder> encoder,
  Pointer<Uint32> errorOut,
);
typedef FLEncoder_Finish = FLSliceResult Function(
  Pointer<FLEncoder> encoder,
  Pointer<Uint32> errorOut,
);

typedef FLEncoder_GetError_C = Uint32 Function(Pointer<FLEncoder> encoder);
typedef FLEncoder_GetError = int Function(Pointer<FLEncoder> encoder);

typedef FLEncoder_GetErrorMessage_C = Pointer<Utf8> Function(
  Pointer<FLEncoder> encoder,
);
typedef FLEncoder_GetErrorMessage = Pointer<Utf8> Function(
  Pointer<FLEncoder> encoder,
);

class FleeceEncoderBindings extends Bindings {
  FleeceEncoderBindings(Bindings parent) : super(parent) {
    _new = libs.cblDart
        .lookupFunction<CBLDart_FLEncoder_New_C, CBLDart_FLEncoder_New>(
      'CBLDart_FLEncoder_New',
    );
    _reset = libs.cbl.lookupFunction<FLEncoder_Reset_C, FLEncoder_Reset>(
      'FLEncoder_Reset',
    );
    _writeArrayValue = libs.cblDart.lookupFunction<
        CBLDart_FLEncoder_WriteArrayValue_C, CBLDart_FLEncoder_WriteArrayValue>(
      'CBLDart_FLEncoder_WriteArrayValue',
    );
    _writeValue =
        libs.cbl.lookupFunction<FLEncoder_WriteValue_C, FLEncoder_WriteValue>(
      'FLEncoder_WriteValue',
    );
    _writeNull =
        libs.cbl.lookupFunction<FLEncoder_WriteNull_C, FLEncoder_WriteNull>(
      'FLEncoder_WriteNull',
    );
    _writeBool =
        libs.cbl.lookupFunction<FLEncoder_WriteBool_C, FLEncoder_WriteBool>(
      'FLEncoder_WriteBool',
    );
    _writeInt =
        libs.cbl.lookupFunction<FLEncoder_WriteInt_C, FLEncoder_WriteInt>(
      'FLEncoder_WriteInt',
    );
    _writeDouble =
        libs.cbl.lookupFunction<FLEncoder_WriteDouble_C, FLEncoder_WriteDouble>(
      'FLEncoder_WriteDouble',
    );
    _writeString = libs.cblDart.lookupFunction<CBLDart_FLEncoder_WriteString_C,
        CBLDart_FLEncoder_WriteString>(
      'CBLDart_FLEncoder_WriteString',
    );
    _writeData = libs.cblDart.lookupFunction<CBLDart_FLEncoder_WriteData_C,
        CBLDart_FLEncoder_WriteData>(
      'CBLDart_FLEncoder_WriteData',
    );
    _writeJSON = libs.cblDart.lookupFunction<CBLDart_FLEncoder_WriteJSON_C,
        CBLDart_FLEncoder_WriteJSON>(
      'CBLDart_FLEncoder_WriteJSON',
    );
    _beginArray = libs.cblDart.lookupFunction<CBLDart_FLEncoder_BeginArray_C,
        CBLDart_FLEncoder_BeginArray>(
      'CBLDart_FLEncoder_BeginArray',
    );
    _endArray =
        libs.cbl.lookupFunction<FLEncoder_EndArray_C, FLEncoder_EndArray>(
      'FLEncoder_EndArray',
    );
    _beginDict = libs.cblDart.lookupFunction<CBLDart_FLEncoder_BeginDict_C,
        CBLDart_FLEncoder_BeginDict>(
      'CBLDart_FLEncoder_BeginDict',
    );
    _writeKey = libs.cblDart.lookupFunction<CBLDart_FLEncoder_WriteKey_C,
        CBLDart_FLEncoder_WriteKey>(
      'CBLDart_FLEncoder_WriteKey',
    );
    _endDict = libs.cbl.lookupFunction<FLEncoder_EndDict_C, FLEncoder_EndDict>(
      'FLEncoder_EndDict',
    );
    _finish = libs.cbl.lookupFunction<FLEncoder_Finish_C, FLEncoder_Finish>(
      'FLEncoder_Finish',
    );
    __getError =
        libs.cbl.lookupFunction<FLEncoder_GetError_C, FLEncoder_GetError>(
      'FLEncoder_GetError',
    );
    __getErrorMessage = libs.cblDart
        .lookupFunction<FLEncoder_GetErrorMessage_C, FLEncoder_GetErrorMessage>(
      'FLEncoder_GetErrorMessage',
    );
  }

  late final CBLDart_FLEncoder_New _new;
  late final FLEncoder_Reset _reset;
  late final CBLDart_FLEncoder_WriteArrayValue _writeArrayValue;
  late final FLEncoder_WriteValue _writeValue;
  late final FLEncoder_WriteNull _writeNull;
  late final FLEncoder_WriteBool _writeBool;
  late final FLEncoder_WriteInt _writeInt;
  late final FLEncoder_WriteDouble _writeDouble;
  late final CBLDart_FLEncoder_WriteString _writeString;
  late final CBLDart_FLEncoder_WriteData _writeData;
  late final CBLDart_FLEncoder_WriteJSON _writeJSON;
  late final CBLDart_FLEncoder_BeginArray _beginArray;
  late final FLEncoder_EndArray _endArray;
  late final CBLDart_FLEncoder_BeginDict _beginDict;
  late final CBLDart_FLEncoder_WriteKey _writeKey;
  late final FLEncoder_EndDict _endDict;
  late final FLEncoder_Finish _finish;
  late final FLEncoder_GetError __getError;
  late final FLEncoder_GetErrorMessage __getErrorMessage;

  Pointer<FLEncoder> create(
    Object object,
    FLEncoderFormat format,
    int reserveSize,
    bool uniqueStrings,
  ) {
    return _new(object, format.toInt(), reserveSize, uniqueStrings.toInt());
  }

  void reset(Pointer<FLEncoder> encoder) {
    _reset(encoder);
  }

  void writeArrayValue(
    Pointer<FLEncoder> encoder,
    Pointer<FLArray> array,
    int index,
  ) {
    _checkError(encoder, _writeArrayValue(encoder, array, index));
  }

  void writeValue(Pointer<FLEncoder> encoder, Pointer<FLValue> value) {
    if (value == nullptr) {
      throw ArgumentError.value(value, 'value', 'must not be `nullptr`');
    }

    _checkError(encoder, _writeValue(encoder, value));
  }

  void writeNull(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _writeNull(encoder));
  }

  void writeBool(Pointer<FLEncoder> encoder, bool value) {
    _checkError(encoder, _writeBool(encoder, value.toInt()));
  }

  void writeInt(Pointer<FLEncoder> encoder, int value) {
    _checkError(encoder, _writeInt(encoder, value));
  }

  void writeDouble(Pointer<FLEncoder> encoder, double value) {
    _checkError(encoder, _writeDouble(encoder, value));
  }

  void writeString(Pointer<FLEncoder> encoder, String value) {
    stringTable.autoFree(() {
      _checkError(
        encoder,
        _writeString(encoder, stringTable.flString(value).ref),
      );
    });
  }

  void writeData(Pointer<FLEncoder> encoder, TypedData value) {
    withZoneArena(() {
      _checkError(
        encoder,
        _writeData(encoder, value.copyToGlobalSliceInArena().ref),
      );
    });
  }

  void writeJSON(Pointer<FLEncoder> encoder, String value) {
    stringTable.autoFree(() {
      _checkError(
        encoder,
        _writeJSON(encoder, stringTable.flString(value).ref),
      );
    });
  }

  void beginArray(Pointer<FLEncoder> encoder, int reserveCount) {
    _checkError(encoder, _beginArray(encoder, reserveCount));
  }

  void endArray(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _endArray(encoder));
  }

  void beginDict(Pointer<FLEncoder> encoder, int reserveCount) {
    _checkError(encoder, _beginDict(encoder, reserveCount));
  }

  void writeKey(Pointer<FLEncoder> encoder, String value) {
    stringTable.autoFree(() {
      _checkError(
        encoder,
        _writeKey(encoder, stringTable.flString(value).ref),
      );
    });
  }

  void endDict(Pointer<FLEncoder> encoder) {
    _checkError(encoder, _endDict(encoder));
  }

  FLSliceResult finish(Pointer<FLEncoder> encoder) {
    return _checkError(encoder, _finish(encoder, _globalFleeceErrorCode));
  }

  FLErrorCode _getError(Pointer<FLEncoder> encoder) =>
      __getError(encoder).toFleeceErrorCode();

  String _getErrorMessage(Pointer<FLEncoder> encoder) {
    final pointer = __getErrorMessage(encoder);
    final result = pointer.toDartString();
    malloc.free(pointer);
    return result;
  }

  T _checkError<T>(Pointer<FLEncoder> encoder, T result) {
    final mayHaveError = (result is int && !result.toBool()) ||
        (result is FLSliceResult && result.buf == nullptr);

    if (mayHaveError) {
      final errorCode = _getError(encoder);
      if (errorCode == FLErrorCode.noError) {
        return result;
      }

      throw CBLErrorException(
        CBLErrorDomain.fleece,
        errorCode,
        _getErrorMessage(encoder),
      );
    }

    return result;
  }
}

// === FleeceBindings ==========================================================

class FleeceBindings extends Bindings {
  FleeceBindings(Bindings parent) : super(parent) {
    slice = SliceBindings(this);
    slot = SlotBindings(this);
    doc = DocBindings(this);
    value = ValueBindings(this);
    array = ArrayBindings(this);
    mutableArray = MutableArrayBindings(this);
    dict = DictBindings(this);
    dictIterator = DictIteratorBindings(this);
    mutableDict = MutableDictBindings(this);
    decoder = FleeceDecoderBindings(this);
    encoder = FleeceEncoderBindings(this);
  }

  late final Pointer<Uint32> _globalFleeceErrorCode = malloc();
  late final SliceBindings slice;
  late final SlotBindings slot;
  late final DocBindings doc;
  late final ValueBindings value;
  late final ArrayBindings array;
  late final MutableArrayBindings mutableArray;
  late final DictBindings dict;
  late final DictIteratorBindings dictIterator;
  late final MutableDictBindings mutableDict;
  late final FleeceDecoderBindings decoder;
  late final FleeceEncoderBindings encoder;

  @override
  void dispose() {
    malloc.free(_globalFleeceErrorCode);
    super.dispose();
  }
}
