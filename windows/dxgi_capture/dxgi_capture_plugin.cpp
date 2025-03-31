#include "dxgi_capture_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <sstream>
#include "dxgi_capture.h"

// static
void DxgiCapturePlugin::RegisterWithRegistrar(
		flutter::PluginRegistrarWindows *registrar)
{
	auto channel =
			std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
					registrar->messenger(), "dxgi_capture_plugin",
					&flutter::StandardMethodCodec::GetInstance());

	auto plugin = std::make_unique<DxgiCapturePlugin>(registrar);

	channel->SetMethodCallHandler(
			[plugin_pointer = plugin.get()](const auto &call, auto result)
			{
				plugin_pointer->HandleMethodCall(call, std::move(result));
			});

	registrar->AddPlugin(std::move(plugin));
}

DxgiCapturePlugin::DxgiCapturePlugin(flutter::PluginRegistrarWindows *registrar)
		: registrar_(registrar) {}

DxgiCapturePlugin::~DxgiCapturePlugin() {}

void DxgiCapturePlugin::HandleMethodCall(
		const flutter::MethodCall<flutter::EncodableValue> &method_call,
		std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
	if (method_call.method_name().compare("isGpuCaptureSupported") == 0)
	{
		bool isSupported = DXGICapture::IsSupported();
		result->Success(flutter::EncodableValue(isSupported));
	}
	else if (method_call.method_name().compare("captureWindow") == 0)
	{
		// Extract HWND from arguments
		const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
		if (!arguments)
		{
			result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
			return;
		}

		auto hwndArg = arguments->find(flutter::EncodableValue("hwnd"));
		if (hwndArg == arguments->end())
		{
			result->Error("INVALID_ARGUMENTS", "HWND is required");
			return;
		}

		int64_t hwndValue = std::get<int64_t>(hwndArg->second);
		HWND hwnd = reinterpret_cast<HWND>(static_cast<uintptr_t>(hwndValue));

		// Perform the capture using DXGI
		std::unique_ptr<DXGICapture> capture = std::make_unique<DXGICapture>();
		if (!capture->Initialize())
		{
			result->Error("INITIALIZATION_FAILED", "Failed to initialize DXGI capture");
			return;
		}

		std::vector<uint8_t> buffer;
		int width = 0, height = 0;

		if (!capture->CaptureWindow(hwnd, buffer, width, height))
		{
			result->Error("CAPTURE_FAILED", "Failed to capture window with DXGI");
			return;
		}

		// Create return data structure
		flutter::EncodableMap returnMap;
		returnMap[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
		returnMap[flutter::EncodableValue("height")] = flutter::EncodableValue(height);
		returnMap[flutter::EncodableValue("isGpuAccelerated")] = flutter::EncodableValue(true);
		returnMap[flutter::EncodableValue("isDirect")] = flutter::EncodableValue(true);
		returnMap[flutter::EncodableValue("originalWidth")] = flutter::EncodableValue(width);
		returnMap[flutter::EncodableValue("originalHeight")] = flutter::EncodableValue(height);
		returnMap[flutter::EncodableValue("captureMethod")] = flutter::EncodableValue("dxgi_gpu");

		// Convert buffer to EncodableList
		flutter::EncodableList pixelList;
		pixelList.reserve(buffer.size());
		for (const auto &byte : buffer)
		{
			pixelList.push_back(flutter::EncodableValue(static_cast<int>(byte)));
		}

		returnMap[flutter::EncodableValue("bytes")] = flutter::EncodableValue(pixelList);

		result->Success(flutter::EncodableValue(returnMap));
	}
	else
	{
		result->NotImplemented();
	}
}
