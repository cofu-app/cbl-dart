#include "dart/dart_api_dl.h"
#include "fleece/Fleece.h"

/**
 * Returns the value of the given Dart CObject, wich is expected to be either an
 * int32 or int64, as an int64_t.
 */
int64_t CBLDart_CObject_getIntValueAsInt64(Dart_CObject* object);

void CBLDart_CObject_SetEmptyArray(Dart_CObject* object);

void CBLDart_CObject_SetPointer(Dart_CObject* object, const void* pointer);

void CBLDart_CObject_SetFLString(Dart_CObject* object, FLString* string);