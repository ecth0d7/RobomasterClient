# Framing is independent of sockets, rendering and the optional decoder host.
qt_add_library(client_hero_video_packets STATIC
    include/HeroVideoPackets.h src/HeroVideoPackets.cpp)
target_include_directories(client_hero_video_packets PUBLIC include)
target_link_libraries(client_hero_video_packets PUBLIC Qt6::Core)
target_sources(client_app PRIVATE include/HeroVideoHost.h src/HeroVideoHost.cpp)
target_include_directories(client_app PUBLIC include)
target_link_libraries(client_app PRIVATE client_hero_video_packets)
target_compile_definitions(client_app PUBLIC CLIENT_HAS_HERO_LOB_VIDEO=1)
