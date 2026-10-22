# Configuration guides travel with native plugins as well as source checkouts.
# Documentation is not a runtime dependency and never enables a plugin.
add_custom_target(client_plugin_guides ALL)
set(_client_plugin_guide_directories
    plugins mqtt protocol udp core input app
    extensions/season-audit extensions/source-health extensions/tactical-timeline
    extensions/battlefield extensions/battlefield-minimap extensions/battlefield-3d extensions/bridge extensions/data-sources
    extensions/decision extensions/hero-lob-video extensions/hero-projectile
    extensions/shark-local-roster extensions/speech extensions/team-legacy
    extensions/team-network extensions/terminal extensions/terminal-renderer
    extensions/terminal-team extensions/yolo-vision)
foreach(_directory IN LISTS _client_plugin_guide_directories)
    set(_guide "${PROJECT_SOURCE_DIR}/${_directory}/README.md")
    if(EXISTS "${_guide}")
        set(_destination "${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/${_directory}")
        add_custom_command(TARGET client_plugin_guides POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_destination}"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_guide}" "${_destination}/README.md"
            VERBATIM)
        install(FILES "${_guide}"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/${_directory}" COMPONENT PluginSDK)
    endif()
endforeach()

# Preserve source-relative links from every guide in a source-free deployment.
set(_client_guide_root "${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides")
set(_client_guide_book "${PROJECT_SOURCE_DIR}/docs/TECHNICAL.md")
set(_client_guide_contract "${PROJECT_SOURCE_DIR}/plugins/CONFIGURATION_CONTRACT.md")
file(GLOB_RECURSE _client_guide_media CONFIGURE_DEPENDS "${PROJECT_SOURCE_DIR}/docs/media/*")
set(_client_guide_dependencies "${_client_guide_book}" ${_client_guide_media})
if(EXISTS "${_client_guide_contract}")
    list(APPEND _client_guide_dependencies "${_client_guide_contract}")
    add_custom_command(TARGET client_plugin_guides POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_client_guide_root}/plugins"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_client_guide_contract}"
            "${_client_guide_root}/plugins/CONFIGURATION_CONTRACT.md" VERBATIM)
    install(FILES "${_client_guide_contract}"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/plugins" COMPONENT PluginSDK)
endif()
add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/plugin-guide-media.stamp"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_client_guide_root}/docs"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_client_guide_book}"
        "${_client_guide_root}/docs/TECHNICAL.md"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${PROJECT_SOURCE_DIR}/docs/media"
        "${_client_guide_root}/docs/media"
    COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_BINARY_DIR}/plugin-guide-media.stamp"
    DEPENDS ${_client_guide_dependencies} VERBATIM)
add_custom_target(client_plugin_guide_media DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/plugin-guide-media.stamp")
add_dependencies(client_plugin_guides client_plugin_guide_media)
install(FILES "${_client_guide_book}"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/docs" COMPONENT PluginSDK)
install(DIRECTORY "${PROJECT_SOURCE_DIR}/docs/media/"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/docs/media" COMPONENT PluginSDK
    FILES_MATCHING PATTERN "*.webp" PATTERN "*.gif" PATTERN "*.svg"
        PATTERN "*.png" PATTERN "*.jpg" PATTERN "*.jpeg" PATTERN "*-LICENSE.txt")

# The technical book links to selected implementation files, not the whole tree.
# Include those small references so guides remain useful without a source checkout.
file(READ "${_client_guide_book}" _client_guide_text)
string(REGEX MATCHALL [=[\(\.\./[^)#]+\)]=] _client_guide_links "${_client_guide_text}")
set(_client_guide_references "extensions/battlefield-3d/assets/CAD-NOTICE.md")
foreach(_link IN LISTS _client_guide_links)
    string(REGEX REPLACE [=[^\(\.\./|\)$]=] "" _relative "${_link}")
    list(APPEND _client_guide_references "${_relative}")
endforeach()
list(REMOVE_DUPLICATES _client_guide_references)
foreach(_relative IN LISTS _client_guide_references)
    # 目录链接仅用于导航，不能交给 install(FILES)，也不递归打包其中源码。
    if(EXISTS "${PROJECT_SOURCE_DIR}/${_relative}"
            AND NOT IS_DIRECTORY "${PROJECT_SOURCE_DIR}/${_relative}")
        get_filename_component(_parent "${_relative}" DIRECTORY)
        add_custom_command(TARGET client_plugin_guides POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${_client_guide_root}/${_parent}"
            COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${PROJECT_SOURCE_DIR}/${_relative}"
                "${_client_guide_root}/${_relative}" VERBATIM)
        install(FILES "${PROJECT_SOURCE_DIR}/${_relative}"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/robomaster/plugin-guides/${_parent}" COMPONENT PluginSDK)
    endif()
endforeach()
