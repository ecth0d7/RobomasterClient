# moc 不展开 signals/property 区域的 include。
# 因此从同一份遥测定义表生成显式属性和信号声明。
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/include/TelemetryGroups.def")
file(STRINGS include/TelemetryGroups.def _telemetry_groups REGEX "^RM_TELEMETRY_GROUP")
set(TELEMETRY_PROPERTIES "")
set(TELEMETRY_SIGNALS "")
foreach(_entry IN LISTS _telemetry_groups)
    if(NOT _entry MATCHES "^RM_TELEMETRY_GROUP\\(([A-Za-z][A-Za-z0-9]*), ([A-Za-z][A-Za-z0-9]*)\\)$")
        message(FATAL_ERROR "Invalid telemetry schema: ${_entry}")
    endif()
    set(_name "${CMAKE_MATCH_1}")
    string(APPEND TELEMETRY_PROPERTIES "    Q_PROPERTY(QVariantMap ${_name} READ ${_name} NOTIFY ${_name}Changed)\n")
    string(APPEND TELEMETRY_SIGNALS "    void ${_name}Changed();\n")
endforeach()
configure_file(include/TelemetryEndpoint.h.in generated/TelemetryEndpoint.h @ONLY)
qt_add_library(client_plugin_sdk SHARED include/ClientPlugin.h include/PluginHost.h src/PluginHost.cpp
    "${CMAKE_CURRENT_BINARY_DIR}/generated/TelemetryEndpoint.h" include/TelemetryGroups.def
    include/InputEndpoint.h include/ExtensionPlugin.h include/ServiceEndpoint.h
    include/AdviceContract.h src/AdviceContract.cpp
    include/PacketObservation.h src/PacketObservation.cpp include/ExtensionPackage.h
    include/ProcessLifetimeGate.h src/ProcessLifetimeGate.cpp
    include/TerminalObservationSource.h include/ExtensionServiceProvider.h include/EncodedVideoEndpoint.h)
target_include_directories(client_plugin_sdk PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/generated>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include/robomaster>)
target_link_libraries(client_plugin_sdk PUBLIC Qt6::Core Qt6::Gui)
# Package factories need only this header ABI and QtCore. They must not link a
# duplicate SDK implementation merely to use ExtensionPackageHost/Session.
add_library(client_package_api INTERFACE)
add_library(RoboMaster::package_api ALIAS client_package_api)
set_target_properties(client_package_api PROPERTIES EXPORT_NAME package_api)
target_include_directories(client_package_api INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include/robomaster>)
target_compile_features(client_package_api INTERFACE cxx_std_17)
target_link_libraries(client_package_api INTERFACE Qt6::Core)
set_target_properties(client_plugin_sdk PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    WINDOWS_EXPORT_ALL_SYMBOLS ON)
install(TARGETS client_plugin_sdk client_package_api EXPORT ClientPluginSDKTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK
    RUNTIME DESTINATION bin COMPONENT PluginSDK
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/ClientPlugin.h include/ExtensionPlugin.h "${CMAKE_CURRENT_BINARY_DIR}/generated/TelemetryEndpoint.h"
    include/TelemetryGroups.def include/InputEndpoint.h include/ServiceEndpoint.h include/AdviceContract.h
    include/PacketObservation.h include/ExtensionPackage.h include/TerminalObservationSource.h include/ExtensionServiceProvider.h include/ProcessLifetimeGate.h include/EncodedVideoEndpoint.h
    DESTINATION include/robomaster COMPONENT PluginSDK)
set(_client_sdk_cmake_directory "${CMAKE_INSTALL_LIBDIR}/cmake/ClientPluginSDK")
install(EXPORT ClientPluginSDKTargets NAMESPACE RoboMaster:: DESTINATION "${_client_sdk_cmake_directory}" COMPONENT PluginSDK)
include(CMakePackageConfigHelpers)
configure_package_config_file(ClientPluginSDKConfig.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/ClientPluginSDKConfig.cmake"
    INSTALL_DESTINATION "${_client_sdk_cmake_directory}")
write_basic_package_version_file("${CMAKE_CURRENT_BINARY_DIR}/ClientPluginSDKConfigVersion.cmake"
    VERSION 1.12.0 COMPATIBILITY SameMajorVersion)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/ClientPluginSDKConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/ClientPluginSDKConfigVersion.cmake"
    cmake/RoboMasterExtensionPackage.cmake
    DESTINATION "${_client_sdk_cmake_directory}" COMPONENT PluginSDK)
# The SDK book sits one level above its source-tree counterpart. Point source
# references at the accompanying portable guide bundle; media remains local.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/docs/TECHNICAL.md")
file(READ "${PROJECT_SOURCE_DIR}/docs/TECHNICAL.md" _client_sdk_book)
string(REPLACE "](../" "](../plugin-guides/" _client_sdk_book "${_client_sdk_book}")
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/sdk-TECHNICAL.md" CONTENT "${_client_sdk_book}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/sdk-TECHNICAL.md" RENAME TECHNICAL.md
    DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/sdk" COMPONENT PluginSDK)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/docs/media/"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/sdk/media" COMPONENT PluginSDK
    FILES_MATCHING PATTERN "*.webp" PATTERN "*.gif" PATTERN "*.svg" PATTERN "*.png" PATTERN "*.jpg" PATTERN "*.jpeg" PATTERN "*-LICENSE.txt")
add_subdirectory(packages)
