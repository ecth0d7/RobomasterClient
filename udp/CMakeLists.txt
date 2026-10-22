# Packet assembly can be tested without a decoder, socket or window.
qt_add_library(client_udp_packets STATIC include/DatagramAssembler.h src/DatagramAssembler.cpp)
target_include_directories(client_udp_packets PUBLIC include)
target_link_libraries(client_udp_packets PUBLIC Qt6::Core)

qt_add_library(client_udp STATIC
    include/VideoReceiver.h src/VideoReceiver.cpp
    src/DecodedFramePool.h src/DecodedFramePool.cpp
    src/AnnexBCodecProbe.h src/AnnexBCodecProbe.cpp
    include/VideoImageProvider.h src/VideoImageProvider.cpp)
target_include_directories(client_udp PUBLIC include)
target_link_libraries(client_udp PUBLIC client_udp_packets client_plugin_sdk Qt6::Gui Qt6::Network Qt6::Quick PRIVATE PkgConfig::FFMPEG)
qt_add_plugin(video_ffmpeg_plugin SHARED CLASS_NAME FfmpegVideoPlugin src/FfmpegVideoPlugin.cpp)
target_link_libraries(video_ffmpeg_plugin PRIVATE client_udp)
set_target_properties(video_ffmpeg_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS video_ffmpeg_plugin LIBRARY DESTINATION lib/robomaster/plugins)
