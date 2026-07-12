cmake_minimum_required(VERSION 3.19)
project(HeroCustomClient LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

# 优先使用 Qt Creator Kit、-DCMAKE_PREFIX_PATH 或 -DQt6_DIR 提供的路径。
# 如果外部没有配置，则自动寻找 Qt Online Installer 的常见用户安装目录，
# 不绑定具体用户名、Qt 版本或编译套件。
if(DEFINED Qt6_DIR AND Qt6_DIR MATCHES "-NOTFOUND$")
    unset(Qt6_DIR CACHE)
endif()
if(NOT Qt6_DIR AND NOT CMAKE_PREFIX_PATH)
    file(GLOB _qt6_user_candidates LIST_DIRECTORIES true
        "$ENV{HOME}/Qt/*/gcc_64/lib/cmake/Qt6"
        "$ENV{HOME}/Qt/*/linux_gcc_64/lib/cmake/Qt6"
    )
    if(_qt6_user_candidates)
        list(SORT _qt6_user_candidates COMPARE NATURAL ORDER DESCENDING)
        list(GET _qt6_user_candidates 0 _qt6_auto_dir)
        set(Qt6_DIR "${_qt6_auto_dir}" CACHE PATH "Auto-detected Qt6 package directory")
        message(STATUS "Auto-detected Qt6: ${Qt6_DIR}")
    endif()
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 QuickLayouts)
find_package(PkgConfig REQUIRED)
find_package(Protobuf REQUIRED)
pkg_check_modules(MOSQUITTO REQUIRED libmosquitto)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWSCALE REQUIRED libswscale)

set(HERO_PROTO ${CMAKE_CURRENT_SOURCE_DIR}/protobuf/hero_custom_client.proto)
if(Protobuf_VERSION VERSION_LESS 3.15)
    set(PROTO_SRCS ${CMAKE_CURRENT_BINARY_DIR}/hero_custom_client.pb.cc)
    set(PROTO_HDRS ${CMAKE_CURRENT_BINARY_DIR}/hero_custom_client.pb.h)
    add_custom_command(
        OUTPUT ${PROTO_SRCS} ${PROTO_HDRS}
        COMMAND ${Protobuf_PROTOC_EXECUTABLE}
                --experimental_allow_proto3_optional
                --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
                --proto_path=${CMAKE_CURRENT_SOURCE_DIR}/protobuf
                ${HERO_PROTO}
        DEPENDS ${HERO_PROTO}
        COMMENT "Generating hero custom-client protobuf sources"
        VERBATIM
    )
else()
    protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${HERO_PROTO})
endif()

qt_add_executable(HeroCustomClient
    main.cpp
    include/HeroClient.h
    include/HeroProtocol.h
    include/H264Decoder.h
    include/VideoImageProvider.h
    src/HeroClient.cpp
    src/HeroProtocol.cpp
    src/H264Decoder.cpp
    src/VideoImageProvider.cpp
    ${PROTO_SRCS}
    ${PROTO_HDRS}
    qml.qrc
)

target_include_directories(HeroCustomClient PRIVATE
    include
    ${CMAKE_CURRENT_BINARY_DIR}
    ${MOSQUITTO_INCLUDE_DIRS}
    ${AVCODEC_INCLUDE_DIRS}
    ${AVUTIL_INCLUDE_DIRS}
    ${SWSCALE_INCLUDE_DIRS}
    ${Protobuf_INCLUDE_DIRS}
)

target_link_libraries(HeroCustomClient PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::QuickLayouts
    ${MOSQUITTO_LIBRARIES}
    ${AVCODEC_LIBRARIES}
    ${AVUTIL_LIBRARIES}
    ${SWSCALE_LIBRARIES}
    ${Protobuf_LIBRARIES}
)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(HeroCustomClient PRIVATE -Wall -Wextra -Wpedantic)
endif()
