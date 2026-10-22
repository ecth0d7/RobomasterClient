# Input emits values; the application decides how to send them.
qt_add_library(client_input STATIC
    include/InputController.h src/InputController.cpp include/InputPolicy.h)
target_include_directories(client_input PUBLIC include)
target_link_libraries(client_input PUBLIC client_plugin_sdk Qt6::Core Qt6::Gui Qt6::Quick)
qt_add_plugin(input_qt_plugin SHARED CLASS_NAME QtInputPlugin src/QtInputPlugin.cpp)
target_link_libraries(input_qt_plugin PRIVATE client_input)
set_target_properties(input_qt_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS input_qt_plugin LIBRARY DESTINATION lib/robomaster/plugins)
