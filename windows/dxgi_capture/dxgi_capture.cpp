#include "dxgi_capture.h"
#include <iostream>

DXGICapture::DXGICapture()
{
}

DXGICapture::~DXGICapture()
{
	ReleaseDXGI();
}

bool DXGICapture::Initialize()
{
	// Create D3D11 device
	D3D_FEATURE_LEVEL featureLevels[] = {D3D_FEATURE_LEVEL_11_0};
	UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;

#ifdef _DEBUG
	flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, flags,
																 featureLevels, ARRAYSIZE(featureLevels), D3D11_SDK_VERSION,
																 &m_device, nullptr, &m_context);

	if (FAILED(hr))
	{
		std::cerr << "Failed to create D3D11 device: 0x" << std::hex << hr << std::endl;
		return false;
	}

	return SetupDXGI();
}

bool DXGICapture::IsSupported()
{
	// Check if DXGI 1.2 is supported (minimum requirement for desktop duplication)
	ID3D11Device *device = nullptr;
	HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
																 nullptr, 0, D3D11_SDK_VERSION,
																 &device, nullptr, nullptr);

	if (FAILED(hr))
	{
		return false;
	}

	IDXGIDevice *dxgiDevice = nullptr;
	hr = device->QueryInterface(__uuidof(IDXGIDevice), (void **)&dxgiDevice);

	if (FAILED(hr))
	{
		device->Release();
		return false;
	}

	IDXGIAdapter *adapter = nullptr;
	hr = dxgiDevice->GetAdapter(&adapter);

	dxgiDevice->Release();
	device->Release();

	if (FAILED(hr))
	{
		return false;
	}

	IDXGIOutput *output = nullptr;
	hr = adapter->EnumOutputs(0, &output);

	adapter->Release();

	if (FAILED(hr))
	{
		return false;
	}

	IDXGIOutput1 *output1 = nullptr;
	hr = output->QueryInterface(__uuidof(IDXGIOutput1), (void **)&output1);

	output->Release();

	if (FAILED(hr))
	{
		return false;
	}

	IDXGIOutputDuplication *duplication = nullptr;
	hr = output1->DuplicateOutput(device, &duplication);

	if (duplication)
	{
		duplication->Release();
	}

	output1->Release();

	return SUCCEEDED(hr);
}

bool DXGICapture::SetupDXGI()
{
	// Get DXGI device
	IDXGIDevice *dxgiDevice = nullptr;
	HRESULT hr = m_device->QueryInterface(__uuidof(IDXGIDevice), (void **)&dxgiDevice);

	if (FAILED(hr))
	{
		std::cerr << "Failed to get DXGI device: 0x" << std::hex << hr << std::endl;
		return false;
	}

	// Get DXGI adapter
	IDXGIAdapter *adapter = nullptr;
	hr = dxgiDevice->GetAdapter(&adapter);
	dxgiDevice->Release();

	if (FAILED(hr))
	{
		std::cerr << "Failed to get DXGI adapter: 0x" << std::hex << hr << std::endl;
		return false;
	}

	// Get primary output (monitor)
	IDXGIOutput *output = nullptr;
	hr = adapter->EnumOutputs(0, &output);
	adapter->Release();

	if (FAILED(hr))
	{
		std::cerr << "Failed to get DXGI output: 0x" << std::hex << hr << std::endl;
		return false;
	}

	// QI for Output1
	IDXGIOutput1 *output1 = nullptr;
	hr = output->QueryInterface(__uuidof(IDXGIOutput1), (void **)&output1);
	output->Release();

	if (FAILED(hr))
	{
		std::cerr << "Failed to get DXGI output1: 0x" << std::hex << hr << std::endl;
		return false;
	}

	// Create desktop duplication
	hr = output1->DuplicateOutput(m_device, &m_dxgiOutputDuplication);
	output1->Release();

	if (FAILED(hr))
	{
		std::cerr << "Failed to create desktop duplication: 0x" << std::hex << hr << std::endl;
		return false;
	}

	return true;
}

void DXGICapture::ReleaseDXGI()
{
	if (m_stagingTexture)
	{
		m_stagingTexture->Release();
		m_stagingTexture = nullptr;
	}

	if (m_acquiredDesktopImage)
	{
		m_acquiredDesktopImage->Release();
		m_acquiredDesktopImage = nullptr;
	}

	if (m_dxgiOutputDuplication)
	{
		m_dxgiOutputDuplication->Release();
		m_dxgiOutputDuplication = nullptr;
	}

	if (m_context)
	{
		m_context->Release();
		m_context = nullptr;
	}

	if (m_device)
	{
		m_device->Release();
		m_device = nullptr;
	}
}

bool DXGICapture::CaptureWindow(HWND hwnd, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight)
{
	return CaptureWindowRegion(hwnd, outBuffer, outWidth, outHeight);
}

