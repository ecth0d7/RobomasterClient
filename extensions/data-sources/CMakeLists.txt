# Host-side source admission remains in client_app; physical feature ownership
# is separate from the stable service interfaces and runtime activation policy.
target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/DataSourceHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/DataSourceHost.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/SourceRegistry.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/SourceRegistry.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/OfficialSourceSnapshot.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/OfficialSourceSnapshot.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalPluginSourceHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalPluginSourceHost.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
