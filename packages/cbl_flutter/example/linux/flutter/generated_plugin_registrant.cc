//
//  Generated file. Do not edit.
//

#include "generated_plugin_registrant.h"

#include <cbl_flutter/cbl_flutter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) cbl_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "CblFlutterPlugin");
  cbl_flutter_plugin_register_with_registrar(cbl_flutter_registrar);
}
