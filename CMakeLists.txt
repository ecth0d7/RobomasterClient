cmake_minimum_required(VERSION 3.19)
project(RoboMasterMqttTest LANGUAGES CXX C)

# 设置C++标准（和参考配置一致）
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ========================= Qt6配置 =========================
# 不固定 Qt 安装目录。CMake 会使用 Qt Creator 工具链、CMAKE_PREFIX_PATH、
# Qt6_DIR 缓存参数或系统默认搜索路径查找 Qt。
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Widgets
    Network
    Gui
    Quick
    QuickControls2
    QuickLayouts
)

# Qt6标准工程设置（和参考配置一致）
qt_standard_project_setup()
set(CMAKE_AUTORCC ON)
# ========================= 第三方库查找=========================
# 1. FFmpeg依赖（参考配置的核心方式）
find_package(PkgConfig REQUIRED)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVFORMAT REQUIRED libavformat)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWSCALE REQUIRED libswscale)

# 2. MQTT（参考配置用pkg_check_modules查找mosquitto）
pkg_check_modules(MOSQUITTO REQUIRED libmosquitto)

# 3. Protobuf（参考配置用find_package）
find_package(Protobuf REQUIRED)

# ========================= Protobuf代码生成=========================
set(ROBOMASTER_PROTO
    ${CMAKE_CURRENT_SOURCE_DIR}/mqtt/protobuf/robomaster_custom_client.proto
)

# 协议 V2.0.0 使用 proto3 optional，官方要求 protoc >= 3.15。
# Ubuntu 20.04/22.04 常见的 3.12 编译器需要显式启用其兼容开关。
if(Protobuf_VERSION VERSION_LESS 3.15)
    set(PROTO_SRCS ${CMAKE_CURRENT_BINARY_DIR}/robomaster_custom_client.pb.cc)
    set(PROTO_HDRS ${CMAKE_CURRENT_BINARY_DIR}/robomaster_custom_client.pb.h)
    add_custom_command(
        OUTPUT ${PROTO_SRCS} ${PROTO_HDRS}
        COMMAND ${Protobuf_PROTOC_EXECUTABLE}
                --experimental_allow_proto3_optional
                --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
                --proto_path=${CMAKE_CURRENT_SOURCE_DIR}/mqtt/protobuf
                ${ROBOMASTER_PROTO}
        DEPENDS ${ROBOMASTER_PROTO}
        COMMENT "Generating RoboMaster V2 protobuf sources"
        VERBATIM
    )
else()
    protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${ROBOMASTER_PROTO})
endif()

# ========================= 源文件/头文件配置=========================
# 源文件列表
set(SOURCES
    main.cpp
    mqtt/src/MqttClient.cpp
    mqtt/src/MqttRecvHandlers.cpp
    mqtt/src/MqttSendHandlers.cpp
    udp/src/VideoImageProvider.cpp
    udp/src/VideoReceiver.cpp
    qml/src/GlobalInputFilter.cpp
    ${PROTO_SRCS}
)

# 头文件列表
set(HEADERS
    mqtt/include/IMqttHandler.h
    mqtt/include/MqttClient.h
    mqtt/include/MqttRecvHandlers.h
    mqtt/include/MqttSendHandlers.h
    udp/include/VideoImageProvider.h
    udp/include/VideoReceiver.h
    qml/include/GlobalInputFilter.h
    ${PROTO_HDRS}
)

# QML资源文件（适配你的QML需求）
set(QML_RESOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/qml/qrc/qml_resources.qrc
)

# ========================= 生成可执行文件=========================
qt_add_executable(RoboMasterMqttTest
    WIN32 MACOSX_BUNDLE  # 参考配置的跨平台标识
    ${SOURCES}
    ${HEADERS}
    ${QML_RESOURCES}
)

# ========================= 链接依赖库=========================
target_link_libraries(RoboMasterMqttTest
    PRIVATE
        # Qt6库（参考配置的Core/Widgets/Network/Gui + 你的Quick组件）
        Qt::Core
        Qt::Widgets
        Qt::Network
        Qt::Gui
        Qt::Quick
        Qt::QuickControls2
        Qt::QuickLayouts
        # FFmpeg库（参考配置的核心方式）
        ${AVCODEC_LIBRARIES}
        ${AVFORMAT_LIBRARIES}
        ${AVUTIL_LIBRARIES}
        ${SWSCALE_LIBRARIES}
        # MQTT/Protobuf（参考配置风格）
        ${MOSQUITTO_LIBRARIES}
        ${PROTOBUF_LIBRARIES}
        # 系统库（参考配置的pthread）
        pthread
        m  # FFmpeg依赖的数学库
)

# ========================= 头文件路径=========================
target_include_directories(RoboMasterMqttTest
    PRIVATE
        # FFmpeg头文件（参考配置方式）
        ${AVCODEC_INCLUDE_DIRS}
        ${AVFORMAT_INCLUDE_DIRS}
        ${AVUTIL_INCLUDE_DIRS}
        ${SWSCALE_INCLUDE_DIRS}
        # MQTT/Protobuf头文件（参考配置方式）
        ${MOSQUITTO_INCLUDE_DIRS}
        ${PROTOBUF_INCLUDE_DIRS}
        # 自定义头文件
        ${CMAKE_CURRENT_BINARY_DIR}  # Protobuf生成的头文件（参考配置核心）
        ${CMAKE_CURRENT_SOURCE_DIR}/mqtt/include
        ${CMAKE_CURRENT_SOURCE_DIR}/mqtt/protobuf
        ${CMAKE_CURRENT_SOURCE_DIR}/udp/include
        ${CMAKE_CURRENT_SOURCE_DIR}/qml/include
        
)

# ========================= 安装配置=========================
include(GNUInstallDirs)
install(TARGETS RoboMasterMqttTest
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# 部署脚本（Qt6自动部署，参考配置风格）
qt_generate_deploy_app_script(
    TARGET RoboMasterMqttTest
    OUTPUT_SCRIPT deploy_script
    NO_UNSUPPORTED_PLATFORM_ERROR
)
install(SCRIPT ${deploy_script})

# ========================= 编译选项=========================
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(RoboMasterMqttTest PRIVATE 
        -O3 
        -Wall 
        -Wno-deprecated-declarations  # 和参考配置完全一致
        -Wno-unused-parameter         # 补充FFmpeg编译友好选项
        -Wno-sign-compare
    )
endif()

# ========================= QML配置=========================
set(QML_IMPORT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/qml CACHE STRING "QML导入路径")
set(QML2_IMPORT_PATH ${QML_IMPORT_PATH} CACHE STRING "QML2导入路径")
