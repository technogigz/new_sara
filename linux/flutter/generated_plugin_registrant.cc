//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_pay_upi/flutter_pay_upi_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>
#include <webview_all_cef/webview_cef_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_pay_upi_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterPayUpiPlugin");
  flutter_pay_upi_plugin_register_with_registrar(flutter_pay_upi_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) webview_all_cef_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WebviewCefPlugin");
  webview_cef_plugin_register_with_registrar(webview_all_cef_registrar);
}
