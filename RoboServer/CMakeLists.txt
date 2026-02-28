cmake_minimum_required(VERSION 3.10)
project(RoboServer)

set(CMAKE_CXX_STANDARD 17)

# 查找 FFmpeg
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED libavcodec libavformat libavutil libswscale)

add_executable(server main.cpp)

target_include_directories(server PRIVATE ${FFMPEG_INCLUDE_DIRS})
target_link_directories(server PRIVATE ${FFMPEG_LIBRARY_DIRS})
target_link_libraries(server PRIVATE ${FFMPEG_LIBRARIES})
