# Keep the authoring project and runtime resources portable. Creator's local
# Kit/environment preferences belong to the source checkout's user, not a UI pack.
if(NOT DEFINED CLIENT_UI_SOURCE_DIR OR NOT DEFINED CLIENT_UI_DESTINATION_DIR)
    message(FATAL_ERROR "CLIENT_UI_SOURCE_DIR and CLIENT_UI_DESTINATION_DIR are required")
endif()
get_filename_component(_client_ui_source "${CLIENT_UI_SOURCE_DIR}" REALPATH)
get_filename_component(_client_ui_destination "${CLIENT_UI_DESTINATION_DIR}" REALPATH)
if(NOT IS_DIRECTORY "${_client_ui_source}")
    message(FATAL_ERROR "UI source directory is missing: ${_client_ui_source}")
endif()
# The destination must never be the authoring directory or one of its parents,
# including through symlinks.
file(RELATIVE_PATH _client_ui_source_from_destination
    "${_client_ui_destination}" "${_client_ui_source}")
if(NOT IS_ABSOLUTE "${_client_ui_source_from_destination}"
        AND NOT _client_ui_source_from_destination MATCHES "^\\.\\.(/|$)")
    message(FATAL_ERROR "UI destination must not equal or contain the UI source: ${_client_ui_destination}")
endif()
file(RELATIVE_PATH _client_ui_destination_from_source
    "${_client_ui_source}" "${_client_ui_destination}")
if(NOT IS_ABSOLUTE "${_client_ui_destination_from_source}"
        AND NOT _client_ui_destination_from_source MATCHES "^\\.\\.(/|$)")
    message(FATAL_ERROR "UI destination must not be inside the UI source: ${_client_ui_destination}")
endif()
# 不自动清空输出目录：本机规则要求逐批获得文件删除许可。
# 源码中已有的文件继续更新；不再使用的旧文件由用户确认后另行处理。
function(_client_copy_ui_tree source destination)
    file(GLOB_RECURSE files LIST_DIRECTORIES FALSE RELATIVE "${source}" "${source}/*")
    foreach(relative IN LISTS files)
        if(relative MATCHES "(^|/)\\.qtcreator(/|$)" OR relative MATCHES "\\.qmlproject\\.user[^/]*$")
            continue()
        endif()
        get_filename_component(parent "${destination}/${relative}" DIRECTORY)
        file(MAKE_DIRECTORY "${parent}")
        # 按内容更新，不能只凭时间戳：同一时钟粒度内的快速编辑也必须进入运行包。
        file(COPY_FILE "${source}/${relative}" "${destination}/${relative}" ONLY_IF_DIFFERENT)
    endforeach()
endfunction()
_client_copy_ui_tree("${_client_ui_source}" "${_client_ui_destination}")
# Optional local simulator metadata belongs to its extension directory, alongside
# the UI pack. Loading failure must not prevent the normal MQTT client starting.
set(_shark_roster_source "${CLIENT_UI_SOURCE_DIR}/../extensions/shark-local-roster")
if(IS_DIRECTORY "${_shark_roster_source}")
    _client_copy_ui_tree("${_shark_roster_source}" "${CLIENT_UI_DESTINATION_DIR}/../extensions/shark-local-roster")
endif()
