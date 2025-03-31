#ifndef DXGI_CAPTURE_H_
#define DXGI_CAPTURE_H_

#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <vector>
#include <memory>

class DXGICapture
{
public:
	DXGICapture();
	~DXGICapture();

	// Initialize the DXGI capture engine
	bool Initialize();

	// Capture a specific window using DXGI
	bool CaptureWindow(HWND hwnd, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight);

	// Check if this system supports DXGI capture
	static bool IsSupported();

private:
	// DirectX resources
	ID3D11Device *m_device = nullptr;
	ID3D11DeviceContext *m_context = nullptr;
	IDXGIOutputDuplication *m_dxgiOutputDuplication = nullptr;

	// Cached resources
	ID3D11Texture2D *m_acquiredDesktopImage = nullptr;
	ID3D11Texture2D *m_stagingTexture = nullptr;

	// Helper functions
	bool SetupDXGI();
	void ReleaseDXGI();
	bool ProcessFrame(ID3D11Texture2D *texture, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight);
	bool CaptureWindowRegion(HWND hwnd, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight);
};

#endif // DXGI_CAPTURE_H_
