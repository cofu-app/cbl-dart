#include "Fleece+Dart.h"

// Fleece ----------------------------------------------------------------------

// -- Slice

FLSlice CBLDart_FLSliceFromDart(CBLDart_FLSlice slice) {
  return {slice.buf, static_cast<size_t>(slice.size)};
}

CBLDart_FLSlice CBLDart_FLSliceToDart(FLSlice slice) {
  return {slice.buf, slice.size};
}

FLSliceResult CBLDart_FLSliceResultFromDart(CBLDart_FLSliceResult slice) {
  return {slice.buf, static_cast<size_t>(slice.size)};
}

CBLDart_FLSliceResult CBLDart_FLSliceResultToDart(FLSliceResult slice) {
  return {slice.buf, slice.size};
}

FLString CBLDart_FLStringFromDart(CBLDart_FLString slice) {
  return {slice.buf, static_cast<size_t>(slice.size)};
}

CBLDart_FLString CBLDart_FLStringToDart(FLString slice) {
  return {slice.buf, slice.size};
}

FLStringResult CBLDart_FLStringResultFromDart(CBLDart_FLStringResult slice) {
  return {slice.buf, static_cast<size_t>(slice.size)};
}

CBLDart_FLStringResult CBLDart_FLStringResultToDart(FLStringResult slice) {
  return {slice.buf, slice.size};
}

uint8_t CBLDart_FLSlice_Equal(CBLDart_FLSlice a, CBLDart_FLSlice b) {
  return FLSlice_Equal(CBLDart_FLSliceFromDart(a), CBLDart_FLSliceFromDart(b));
}

int64_t CBLDart_FLSlice_Compare(CBLDart_FLSlice a, CBLDart_FLSlice b) {
  return FLSlice_Compare(CBLDart_FLSliceFromDart(a),
                         CBLDart_FLSliceFromDart(b));
}

CBLDart_FLSliceResult CBLDart_FLSliceResult_New(uint64_t size) {
  return CBLDart_FLSliceResultToDart(FLSliceResult_New(size));
}

CBLDart_FLSliceResult CBLDart_FLSlice_Copy(CBLDart_FLSlice slice) {
  return CBLDart_FLSliceResultToDart(
      FLSlice_Copy(CBLDart_FLSliceFromDart(slice)));
}

void CBLDart_ReleaseDartObjectBoundFLSliceResult(void *dart_callback_data,
                                                 void *peer) {
  auto slice = reinterpret_cast<FLSliceResult *>(peer);
  FLSliceResult_Release(*slice);
  delete slice;
}

void CBLDart_FLSliceResult_BindToDartObject(Dart_Handle object,
                                            CBLDart_FLSliceResult slice,
                                            uint8_t retain) {
  auto _slice = new FLSliceResult;
  *_slice = CBLDart_FLSliceResultFromDart(slice);

  if (retain) {
    FLSliceResult_Retain(*_slice);
  }

  Dart_NewFinalizableHandle_DL(object, _slice, 0,
                               CBLDart_ReleaseDartObjectBoundFLSliceResult);
}

void CBLDart_FLSliceResult_Release(CBLDart_FLSliceResult slice) {
  FLSliceResult_Release(CBLDart_FLSliceResultFromDart(slice));
}

// -- Doc

FLDoc CBLDart_FLDoc_FromResultData(CBLDart_FLSliceResult data, uint8_t trust,
                                   FLSharedKeys sharedKeys,
                                   CBLDart_FLSlice externalData) {
  return FLDoc_FromResultData(CBLDart_FLSliceResultFromDart(data),
                              (FLTrust)trust, sharedKeys,
                              CBLDart_FLSliceFromDart(externalData));
}

FLDoc CBLDart_FLDoc_FromJSON(CBLDart_FLString json, FLError *errorOut) {
  return FLDoc_FromJSON(CBLDart_FLStringFromDart(json), errorOut);
}

void CBLDart_ReleaseDartObjectBoundFLDoc(void *dart_callback_data, void *peer) {
  auto doc = reinterpret_cast<FLDoc>(peer);
  FLDoc_Release(doc);
}

void CBLDart_FLDoc_BindToDartObject(Dart_Handle object, FLDoc doc) {
  Dart_NewFinalizableHandle_DL(object, doc, 0,
                               CBLDart_ReleaseDartObjectBoundFLDoc);
}

// -- Value

void CBLDart_ReleaseDartObjectBoundFLValue(void *dart_callback_data,
                                           void *peer) {
  auto value = reinterpret_cast<FLValue>(peer);
  FLValue_Release(value);
}

void CBLDart_FLValue_BindToDartObject(Dart_Handle object, FLValue value,
                                      uint8_t retain) {
  // There is nothing to be done for `null` und `undefined`.
  if (value == NULL ||  // The null pointer represents `undefined` values.
      value == kFLNullValue)
    return;

  if (retain) FLValue_Retain(value);

  Dart_NewFinalizableHandle_DL(object, (void *)value, 0,
                               CBLDart_ReleaseDartObjectBoundFLValue);
}

