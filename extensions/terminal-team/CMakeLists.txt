# Pure contracts stay available without the optional authenticated transport.
qt_add_library(client_terminal_team_contract STATIC
    include/TerminalTeamContract.h include/TerminalTeamProofVerifier.h src/TerminalTeamContract.cpp)
target_include_directories(client_terminal_team_contract PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:include/robomaster>")
target_link_libraries(client_terminal_team_contract PUBLIC Qt6::Core)
set_target_properties(client_terminal_team_contract PROPERTIES EXPORT_NAME terminal_team_contract)
install(TARGETS client_terminal_team_contract EXPORT ClientPluginSDKTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/TerminalTeamContract.h include/TerminalTeamProofVerifier.h
    DESTINATION include/robomaster COMPONENT PluginSDK)
target_compile_options(client_terminal_team_contract PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalTeamHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalTeamHost.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

if(ROBOMASTER_BUILD_TERMINAL_TEAM_PLUGIN)
    if(TARGET client_team_network)
        # The host's verifier is independent of whichever package transports
        # a cut. It shares the actual crypto implementation but opens no link.
        qt_add_library(client_terminal_team_verifier SHARED
            include/TerminalTeamVerifier.h src/TerminalTeamVerifier.cpp)
        target_include_directories(client_terminal_team_verifier PUBLIC
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
            "$<INSTALL_INTERFACE:include/robomaster>")
        target_link_libraries(client_terminal_team_verifier PUBLIC Qt6::Core
            PRIVATE client_team_network client_terminal_team_contract)
        target_compile_options(client_terminal_team_verifier PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
        set_target_properties(client_terminal_team_verifier PROPERTIES
            EXPORT_NAME terminal_team_verifier WINDOWS_EXPORT_ALL_SYMBOLS ON
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
        target_link_libraries(client_app PRIVATE client_terminal_team_verifier)
        target_compile_definitions(client_app PUBLIC CLIENT_HAS_TERMINAL_TEAM_VERIFIER=1)
        qt_add_library(client_terminal_team_aggregation SHARED
            include/TerminalTeamAggregation.h src/TerminalTeamAggregation.cpp)
        target_include_directories(client_terminal_team_aggregation PUBLIC
            "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
            "$<INSTALL_INTERFACE:include/robomaster>")
        target_link_libraries(client_terminal_team_aggregation PUBLIC client_plugin_sdk client_terminal_team_contract
            PRIVATE client_team_network)
        target_compile_options(client_terminal_team_aggregation PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
        set_target_properties(client_terminal_team_aggregation PROPERTIES
            EXPORT_NAME terminal_team_aggregation WINDOWS_EXPORT_ALL_SYMBOLS ON
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
        install(TARGETS client_terminal_team_verifier client_terminal_team_aggregation EXPORT ClientPluginSDKTargets
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT PluginSDK
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
        install(FILES include/TerminalTeamVerifier.h include/TerminalTeamAggregation.h
            DESTINATION include/robomaster COMPONENT PluginSDK)
        qt_add_plugin(terminal_team_plugin SHARED CLASS_NAME TerminalTeamPlugin src/TerminalTeamPlugin.cpp)
        target_link_libraries(terminal_team_plugin PRIVATE client_terminal_team_aggregation)
        set_target_properties(terminal_team_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
        install(TARGETS terminal_team_plugin LIBRARY DESTINATION lib/robomaster/plugins)
    else()
        message(STATUS "Optional terminal-team plugin omitted: authenticated transport unavailable")
    endif()
endif()
