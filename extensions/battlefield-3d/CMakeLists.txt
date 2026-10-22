# QML-only optional renderer: do not link QtQuick3D into the core executable.
option(ROBOMASTER_PREPARE_3D_ASSETS "Condition the field with the matching Qt SDK when Balsam is available" ON)
set(_prepare_commands)
set(_field_source "${CMAKE_CURRENT_SOURCE_DIR}/assets/field-2027-batched.glb")
set(_prepare_script "${PROJECT_SOURCE_DIR}/cmake/PrepareFieldAsset.cmake")
if(ROBOMASTER_PREPARE_3D_ASSETS AND NOT CMAKE_CROSSCOMPILING)
    get_filename_component(_qt_sdk "${Qt6Core_DIR}/../../.." ABSOLUTE)
    # A cached find_program result could point to an SDK selected by an earlier configure.
    set(_field_balsam "${_qt_sdk}/bin/balsam${CMAKE_EXECUTABLE_SUFFIX}")
    if(EXISTS "${_field_balsam}" AND NOT IS_DIRECTORY "${_field_balsam}")
        # Cache identity includes source bytes, SDK and conditioning logic; never clean old bundles.
        file(SHA256 "${_field_source}" _source_hash)
        file(SHA256 "${_prepare_script}" _preparer_hash)
        string(SHA256 _bundle_hash "${_source_hash};${Qt6Core_VERSION};${_preparer_hash}")
        string(SUBSTRING "${_bundle_hash}" 0 16 _bundle_key)
        set(_prepared_bundle "${CMAKE_BINARY_DIR}/extensions/battlefield-3d/assets/prepared/${Qt6Core_VERSION}-${_bundle_key}")
        set(_prepared_catalog "${CMAKE_BINARY_DIR}/extensions/battlefield-3d/qml/PreparedAssetInfo.qml")
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_field_source}" "${_prepare_script}")
        list(APPEND _prepare_commands COMMAND "${CMAKE_COMMAND}"
            "-DSOURCE=${_field_source}" "-DSOURCE_HASH=${_source_hash}" "-DBALSAM=${_field_balsam}"
            "-DBUNDLE=${_prepared_bundle}" "-DCATALOG=${_prepared_catalog}" "-DQT_VERSION=${Qt6Core_VERSION}"
            -P "${_prepare_script}")
        message(STATUS "Optional field conditioning enabled with Qt ${Qt6Core_VERSION} Balsam")
    else()
        message(STATUS "Qt SDK Balsam unavailable; optional 3D field retains GLB loading")
    endif()
endif()
add_custom_target(battlefield_3d_assets ALL
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/extensions/battlefield-3d"
    ${_prepare_commands})
install(DIRECTORY qml assets DESTINATION share/robomaster/extensions/battlefield-3d)
install(FILES manifest.json README.md DESTINATION share/robomaster/extensions/battlefield-3d OPTIONAL)
if(_prepared_bundle)
    install(DIRECTORY "${_prepared_bundle}/" DESTINATION "share/robomaster/extensions/battlefield-3d/assets/prepared/${Qt6Core_VERSION}-${_bundle_key}" OPTIONAL
        FILES_MATCHING PATTERN "*.qml" PATTERN "*.mesh" PATTERN "*.png" PATTERN "*.jpg" PATTERN "*.jpeg" PATTERN "*.ktx")
    install(FILES "${_prepared_catalog}" DESTINATION share/robomaster/extensions/battlefield-3d/qml OPTIONAL)
endif()
