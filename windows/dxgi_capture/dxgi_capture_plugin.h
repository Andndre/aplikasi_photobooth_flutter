#ifndef DXGI_CAPTURE_PLUGIN_H_
#define DXGI_CAPTURE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>
#include <string>

class DxgiCapturePlugin : public flutter::Plugin
{
public:
	static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

	DxgiCapturePlugin(flutter::PluginRegistrarWindows *registrar);

	virtual ~DxgiCapturePlugin();

private:
	// Called when a method is called on this plugin's channel from Dart.
	void HandleMethodCall(
			const flutter::MethodCall<flutter::EncodableValue> &method_call,
			std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

	// Registrar for this plugin, for accessing the window
	flutter::PluginRegistrarWindows *registrar_;
};

#endif // DXGI_CAPTURE_PLUGIN_H_
