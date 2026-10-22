qt_add_library(client_plugin_packages STATIC
    include/PluginPackageRuntime.h include/PluginContext.h
    src/PackageValidation.h src/PackageValidation.cpp
    src/NativePackageLoader.h src/NativePackageLoader.cpp
    src/LeaseServiceEndpoint.h src/LeaseServiceEndpoint.cpp
    src/PluginPackageRuntime.cpp src/PluginContext.cpp)
target_include_directories(client_plugin_packages PUBLIC include)
target_link_libraries(client_plugin_packages PUBLIC client_plugin_sdk Qt6::Core Qt6::Qml)
target_compile_options(client_plugin_packages PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
