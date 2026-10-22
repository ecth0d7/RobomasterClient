# QML and images are external editable UI packs. No RCC registration is needed.
foreach(_entry qml/manifest.json qml/components/Main.qml qml/components/UIForm.ui.qml qml/RoboMasterUi.qmlproject)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_entry}")
        message(FATAL_ERROR "Missing UI pack entry: ${_entry}")
    endif()
endforeach()
