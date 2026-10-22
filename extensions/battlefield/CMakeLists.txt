qt_add_plugin(battlefield_process_plugin SHARED CLASS_NAME BattlefieldPlugin src/BattlefieldPlugin.cpp)
target_link_libraries(battlefield_process_plugin PRIVATE client_plugin_sdk Qt6::Core)
target_compile_definitions(battlefield_process_plugin PRIVATE BATTLEFIELD_SOURCE_RUNTIME="${CMAKE_CURRENT_SOURCE_DIR}/runtime/runtime.py")
set_target_properties(battlefield_process_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
target_sources(client_app PRIVATE include/BattlefieldHost.h src/BattlefieldHost.cpp)
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_definitions(client_app PUBLIC CLIENT_HAS_BATTLEFIELD=1)
add_custom_target(battlefield_runtime ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/runtime" "${CMAKE_BINARY_DIR}/extensions/battlefield/runtime"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/config" "${CMAKE_BINARY_DIR}/extensions/battlefield/config")
install(TARGETS battlefield_process_plugin LIBRARY DESTINATION lib/robomaster/plugins)
install(DIRECTORY runtime config DESTINATION share/robomaster/extensions/battlefield PATTERN "__pycache__" EXCLUDE)

# Independent feature runtime; absence is handled by the battlefield host.
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../hero-projectile/runtime")
add_custom_target(hero_projectile_runtime ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/../hero-projectile" "${CMAKE_BINARY_DIR}/extensions/hero-projectile")
add_dependencies(battlefield_runtime hero_projectile_runtime)
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../hero-projectile"
    DESTINATION share/robomaster/extensions PATTERN "__pycache__" EXCLUDE)
endif()

if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../yolo-vision/runtime")
add_custom_target(yolo_vision_runtime ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/../yolo-vision" "${CMAKE_BINARY_DIR}/extensions/yolo-vision")
add_dependencies(battlefield_runtime yolo_vision_runtime)
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../yolo-vision"
    DESTINATION share/robomaster/extensions PATTERN "__pycache__" EXCLUDE)
endif()
