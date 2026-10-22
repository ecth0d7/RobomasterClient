qt_add_library(client_bridge SHARED include/TcpBridge.h src/TcpBridge.cpp)
target_include_directories(client_bridge PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:include/robomaster>")
target_link_libraries(client_bridge PUBLIC client_plugin_sdk Qt6::Network)
set_target_properties(client_bridge PROPERTIES
    EXPORT_NAME bridge
    WINDOWS_EXPORT_ALL_SYMBOLS ON
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
install(TARGETS client_bridge EXPORT ClientPluginSDKTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT PluginSDK
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/TcpBridge.h DESTINATION include/robomaster COMPONENT PluginSDK)
target_compile_options(client_bridge PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalBridgeHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalBridgeHost.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

qt_add_plugin(bridge_tcp_plugin SHARED CLASS_NAME TcpBridgePlugin src/TcpBridgePlugin.cpp)
target_link_libraries(bridge_tcp_plugin PRIVATE client_bridge)
set_target_properties(bridge_tcp_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS bridge_tcp_plugin LIBRARY DESTINATION lib/robomaster/plugins)
