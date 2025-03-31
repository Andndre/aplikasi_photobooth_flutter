cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "dxgi_capture")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin
set(PLUGIN_NAME "dxgi_capture_plugin")

# Define the plugin library target for the DXGI capture
add_library(${PLUGIN_NAME} SHARED
  "dxgi_capture.cpp"
  "dxgi_capture.h"
  "dxgi_capture_plugin.cpp"
  "dxgi_capture_plugin.h"
  "dxgi_capture_plugin_c_api.cpp"
  "dxgi_capture_plugin_c_api.h"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Link DirectX libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE d3d11.lib dxgi.lib)

# List of absolute paths to libraries that should be bundled with the plugin
set(dxgi_capture_bundled_libraries
  ""
  PARENT_SCOPE
)
