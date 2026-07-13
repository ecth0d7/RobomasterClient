cmake_minimum_required(VERSION 3.19)
project(HeroProtocolTestServer LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(DEFINED Qt6_DIR AND Qt6_DIR MATCHES "-NOTFOUND$")
    unset(Qt6_DIR CACHE)
endif()
if(NOT Qt6_DIR AND NOT CMAKE_PREFIX_PATH)
    file(GLOB _qt6_candidates LIST_DIRECTORIES true
        "$ENV{HOME}/Qt/*/gcc_64/lib/cmake/Qt6"
        "$ENV{HOME}/Qt/*/linux_gcc_64/lib/cmake/Qt6")
    if(_qt6_candidates)
        list(SORT _qt6_candidates COMPARE NATURAL ORDER DESCENDING)
        list(GET _qt6_candidates 0 _qt6_dir)
        set(Qt6_DIR "${_qt6_dir}" CACHE PATH "Auto-detected Qt6 package directory")
    endif()
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Network)
find_package(PkgConfig REQUIRED)
find_package(Protobuf REQUIRED)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVUTIL REQUIRED libavutil)

set(HERO_PROTO ${CMAKE_CURRENT_LIST_DIR}/../hero_custom_client/protobuf/hero_custom_client.proto)
if(Protobuf_VERSION VERSION_LESS 3.15)
    set(PROTO_SRCS ${CMAKE_CURRENT_BINARY_DIR}/hero_custom_client.pb.cc)
    set(PROTO_HDRS ${CMAKE_CURRENT_BINARY_DIR}/hero_custom_client.pb.h)
    add_custom_command(
        OUTPUT ${PROTO_SRCS} ${PROTO_HDRS}
        COMMAND ${Protobuf_PROTOC_EXECUTABLE}
                --experimental_allow_proto3_optional
                --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
                --proto_path=${CMAKE_CURRENT_LIST_DIR}/../hero_custom_client/protobuf
                ${HERO_PROTO}
        DEPENDS ${HERO_PROTO}
        VERBATIM)
else()
    protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${HERO_PROTO})
endif()

add_executable(HeroProtocolTestServer main.cpp ${PROTO_SRCS} ${PROTO_HDRS})
target_include_directories(HeroProtocolTestServer PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR} ${Protobuf_INCLUDE_DIRS}
    ${AVCODEC_INCLUDE_DIRS} ${AVUTIL_INCLUDE_DIRS})
target_link_libraries(HeroProtocolTestServer PRIVATE
    Qt6::Core Qt6::Network ${Protobuf_LIBRARIES} ${AVCODEC_LIBRARIES} ${AVUTIL_LIBRARIES})
target_compile_options(HeroProtocolTestServer PRIVATE -Wall -Wextra -Wpedantic)
