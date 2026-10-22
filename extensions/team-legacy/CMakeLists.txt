# Historical schema2 contracts are preserved for existing source references.
# They do not become an active 2027 runtime profile.
qt_add_library(client_team_contract STATIC include/TeamDataContract.h src/TeamDataContract.cpp)
target_include_directories(client_team_contract PUBLIC include)
target_link_libraries(client_team_contract PUBLIC Qt6::Core)
target_compile_options(client_team_contract PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TeamConfiguration.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TeamConfiguration.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TeamViewCache.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TeamViewCache.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TeamSourceExport.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TeamSourceExport.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

if(ROBOMASTER_BUILD_TEAM_PLUGIN)
    if(TARGET client_team_network)
        qt_add_library(client_team_aggregation STATIC include/TeamAggregation.h src/TeamAggregation.cpp)
        target_include_directories(client_team_aggregation PUBLIC include)
        target_link_libraries(client_team_aggregation PUBLIC client_plugin_sdk client_team_contract client_team_network Qt6::Network)
        target_compile_options(client_team_aggregation PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
        qt_add_plugin(team_aggregation_plugin SHARED CLASS_NAME TeamAggregationPlugin src/TeamAggregationPlugin.cpp)
        target_link_libraries(team_aggregation_plugin PRIVATE client_team_aggregation)
        set_target_properties(team_aggregation_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
        install(TARGETS team_aggregation_plugin LIBRARY DESTINATION lib/robomaster/plugins)
    else()
        message(STATUS "Optional legacy team aggregation omitted: authenticated transport unavailable")
    endif()
endif()
