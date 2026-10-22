# The authenticated transport is shared by legacy and schema3 aggregation.
# Its absence must not prevent the pure contracts or single-client hosts.
if(ROBOMASTER_BUILD_TEAM_PLUGIN OR ROBOMASTER_BUILD_TERMINAL_TEAM_PLUGIN)
    find_package(OpenSSL 3.0 QUIET)
    if(OpenSSL_FOUND)
        qt_add_library(client_team_network STATIC include/TeamNetwork.h src/TeamNetwork.cpp)
        target_include_directories(client_team_network PUBLIC include)
        target_link_libraries(client_team_network PUBLIC Qt6::Network
            PRIVATE PkgConfig::MOSQUITTO OpenSSL::Crypto OpenSSL::SSL)
        target_compile_options(client_team_network PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
    else()
        message(STATUS "Optional authenticated team transport omitted: OpenSSL development package unavailable")
    endif()
endif()
