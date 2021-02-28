#include "include/cbl_flutter/cbl_flutter_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define CBL_FLUTTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), cbl_flutter_plugin_get_type(), \
                              CblFlutterPlugin))

struct _CblFlutterPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(CblFlutterPlugin, cbl_flutter_plugin, g_object_get_type())


static void cbl_flutter_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(cbl_flutter_plugin_parent_class)->dispose(object);
}

static void cbl_flutter_plugin_class_init(CblFlutterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = cbl_flutter_plugin_dispose;
}

static void cbl_flutter_plugin_init(CblFlutterPlugin* self) {}

void cbl_flutter_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  // NOOP
}
