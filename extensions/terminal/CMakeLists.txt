# Reuse the actual byte transports from independently built packages without
# exporting the host's private MQTT target or its build-machine pkg-config path.
qt_add_library(client_terminal_links SHARED include/TerminalLinks.h src/TerminalLinks.cpp)
target_include_directories(client_terminal_links PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:include/robomaster>")
target_link_libraries(client_terminal_links PUBLIC client_plugin_sdk PRIVATE client_mqtt Qt6::Network)
set_target_properties(client_terminal_links PROPERTIES
    EXPORT_NAME terminal_links
    WINDOWS_EXPORT_ALL_SYMBOLS ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
install(TARGETS client_terminal_links EXPORT ClientPluginSDKTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT PluginSDK
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/TerminalLinks.h DESTINATION include/robomaster COMPONENT PluginSDK)
target_compile_options(client_terminal_links PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)

qt_add_plugin(terminal_loopback_plugin SHARED CLASS_NAME LoopbackTerminalPlugin src/LoopbackTerminalPlugin.cpp)
qt_add_plugin(terminal_mqtt_plugin SHARED CLASS_NAME MqttTerminalPlugin src/MqttTerminalPlugin.cpp)
qt_add_plugin(terminal_udp_plugin SHARED CLASS_NAME UdpTerminalPlugin src/UdpTerminalPlugin.cpp)
foreach(_terminal_plugin terminal_loopback_plugin terminal_mqtt_plugin terminal_udp_plugin)
    target_link_libraries(${_terminal_plugin} PRIVATE client_terminal_links)
    set_target_properties(${_terminal_plugin} PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
    install(TARGETS ${_terminal_plugin} LIBRARY DESTINATION lib/robomaster/plugins)
endforeach()

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalGateway.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalGateway.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalGatewayContract.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalGatewayContract.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