CBLDart_FLString CBLDart_FLValue_AsString(FLValue value) {
  return CBLDart_FLStringToDart(FLValue_AsString(value));
}

CBLDart_FLSlice CBLDart_FLValue_AsData(FLValue value) {
  return CBLDart_FLSliceToDart(FLValue_AsData(value));
}

CBLDart_FLStringResult CBLDart_FLValue_ToString(FLValue value) {
  return CBLDart_FLStringResultToDart(FLValue_ToString(value));
}

CBLDart_FLStringResult CBLDart_FLValue_ToJSONX(FLValue value, uint8_t json5,
                                               uint8_t canonicalForm) {
  return CBLDart_FLStringResultToDart(
      FLValue_ToJSONX(value, json5, canonicalForm));
}

// -- Dict

FLValue CBLDart_FLDict_Get(FLDict dict, CBLDart_FLString keyString) {
  return FLDict_Get(dict, CBLDart_FLStringFromDart(keyString));
}

void CBLDart_FinalizeDartObjectBoundDictIterator(void *dart_callback_data,
                                                 void *peer) {
  auto iterator = reinterpret_cast<CBLDart_DictIterator *>(peer);

  if (!iterator->done) FLDictIterator_End(iterator->iterator);

  delete iterator->iterator;
  delete iterator;
}

CBLDart_DictIterator *CBLDart_FLDictIterator_Begin(Dart_Handle object,
                                                   FLDict dict) {
  auto iterator = new CBLDart_DictIterator;
  iterator->iterator = new FLDictIterator;
  iterator->keyString = kCBLDartNullSlice;
  iterator->done = false;

  FLDictIterator_Begin(dict, iterator->iterator);

  Dart_NewFinalizableHandle_DL(object, iterator, sizeof(iterator),
                               CBLDart_FinalizeDartObjectBoundDictIterator);

  return iterator;
}

void CBLDart_FLDictIterator_Next(CBLDart_DictIterator *iterator) {
  auto value = FLDictIterator_GetValue(iterator->iterator);
  if (value != NULL) {
    auto key = FLDictIterator_GetKeyString(iterator->iterator);
    iterator->keyString = CBLDart_FLSliceToDart(key);
    iterator->done = !FLDictIterator_Next(iterator->iterator);
  } else {
    iterator->keyString = kCBLDartNullSlice;
    iterator->done = true;
  }
}

void CBLDart_FLMutableDict_Remove(FLMutableDict dict, CBLDart_FLString key) {
  FLMutableDict_Remove(dict, CBLDart_FLStringFromDart(key));
}

FLSlot CBLDart_FLMutableDict_Set(FLMutableDict dict, CBLDart_FLString key) {
  return FLMutableDict_Set(dict, CBLDart_FLStringFromDart(key));
}

void CBLDart_FLSlot_SetString(FLSlot slot, CBLDart_FLString value) {
  FLSlot_SetString(slot, CBLDart_FLSliceFromDart(value));
}

FLMutableArray CBLDart_FLMutableDict_GetMutableArray(FLMutableDict dict,
                                                     CBLDart_FLString key) {
  return FLMutableDict_GetMutableArray(dict, CBLDart_FLStringFromDart(key));
}

FLMutableDict CBLDart_FLMutableDict_GetMutableDict(FLMutableDict dict,
                                                   CBLDart_FLString key) {
  return FLMutableDict_GetMutableDict(dict, CBLDart_FLStringFromDart(key));
}

// Decoder --------------------------------------------------------------------

CBLDart_FLStringResult CBLDart_FLData_Dump(CBLDart_FLSlice data) {
  return CBLDart_FLStringResultToDart(
      FLData_Dump(CBLDart_FLSliceFromDart(data)));
}

uint8_t CBLDart_FLValue_FromData(CBLDart_FLSlice data, FLTrust trust,
                                 CBLDart_LoadedFLValue *out) {
  auto value = FLValue_FromData(CBLDart_FLSliceFromDart(data), trust);
  if (!value) {
    return false;
  }

  CBLDart_GetLoadedFLValue(value, out);

  return true;
}

void CBLDart_GetLoadedFLValue(FLValue value, CBLDart_LoadedFLValue *out) {
  auto type = FLValue_GetType(value);
  out->type = type;

  switch (type) {
    case kFLUndefined:
    case kFLNull:
      break;
    case kFLBoolean: {
      out->asBool = FLValue_AsBool(value);
      break;
    }
    case kFLNumber: {
      auto isInteger = FLValue_IsInteger(value);
      out->isInteger = isInteger;
      if (isInteger) {
        out->asInt = FLValue_AsInt(value);
      } else {
        out->asDouble = FLValue_AsDouble(value);
      }
      break;
    }
    case kFLString: {
      out->asString = CBLDart_FLStringToDart(FLValue_AsString(value));
      out->asValue = value;
      break;
    }
    case kFLData: {
      out->asData = CBLDart_FLSliceToDart(FLValue_AsData(value));
      out->asValue = value;
      break;
    }
    case kFLArray: {
      out->collectionSize = FLArray_Count((FLArray)value);
      out->asValue = value;
      break;
    }
    case kFLDict: {
      out->collectionSize = FLDict_Count((FLDict)value);
      out->asValue = value;
      break;
    }
  }
}