bool DXGICapture::CaptureWindowRegion(HWND hwnd, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight)
{
	if (!m_dxgiOutputDuplication || !m_device || !m_context)
	{
		return false;
	}

	// Get window dimensions
	RECT windowRect;
	if (!GetWindowRect(hwnd, &windowRect))
	{
		return false;
	}

	int width = windowRect.right - windowRect.left;
	int height = windowRect.bottom - windowRect.top;

	if (width <= 0 || height <= 0)
	{
		return false;
	}

	outWidth = width;
	outHeight = height;

	// Acquire next frame
	DXGI_OUTDUPL_FRAME_INFO frameInfo;
	IDXGIResource *desktopResource = nullptr;
	HRESULT hr = m_dxgiOutputDuplication->AcquireNextFrame(100, &frameInfo, &desktopResource);

	if (FAILED(hr))
	{
		// If timeout or error, return false
		return false;
	}

	// QI for ID3D11Texture2D
	if (m_acquiredDesktopImage)
	{
		m_acquiredDesktopImage->Release();
		m_acquiredDesktopImage = nullptr;
	}

	hr = desktopResource->QueryInterface(__uuidof(ID3D11Texture2D), (void **)&m_acquiredDesktopImage);
	desktopResource->Release();

	if (FAILED(hr))
	{
		m_dxgiOutputDuplication->ReleaseFrame();
		return false;
	}

	// Get the desktop image description
	D3D11_TEXTURE2D_DESC desktopDesc;
	m_acquiredDesktopImage->GetDesc(&desktopDesc);

	// Create a staging texture for CPU access
	if (!m_stagingTexture)
	{
		D3D11_TEXTURE2D_DESC stagingDesc = desktopDesc;
		stagingDesc.Width = width;
		stagingDesc.Height = height;
		stagingDesc.BindFlags = 0;
		stagingDesc.MiscFlags = 0;
		stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
		stagingDesc.Usage = D3D11_USAGE_STAGING;

		hr = m_device->CreateTexture2D(&stagingDesc, nullptr, &m_stagingTexture);
		if (FAILED(hr))
		{
			m_acquiredDesktopImage->Release();
			m_acquiredDesktopImage = nullptr;
			m_dxgiOutputDuplication->ReleaseFrame();
			return false;
		}
	}

	// Copy region from desktop to staging texture
	D3D11_BOX sourceBox;
	sourceBox.left = windowRect.left;
	sourceBox.top = windowRect.top;
	sourceBox.right = windowRect.right;
	sourceBox.bottom = windowRect.bottom;
	sourceBox.front = 0;
	sourceBox.back = 1;

	m_context->CopySubresourceRegion(m_stagingTexture, 0, 0, 0, 0, m_acquiredDesktopImage, 0, &sourceBox);

	// Process the frame data
	bool result = ProcessFrame(m_stagingTexture, outBuffer, outWidth, outHeight);

	// Release acquired frame
	m_dxgiOutputDuplication->ReleaseFrame();

	return result;
}

bool DXGICapture::ProcessFrame(ID3D11Texture2D *texture, std::vector<uint8_t> &outBuffer, int &outWidth, int &outHeight)
{
	// Map the staging texture to get the data
	D3D11_MAPPED_SUBRESOURCE mappedResource;
	HRESULT hr = m_context->Map(texture, 0, D3D11_MAP_READ, 0, &mappedResource);

	if (FAILED(hr))
	{
		return false;
	}

	// Get the texture description to determine size
	D3D11_TEXTURE2D_DESC desc;
	texture->GetDesc(&desc);

	// Calculate buffer size and update output parameters
	size_t bufferSize = desc.Width * desc.Height * 4; // BGRA format (4 bytes per pixel)
	outWidth = desc.Width;
	outHeight = desc.Height;

	// Resize output buffer
	outBuffer.resize(bufferSize);

	// Copy the data row by row (accounting for pitch)
	const uint8_t *srcRow = static_cast<const uint8_t *>(mappedResource.pData);
	uint8_t *dstRow = outBuffer.data();

	for (UINT row = 0; row < desc.Height; ++row)
	{
		// Convert from BGRA to RGBA directly
		for (UINT i = 0; i < desc.Width; ++i)
		{
			const uint8_t *bgra = srcRow + (i * 4);
			uint8_t *rgba = dstRow + (i * 4);

			// BGRA to RGBA conversion
			rgba[0] = bgra[2]; // R = B
			rgba[1] = bgra[1]; // G = G
			rgba[2] = bgra[0]; // B = R
			rgba[3] = bgra[3]; // A = A
		}

		// Move to next row
		srcRow += mappedResource.RowPitch;
		dstRow += desc.Width * 4;
	}

	// Unmap the texture
	m_context->Unmap(texture, 0);

	return true;
}
