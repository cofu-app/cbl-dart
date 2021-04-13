#pragma once

#include <atomic>
#include <functional>
#include <map>
#include <mutex>
#include <shared_mutex>
#include <vector>

#include "dart/dart_api_dl.h"

// === Callback ===============================================================

typedef void (*CallbackFinalizer)(void *context);

class Callback {
 public:
  Callback(Dart_Handle dartCallback, Dart_Port sendport);

  Dart_Port sendPort() const { return sendPort_; }

  void setFinalizer(void *context, CallbackFinalizer finalizer);

  void close();

 private:
  void static dartCallbackHandleFinalizer(void *dart_callback_data, void *peer);

  ~Callback();

  Dart_Port sendPort_ = ILLEGAL_PORT;
  void *finalizerContext_ = nullptr;
  CallbackFinalizer finalizer_ = nullptr;
  Dart_WeakPersistentHandle dartCallbackHandle_ = nullptr;

  void runFinalizer();
};

// === CallbackCall ===========================================================

typedef void(CallbackResultHandler)(Dart_CObject *);

class CallbackCall {
 public:
  CallbackCall(const Callback &callback);

  CallbackCall(const Callback &callback,
               const std::function<CallbackResultHandler> &resultHandler);

  ~CallbackCall();

  void execute(Dart_CObject &arguments);

  static void messageHandler(Dart_Port dest_port_id, Dart_CObject *message);

 private:
  const Callback &callback_;
  const std::function<CallbackResultHandler> *resultHandler_ = nullptr;
  Dart_Port receivePort_ = ILLEGAL_PORT;
  std::condition_variable cv_;
  bool completed_ = false;
};
