#pragma once

#include <functional>
#include <map>
#include <mutex>
#include <shared_mutex>
#include <vector>
#include <atomic>

#include "dart/dart_api_dl.h"

typedef int64_t CallbackId;

#define NULL_CALLBACK (CallbackId(0))

/**
 * A callback which is invoked when an Isolate dies but the callback
 * registration still exists.
 *
 * This callback should ensure that the callback will not be invoked any more.
 *
 * The callback receives the context which was provided when it was registered.
 */
typedef void (*CallbackFinalizer)(CallbackId CallbackId, void *context);

class CallbackIsolate {
 public:
  static CallbackIsolate *&getForCallbackId(CallbackId callbackId);

  CallbackIsolate(Dart_Handle handle, Dart_Port sendPort);

  Dart_Port sendPort();

  // This method is called when the Isolate which this instance was created by
  // dies.
  static void finalizer(void *dart_callback_data, void *peer);

  CallbackId registerCallback();

  void unregisterCallback(CallbackId callbackId, bool runFinalizer);

  void setCallbackFinalizer(CallbackId callbackId, void *context,
                            CallbackFinalizer finalizer);

  void removeCallbackFinalizer(CallbackId callbackId);

 private:
  static std::atomic<CallbackId> nextCallbackId;

  static std::map<CallbackId, CallbackIsolate *> isolatesByCallback;
  static std::shared_mutex isolatesByCallback_mutex;

  Dart_Port sendPort_;
  std::vector<CallbackId> callbackIds;

  std::map<CallbackId, std::pair<CallbackFinalizer, void *> *>
      callbackFinalizers;

  CallbackId createCallbackId();

  void removeFinalizer(CallbackId callbackId, bool runFinalizer);
};

typedef void(CallbackResultHandler)(Dart_CObject *);

class CallbackCall {
 public:
  CallbackCall();

  CallbackCall(const std::function<CallbackResultHandler> &resultHandler);

  ~CallbackCall();

  void execute(CallbackId callbackId, Dart_CObject *arguments);

  static void messageHandler(Dart_Port dest_port_id, Dart_CObject *message);

 private:
  const std::function<CallbackResultHandler> *resultHandler = nullptr;
  Dart_Port receivePort = ILLEGAL_PORT;
  std::condition_variable cv;
  bool completed = false;
};
