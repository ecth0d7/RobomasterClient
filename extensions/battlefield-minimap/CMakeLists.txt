add_custom_target(battlefield_minimap_assets ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/extensions/battlefield-minimap")
install(DIRECTORY qml DESTINATION share/robomaster/extensions/battlefield-minimap)
install(FILES manifest.json README.md DESTINATION share/robomaster/extensions/battlefield-minimap)
