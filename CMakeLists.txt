cmake_minimum_required(VERSION 3.19)
get_filename_component(_client_source_root "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
get_filename_component(_client_build_root "${CMAKE_CURRENT_BINARY_DIR}" REALPATH)
if(_client_source_root STREQUAL _client_build_root)
    message(FATAL_ERROR
        "In-source builds are disabled to protect source QML and resources. "
        "Use cmake --preset debug, then cmake --build --preset debug.")
endif()
# Older generators emit ../source dependencies that break when build is a
# symlink outside the source tree. Newer CMake supports this layout directly.
if(CMAKE_VERSION VERSION_LESS 3.24
        AND NOT "${CMAKE_CURRENT_BINARY_DIR}" STREQUAL "${_client_build_root}")
    message(FATAL_ERROR
        "CMake ${CMAKE_VERSION} cannot safely generate this symlinked build.\n"
        "Use CMake 3.24 or newer (the Qt SDK includes a compatible CMake),\n"
        "or configure the physical build directory:\n"
        "  cmake -S \"${_client_source_root}\" -B \"${_client_build_root}\"\n"
        "Or use cmake --preset debug, then cmake --build --preset debug.")
endif()
project(RoboMasterClient VERSION 2.0.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
include(GNUInstallDirs)
option(BUILD_TESTING "Build the external validation workspace" OFF)
include(CTest)
get_filename_component(_support_project "${CMAKE_CURRENT_SOURCE_DIR}" NAME)
set(ROBOMASTER_TEST_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../ProjectSupport/${_support_project}/tests" CACHE PATH "External project validation sources")
set(ROBOMASTER_TOOL_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../ProjectSupport/${_support_project}/tools" CACHE PATH "External developer tools")
option(ROBOMASTER_BUILD_DEVELOPER_TOOLS "Build external preview and diagnostic tools" OFF)
set(CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR};$ORIGIN;$ORIGIN/../../../${CMAKE_INSTALL_LIBDIR}")

if(NOT Qt6_DIR AND NOT CMAKE_PREFIX_PATH)
    file(GLOB _qt_candidates "$ENV{HOME}/Qt/*/gcc_64/lib/cmake/Qt6" "$ENV{HOME}/Qt/*/linux_gcc_64/lib/cmake/Qt6")
    if(_qt_candidates)
        list(SORT _qt_candidates COMPARE NATURAL ORDER DESCENDING)
        list(GET _qt_candidates 0 Qt6_DIR)
    endif()
endif()
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2)
qt_standard_project_setup()
# moc headers must include through target include directories, rather than
# walking ../ out of a build symlink into the wrong physical parent directory.
set(CMAKE_AUTOMOC_PATH_PREFIX ON)
set(CMAKE_AUTORCC ON)
find_package(Protobuf REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MOSQUITTO REQUIRED IMPORTED_TARGET libmosquitto)
pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET libavcodec libavutil libswscale)
add_subdirectory(plugins)
add_subdirectory(protocol)
add_subdirectory(core)
add_subdirectory(mqtt)
add_subdirectory(udp)
add_subdirectory(input)
add_subdirectory(app)
add_subdirectory(extensions)
include(cmake/PluginDocumentation.cmake)
# Build every archive exported by the development component before installing
# it. Building only the shared ABI leaves fresh SDK-only builds incomplete.
add_custom_target(client_plugin_sdk_development
    DEPENDS client_plugin_sdk client_terminal_renderer_contract client_decision client_codex_decision client_speech
        client_terminal_links client_terminal_team_contract client_bridge)
if(TARGET client_terminal_team_verifier AND TARGET client_terminal_team_aggregation)
    add_dependencies(client_plugin_sdk_development client_terminal_team_verifier client_terminal_team_aggregation)
endif()
# Preserve the executable name used by existing Qt Creator configurations.
qt_add_executable(RoboMasterMqttTest main.cpp)
foreach(_feature season-audit source-health tactical-timeline)
    if(TARGET ${_feature}_assets)
        add_dependencies(RoboMasterMqttTest ${_feature}_assets)
    endif()
endforeach()
if(TARGET battlefield_minimap_assets)
    add_dependencies(RoboMasterMqttTest battlefield_minimap_assets)
endif()
if(TARGET battlefield_3d_assets)
    add_dependencies(RoboMasterMqttTest battlefield_3d_assets)
    # Discover lazy deployment imports without linking Quick3D into the core.
    target_sources(RoboMasterMqttTest PRIVATE extensions/battlefield-3d/qml/Field3D.qml)
endif()
qt_add_library(client_graphics STATIC
    app/include/GraphicsBootstrap.h app/src/GraphicsBootstrap.cpp)
target_include_directories(client_graphics PUBLIC app/include)
target_link_libraries(client_graphics PUBLIC Qt6::Quick)
if(ROBOMASTER_BUILD_DEVELOPER_TOOLS)
    foreach(_tool UiPreview SeasonWorkspace DecisionProbe VideoStress)
        if(NOT EXISTS "${ROBOMASTER_TOOL_SOURCE_DIR}/${_tool}.cpp")
            message(FATAL_ERROR "Developer tool source missing: ${ROBOMASTER_TOOL_SOURCE_DIR}/${_tool}.cpp; disable ROBOMASTER_BUILD_DEVELOPER_TOOLS for the application-only build")
        endif()
    endforeach()
    qt_add_executable(client_ui_preview "${ROBOMASTER_TOOL_SOURCE_DIR}/UiPreview.cpp")
    qt_add_executable(client_season_workspace "${ROBOMASTER_TOOL_SOURCE_DIR}/SeasonWorkspace.cpp")
    qt_add_executable(client_decision_probe "${ROBOMASTER_TOOL_SOURCE_DIR}/DecisionProbe.cpp")
    qt_add_executable(client_video_stress "${ROBOMASTER_TOOL_SOURCE_DIR}/VideoStress.cpp")
    target_link_libraries(client_decision_probe PRIVATE client_app client_plugin_sdk)
    add_dependencies(client_decision_probe decision_http_plugin)
    target_link_libraries(client_video_stress PRIVATE client_udp Qt6::Qml PkgConfig::FFMPEG)
    add_dependencies(client_video_stress video_ffmpeg_plugin)
    target_link_libraries(client_ui_preview PRIVATE client_graphics Qt6::Quick Qt6::Qml Qt6::QuickControls2)
    target_compile_definitions(client_ui_preview PRIVATE CLIENT_PREVIEW_UI_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
    target_link_libraries(client_season_workspace PRIVATE client_graphics client_app client_plugin_packages Qt6::QuickControls2)
    target_compile_definitions(client_season_workspace PRIVATE CLIENT_SEASON_UI_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
endif()
add_custom_target(client_ui_assets ALL
    COMMAND ${CMAKE_COMMAND}
        "-DCLIENT_UI_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}/qml"
        "-DCLIENT_UI_DESTINATION_DIR=${CMAKE_BINARY_DIR}/qml"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CopyUiAssets.cmake"
    COMMENT "复制可编辑 QML 包和外部图像资源" VERBATIM)
# 只向 IDE 登记源码，不嵌入 qrc。新控件必须进入项目模型，Designer 才能发现它们。
file(GLOB _client_ui_sources CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/components/*.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/components/*.js")
file(GLOB_RECURSE _client_public_ui_sources CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/imports/*.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/imports/qmldir")
target_sources(client_ui_assets PRIVATE ${_client_ui_sources} ${_client_public_ui_sources}
    qml/RoboMasterUi.qmlproject qml/manifest.json)
target_link_libraries(RoboMasterMqttTest PRIVATE client_graphics client_app client_input client_udp client_plugin_packages Qt6::QuickControls2)
add_dependencies(RoboMasterMqttTest mqtt_mosquitto_plugin protocol_rm2026_plugin video_ffmpeg_plugin
    state_telemetry_plugin input_qt_plugin policy_operator_plugin bridge_tcp_plugin decision_http_plugin
    speech_espeak_plugin speech_http_plugin decision_codex_plugin client_ui_assets client_plugin_guides)
add_dependencies(RoboMasterMqttTest protocol_terminal_local_plugin
    terminal_loopback_plugin terminal_mqtt_plugin terminal_udp_plugin)
if(TARGET battlefield_process_plugin)
    add_dependencies(RoboMasterMqttTest battlefield_process_plugin battlefield_runtime)
endif()
if(TARGET client_season_workspace)
    add_dependencies(client_season_workspace protocol_terminal_local_plugin
        terminal_loopback_plugin terminal_mqtt_plugin terminal_udp_plugin bridge_tcp_plugin)
endif()
if(TARGET team_aggregation_plugin)
    add_dependencies(RoboMasterMqttTest team_aggregation_plugin)
endif()
if(TARGET terminal_team_plugin)
    add_dependencies(RoboMasterMqttTest terminal_team_plugin)
    if(TARGET client_season_workspace)
        add_dependencies(client_season_workspace terminal_team_plugin)
    endif()
endif()
if(TARGET team_aggregation_plugin OR TARGET terminal_team_plugin)
    install(FILES docs/licenses/OpenSSL-Ubuntu-copyright.txt docs/licenses/Apache-2.0.txt
        DESTINATION ${CMAKE_INSTALL_DATADIR}/robomaster/licenses)
endif()
if(TARGET terminal_renderer_2d_plugin)
    add_dependencies(RoboMasterMqttTest terminal_renderer_2d_plugin)
    if(TARGET client_season_workspace)
        add_dependencies(client_season_workspace terminal_renderer_2d_plugin)
    endif()
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    foreach(target client_protocol client_core client_mqtt client_udp_packets client_udp client_input client_app RoboMasterMqttTest)
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
    endforeach()
endif()
install(TARGETS RoboMasterMqttTest RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY qml/ DESTINATION ${CMAKE_INSTALL_DATADIR}/robomaster/qml
    PATTERN ".qtcreator" EXCLUDE
    PATTERN "*.qmlproject.user*" EXCLUDE)
install(DIRECTORY extensions/shark-local-roster
    DESTINATION ${CMAKE_INSTALL_DATADIR}/robomaster/extensions)
# 原生插件按需加载，不直接链接到主程序，因此安装时显式收集它们的依赖。
# 只扫描主程序会漏掉默认协议所需的 libprotobuf，导致全新安装无法加载插件。
set(_native_plugin_deploy_paths "")
set(_native_plugin_targets mqtt_mosquitto_plugin protocol_rm2026_plugin video_ffmpeg_plugin
        state_telemetry_plugin input_qt_plugin policy_operator_plugin bridge_tcp_plugin
        decision_http_plugin decision_codex_plugin speech_espeak_plugin speech_http_plugin)
list(APPEND _native_plugin_targets protocol_terminal_local_plugin
    terminal_loopback_plugin terminal_mqtt_plugin terminal_udp_plugin)
if(TARGET team_aggregation_plugin)
    list(APPEND _native_plugin_targets team_aggregation_plugin)
endif()
if(TARGET terminal_team_plugin)
    list(APPEND _native_plugin_targets terminal_team_plugin)
endif()
if(TARGET terminal_renderer_2d_plugin)
    list(APPEND _native_plugin_targets terminal_renderer_2d_plugin)
endif()
foreach(_plugin IN LISTS _native_plugin_targets)
    string(APPEND _native_plugin_deploy_paths "\n        \"$<TARGET_FILE:${_plugin}>\"")
endforeach()
qt6_generate_deploy_script(TARGET RoboMasterMqttTest OUTPUT_SCRIPT deploy_script CONTENT "
    qt_deploy_qml_imports(TARGET RoboMasterMqttTest PLUGINS_FOUND qml_plugins)
    qt_deploy_runtime_dependencies(
        EXECUTABLE \"$<TARGET_FILE:RoboMasterMqttTest>\"
        ADDITIONAL_LIBRARIES \"$<TARGET_FILE:client_protocol>\" \"$<TARGET_FILE:client_plugin_sdk>\"
        ADDITIONAL_MODULES \${qml_plugins} ${_native_plugin_deploy_paths}
        GENERATE_QT_CONF NO_TRANSLATIONS
    )")
install(SCRIPT ${deploy_script})
if(TARGET Qt6::QOffscreenIntegrationPlugin)
    install(FILES $<TARGET_FILE:Qt6::QOffscreenIntegrationPlugin> DESTINATION plugins/platforms)
endif()
# 外置 QML 没有 qt_add_qml_module 提供的自动导入元信息，显式登记所选 Qt 的模块目录。
# 保留使用者额外的路径，避免升级配置时覆盖队伍自定义控件目录。
set(_client_qml_imports ${QML_IMPORT_PATH}
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/components"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/imports"
    "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_QML}")
list(REMOVE_DUPLICATES _client_qml_imports)
set(QML_IMPORT_PATH "${_client_qml_imports}" CACHE STRING "QML Designer import paths" FORCE)
include(cmake/ValidateAssets.cmake)
if(BUILD_TESTING)
    if(NOT EXISTS "${ROBOMASTER_TEST_SOURCE_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "External validation sources are unavailable. Set ROBOMASTER_TEST_SOURCE_DIR, or build the application with BUILD_TESTING=OFF.")
    endif()
    add_subdirectory("${ROBOMASTER_TEST_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/validation")
endif()
