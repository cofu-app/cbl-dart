
#pragma once

#ifdef __APPLE__
#include <CouchbaseLite/CouchbaseLite.h>
#else
#include "cbl/CouchbaseLite.h"
#endif

#include "Callbacks.h"
#include "Fleece+Dart.h"
#include "cbldart_export.h"
#include "dart/dart_api_dl.h"

/**
 * This is a compatibility layer to allow Dart code to use the Couchbase Lite C
 * API. Some method signatures are incompatible with Dart's FFI capabilities.
 *
 * This layer is also where memory management of objects from the Couchbase Lite
 * C API is integrated with the garbage collection of Dart objects.
 */

extern "C" {
// Dart --------------------------------------------------------------------

CBLDART_EXPORT
void CBLDart_InitDartApiDL(void *data);

// -- Callbacks

CBLDART_EXPORT
Callback *CBLDart_Callback_New(Dart_Handle object, Dart_Port sendPort);

CBLDART_EXPORT
void CBLDart_Callback_Close(Callback *callback);

CBLDART_EXPORT
void CBLDart_Callback_CallForTest(Callback *callback, int64_t argument);

// Couchbase Lite ----------------------------------------------------------

// -- Base

CBLDART_EXPORT
CBLDart_FLStringResult CBLDart_CBLError_Message(CBLError *error);

/**
 * Binds a CBLRefCounted to a Dart objects lifetime.
 *
 * If \p retain is true the ref counted object will be retained. Otherwise
 * it will only be released once the Dart object is garbage collected.
 */
CBLDART_EXPORT
void CBLDart_BindCBLRefCountedToDartObject(Dart_Handle object,
                                           CBLRefCounted *refCounted,
                                           uint8_t retain, char *debugName);

/**
 * Sets whether information to debug CBLRefCounted is printed.
 *
 * This features is only functional in debug builds.
 */
CBLDART_EXPORT
void CBLDart_SetDebugRefCounted(uint8_t enabled);

// -- Log

CBLDART_EXPORT
void CBLDart_CBLLog_RestoreOriginalCallback();

CBLDART_EXPORT
void CBLDart_CBLLog_SetCallback(Callback *callback);

// -- Document

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLDocument_ID(CBLDocument *doc);

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLDocument_RevisionID(CBLDocument *doc);

CBLDART_EXPORT
CBLDart_FLStringResult CBLDart_CBLDocument_CreateJSON(CBLDocument *doc);

CBLDART_EXPORT
CBLDocument *CBLDart_CBLDocument_CreateWithID(CBLDart_FLString docID);

CBLDART_EXPORT
int8_t CBLDart_CBLDocument_SetJSON(CBLDocument *doc, CBLDart_FLString json,
                                   CBLError *errorOut);

// -- Database

struct CBLDart_CBLDatabaseConfiguration {
  CBLDart_FLString directory;
};

CBLDART_EXPORT
CBLDart_CBLDatabaseConfiguration CBLDart_CBLDatabaseConfiguration_Default();

CBLDART_EXPORT
uint8_t CBLDart_CBL_DatabaseExists(CBLDart_FLString name,
                                   CBLDart_FLString inDirectory);

CBLDART_EXPORT
uint8_t CBLDart_CBL_CopyDatabase(CBLDart_FLString fromPath,
                                 CBLDart_FLString toName,
                                 CBLDart_CBLDatabaseConfiguration *config,
                                 CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBL_DeleteDatabase(CBLDart_FLString name,
                                   CBLDart_FLString inDirectory,
                                   CBLError *errorOut);

CBLDART_EXPORT
CBLDatabase *CBLDart_CBLDatabase_Open(CBLDart_FLString name,
                                      CBLDart_CBLDatabaseConfiguration *config,
                                      CBLError *errorOut);

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLDatabase_Name(CBLDatabase *db);

CBLDART_EXPORT
CBLDart_FLStringResult CBLDart_CBLDatabase_Path(CBLDatabase *db);

CBLDART_EXPORT
CBLDart_CBLDatabaseConfiguration CBLDart_CBLDatabase_Config(CBLDatabase *db);

CBLDART_EXPORT
const CBLDocument *CBLDart_CBLDatabase_GetDocument(CBLDatabase *database,
                                                   CBLDart_FLString docID,
                                                   CBLError *errorOut);

CBLDART_EXPORT
CBLDocument *CBLDart_CBLDatabase_GetMutableDocument(CBLDatabase *database,
                                                    CBLDart_FLString docID,
                                                    CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_SaveDocumentWithConcurrencyControl(
    CBLDatabase *db, CBLDocument *doc, CBLConcurrencyControl concurrency,
    CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_SaveDocumentWithConflictHandler(
    CBLDatabase *db, CBLDocument *doc, Callback *conflictHandler,
    CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_PurgeDocumentByID(CBLDatabase *database,
                                              CBLDart_FLString docID,
                                              CBLError *errorOut);

CBLDART_EXPORT
CBLTimestamp CBLDart_CBLDatabase_GetDocumentExpiration(CBLDatabase *db,
                                                       CBLDart_FLSlice docID,
                                                       CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_SetDocumentExpiration(CBLDatabase *db,
                                                  CBLDart_FLSlice docID,
                                                  CBLTimestamp expiration,
                                                  CBLError *errorOut);

CBLDART_EXPORT
void CBLDart_CBLDatabase_AddDocumentChangeListener(const CBLDatabase *db,
                                                   const CBLDart_FLString docID,
                                                   Callback *listener);

CBLDART_EXPORT
void CBLDart_CBLDatabase_AddChangeListener(const CBLDatabase *db,
                                           Callback *listener);

typedef enum : uint8_t {
  kCBLDart_IndexTypeValue,
  kCBLDart_IndexTypeFullText,
} CBLDart_IndexType;

struct CBLDart_CBLIndexSpec {
  CBLDart_IndexType type;
  CBLQueryLanguage expressionLanguage;
  CBLDart_FLString expressions;
  uint8_t ignoreAccents;
  CBLDart_FLString language;
};

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_CreateIndex(CBLDatabase *db, CBLDart_FLString name,
                                        CBLDart_CBLIndexSpec indexSpec,
                                        CBLError *errorOut);

CBLDART_EXPORT
uint8_t CBLDart_CBLDatabase_DeleteIndex(CBLDatabase *db, CBLDart_FLString name,
                                        CBLError *errorOut);

// -- Query

CBLDART_EXPORT
CBLQuery *CBLDart_CBLDatabase_CreateQuery(CBLDatabase *db,
                                          CBLQueryLanguage language,
                                          CBLDart_FLString queryString,
                                          int *errorPosOut, CBLError *errorOut);

CBLDART_EXPORT
CBLDart_FLStringResult CBLDart_CBLQuery_Explain(const CBLQuery *query);

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLQuery_ColumnName(const CBLQuery *query,
                                             unsigned columnIndex);

CBLDART_EXPORT
FLValue CBLDart_CBLResultSet_ValueForKey(CBLResultSet *rs,
                                         CBLDart_FLString key);

CBLDART_EXPORT
CBLListenerToken *CBLDart_CBLQuery_AddChangeListener(CBLQuery *query,
                                                     Callback *listener);

// -- Blob

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLBlob_Digest(CBLBlob *blob);

CBLDART_EXPORT
CBLDart_FLString CBLDart_CBLBlob_ContentType(CBLBlob *blob);

CBLDART_EXPORT
uint64_t CBLDart_CBLBlobReader_Read(CBLBlobReadStream *stream, void *buf,
                                    uint64_t bufSize, CBLError *outError);

CBLDART_EXPORT
CBLBlob *CBLDart_CBLBlob_CreateWithStream(CBLDart_FLString contentType,
                                          CBLBlobWriteStream *writer);

// -- Replicator

CBLDART_EXPORT
CBLEndpoint *CBLDart_CBLEndpoint_CreateWithURL(CBLDart_FLString url);

CBLDART_EXPORT
CBLAuthenticator *CBLDart_CBLAuth_CreatePassword(CBLDart_FLString username,
                                                 CBLDart_FLString password);

CBLDART_EXPORT
CBLAuthenticator *CBLDart_CBLAuth_CreateSession(CBLDart_FLString sessionID,
                                                CBLDart_FLString cookieName);

struct CBLDart_CBLProxySettings {
  CBLProxyType type;
  CBLDart_FLString hostname;
  uint16_t port;
  CBLDart_FLString username;
  CBLDart_FLString password;
};

struct CBLDart_ReplicatorConfiguration {
  CBLDatabase *database;
  CBLEndpoint *endpoint;
  CBLReplicatorType replicatorType;
  uint8_t continuous;
  uint8_t disableAutoPurge;
  uint32_t maxAttempts;
  uint32_t maxAttemptWaitTime;
  uint32_t heartbeat;
  CBLAuthenticator *authenticator;
  CBLDart_CBLProxySettings *proxy;
  FLDict headers;
  FLSlice *pinnedServerCertificate;
  FLSlice *trustedRootCertificates;
  FLArray channels;
  FLArray documentIDs;
  Callback *pushFilter;
  Callback *pullFilter;
  Callback *conflictResolver;
};

CBLDART_EXPORT
CBLReplicator *CBLDart_CBLReplicator_Create(
    CBLDart_ReplicatorConfiguration *config, CBLError *errorOut);

CBLDART_EXPORT
void CBLDart_BindReplicatorToDartObject(Dart_Handle object,
                                        CBLReplicator *replicator,
                                        char *debugName);

CBLDART_EXPORT
uint8_t CBLDart_CBLReplicator_IsDocumentPending(CBLReplicator *replicator,
                                                CBLDart_FLString docId,
                                                CBLError *errorOut);
CBLDART_EXPORT
void CBLDart_CBLReplicator_AddChangeListener(CBLReplicator *replicator,
                                             Callback *listenerId);

struct CBLDart_ReplicatedDocument {
  CBLDart_FLString ID;

  uint32_t flags;

  CBLError error;
};

CBLDART_EXPORT
void CBLDart_CBLReplicator_AddDocumentReplicationListener(
    CBLReplicator *replicator, Callback *listenerId);
}
