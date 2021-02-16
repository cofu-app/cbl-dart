#pragma once

#include "cbldart_export.h"
#include "dart/dart_api_dl.h"
#include "fleece/Fleece.h"

extern "C" {
// Slice -------------------------------------------------------------------

/**
 * See `FLSlice` in Dart code.
 */
struct CBLDart_FLSlice {
  const void *buf;
  uint64_t size;
};

FLSliceResult CBLDart_FLSliceResultFromDart(CBLDart_FLSlice slice);

CBLDart_FLSlice CBLDart_FLSliceResultToDart(FLSliceResult slice);

CBLDart_FLSlice CBLDart_FLSliceToDart(FLSlice slice);

CBLDART_EXPORT
void CBLDart_FLSliceResult_Release(CBLDart_FLSlice *slice);

// Doc ---------------------------------------------------------------------

CBLDART_EXPORT
FLDoc CBLDart_FLDoc_FromJSON(char *json, FLError *error);

CBLDART_EXPORT
void CBLDart_FLDoc_BindToDartObject(Dart_Handle handle, FLDoc doc);

// Value -------------------------------------------------------------------

CBLDART_EXPORT
void CBLDart_FLValue_BindToDartObject(Dart_Handle handle, FLValue value,
                                      bool retain);

CBLDART_EXPORT
void CBLDart_FLValue_AsString(FLValue value, CBLDart_FLSlice *slice);

CBLDART_EXPORT
void CBLDart_FLValue_ToString(FLValue value, CBLDart_FLSlice *slice);

CBLDART_EXPORT
void CBLDart_FLValue_ToJSONX(FLValue value, bool json5, bool canonicalForm,
                             CBLDart_FLSlice *result);

// Dict --------------------------------------------------------------------

CBLDART_EXPORT
FLValue CBLDart_FLDict_Get(FLDict dict, char *keyString);

typedef struct {
  FLDictIterator *iterator;
  CBLDart_FLSlice *keyString;
} CBLDart_DictIterator;

CBLDART_EXPORT
CBLDart_DictIterator *CBLDart_FLDictIterator_Begin(Dart_Handle handle,
                                                   FLDict dict);

CBLDART_EXPORT
void CBLDart_FLDictIterator_GetKeyString(FLDictIterator *iterator,
                                         CBLDart_FLSlice *keyString);

CBLDART_EXPORT
void CBLDart_FLMutableDict_Remove(FLMutableDict dict, char *key);

CBLDART_EXPORT
FLSlot CBLDart_FLMutableDict_Set(FLMutableDict dict, char *key);

CBLDART_EXPORT
void CBLDart_FLSlot_SetString(FLSlot slot, char *value);

CBLDART_EXPORT
FLMutableArray CBLDart_FLMutableDict_GetMutableArray(FLMutableDict dict,
                                                     char *key);

CBLDART_EXPORT
FLMutableDict CBLDart_FLMutableDict_GetMutableDict(FLMutableDict dict,
                                                   char *key);
}
