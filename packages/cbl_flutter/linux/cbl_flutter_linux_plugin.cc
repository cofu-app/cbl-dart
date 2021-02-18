#include "include/cbl_flutter_linux/cbl_flutter_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define CBL_FLUTTER_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), cbl_flutter_linux_plugin_get_type(), \
                              CblFlutterLinuxPlugin))

struct _CblFlutterLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(CblFlutterLinuxPlugin, cbl_flutter_linux_plugin,
              g_object_get_type())

static void cbl_flutter_linux_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(cbl_flutter_linux_plugin_parent_class)->dispose(object);
}

static void cbl_flutter_linux_plugin_class_init(
    CblFlutterLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = cbl_flutter_linux_plugin_dispose;
}

static void cbl_flutter_linux_plugin_init(CblFlutterLinuxPlugin* self) {}

void cbl_flutter_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  // NOOP
}
