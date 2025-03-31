#include "dxgi_capture_plugin_c_api.h"
#include "dxgi_capture_plugin.h"

#include <flutter/plugin_registrar_windows.h>

void DxgiCapturePluginRegisterWithRegistrar(
		FlutterDesktopPluginRegistrarRef registrar)
{
	DxgiCapturePlugin::RegisterWithRegistrar(
			flutter::PluginRegistrarManager::GetInstance()
					->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
