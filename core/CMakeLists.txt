# Decoded telemetry, identity and freshness. No sockets or QML.
qt_add_library(client_core STATIC
    include/TelemetryStore.h src/TelemetryStore.cpp include/RobotIdentity.h)
target_include_directories(client_core PUBLIC include)
target_link_libraries(client_core PUBLIC client_plugin_sdk Qt6::Core)
qt_add_plugin(state_telemetry_plugin SHARED CLASS_NAME TelemetryPlugin src/TelemetryPlugin.cpp)
target_link_libraries(state_telemetry_plugin PRIVATE client_core)
set_target_properties(state_telemetry_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS state_telemetry_plugin LIBRARY DESTINATION lib/robomaster/plugins)
