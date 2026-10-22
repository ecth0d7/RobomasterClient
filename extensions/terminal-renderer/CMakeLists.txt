# Geometry is independent from scene engines, networking and platform graphics.
qt_add_library(client_terminal_renderer_contract STATIC
    include/TerminalRendererContract.h src/TerminalRendererContract.cpp)
target_include_directories(client_terminal_renderer_contract PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include/robomaster>)
set_target_properties(client_terminal_renderer_contract PROPERTIES EXPORT_NAME terminal_renderer_contract)
target_link_libraries(client_terminal_renderer_contract PUBLIC Qt6::Core)
target_compile_options(client_terminal_renderer_contract PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
install(TARGETS client_terminal_renderer_contract EXPORT ClientPluginSDKTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/TerminalRendererContract.h DESTINATION include/robomaster COMPONENT PluginSDK)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalSceneHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalSceneHost.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(client_app PRIVATE client_plugin_packages)

option(ROBOMASTER_BUILD_TERMINAL_RENDERER_PLUGIN "Build optional normalized 2D scene renderer" ON)
if(ROBOMASTER_BUILD_TERMINAL_RENDERER_PLUGIN)
    qt_add_library(client_terminal_renderer STATIC include/Terminal2dRenderer.h src/Terminal2dRenderer.cpp)
    target_include_directories(client_terminal_renderer PUBLIC include)
    target_link_libraries(client_terminal_renderer PUBLIC client_plugin_sdk client_terminal_renderer_contract Qt6::Core)
    target_compile_options(client_terminal_renderer PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
    qt_add_plugin(terminal_renderer_2d_plugin SHARED CLASS_NAME Terminal2dRendererPlugin src/Terminal2dRendererPlugin.cpp)
    target_link_libraries(terminal_renderer_2d_plugin PRIVATE client_terminal_renderer)
    set_target_properties(terminal_renderer_2d_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
    install(TARGETS terminal_renderer_2d_plugin LIBRARY DESTINATION lib/robomaster/plugins)
endif()