void CBLDart_FLArray_GetLoadedFLValue(FLArray array, uint32_t index,
                                      CBLDart_LoadedFLValue *out) {
  auto value = FLArray_Get(array, index);
  CBLDart_GetLoadedFLValue(value, out);
}

void CBLDart_FLDict_GetLoadedFLValue(FLDict dict, CBLDart_FLString key,
                                     CBLDart_LoadedFLValue *out) {
  CBLDart_GetLoadedFLValue(FLDict_Get(dict, CBLDart_FLStringFromDart(key)),
                           out);
}

void CBLDart_FinalizeDartObjectBoundDictIterator2(void *dart_callback_data,
                                                  void *peer) {
  auto iterator = reinterpret_cast<CBLDart_FLDictIterator2 *>(peer);

  if (!iterator->isDone) FLDictIterator_End(iterator->_iterator);

  delete iterator->_iterator;
  delete iterator;
}

CBLDart_FLDictIterator2 *CBLDart_FLDictIterator2_Begin(
    Dart_Handle object, FLDict dict, CBLDart_FLString *keyOut,
    CBLDart_LoadedFLValue *valueOut) {
  auto iterator = new CBLDart_FLDictIterator2;
  iterator->_iterator = new FLDictIterator;
  iterator->isDone = false;
  iterator->keyOut = keyOut;
  iterator->valueOut = valueOut;

  FLDictIterator_Begin(dict, iterator->_iterator);

  Dart_NewFinalizableHandle_DL(object, iterator, sizeof(iterator),
                               CBLDart_FinalizeDartObjectBoundDictIterator2);

  return iterator;
}

void CBLDart_FLDictIterator2_Next(CBLDart_FLDictIterator2 *iterator) {
  auto value = FLDictIterator_GetValue(iterator->_iterator);
  iterator->isDone = value == nullptr;
  if (!iterator->isDone) {
    if (iterator->keyOut) {
      auto key = FLDictIterator_GetKeyString(iterator->_iterator);
      *iterator->keyOut = CBLDart_FLSliceToDart(key);
    }

    if (iterator->valueOut) CBLDart_GetLoadedFLValue(value, iterator->valueOut);

    FLDictIterator_Next(iterator->_iterator);
  }
}

// Encoder --------------------------------------------------------------------

void CBLDart_ReleaseDartObjectBoundFLEncoder(void *dart_callback_data,
                                             void *peer) {
  auto encoder = reinterpret_cast<FLEncoder>(peer);
  FLEncoder_Free(encoder);
}

FLEncoder CBLDart_FLEncoder_New(Dart_Handle object, uint8_t format,
                                uint64_t reserveSize, uint8_t uniqueStrings) {
  auto encoder = FLEncoder_NewWithOptions(static_cast<FLEncoderFormat>(format),
                                          reserveSize, uniqueStrings);

  Dart_NewFinalizableHandle_DL(object, encoder, 0,
                               CBLDart_ReleaseDartObjectBoundFLEncoder);

  return encoder;
}

uint8_t CBLDart_FLEncoder_WriteArrayValue(FLEncoder encoder, FLArray array,
                                          uint32_t index) {
  return FLEncoder_WriteValue(encoder, FLArray_Get(array, index));
}

uint8_t CBLDart_FLEncoder_WriteString(FLEncoder encoder,
                                      CBLDart_FLString value) {
  return FLEncoder_WriteString(encoder, CBLDart_FLStringFromDart(value));
}

uint8_t CBLDart_FLEncoder_WriteData(FLEncoder encoder, CBLDart_FLSlice value) {
  return FLEncoder_WriteData(encoder, CBLDart_FLSliceFromDart(value));
}

uint8_t CBLDart_FLEncoder_WriteJSON(FLEncoder encoder, CBLDart_FLString value) {
  return FLEncoder_ConvertJSON(encoder, CBLDart_FLStringFromDart(value));
}

uint8_t CBLDart_FLEncoder_BeginArray(FLEncoder encoder, uint64_t reserveCount) {
  return FLEncoder_BeginArray(encoder, reserveCount);
}

uint8_t CBLDart_FLEncoder_BeginDict(FLEncoder encoder, uint64_t reserveCount) {
  return FLEncoder_BeginDict(encoder, reserveCount);
}

uint8_t CBLDart_FLEncoder_WriteKey(FLEncoder encoder, CBLDart_FLString key) {
  return FLEncoder_WriteKey(encoder, CBLDart_FLStringFromDart(key));
}
