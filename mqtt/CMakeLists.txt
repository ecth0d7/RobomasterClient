# Raw topic/byte transport. Knows no RoboMaster fields.
qt_add_library(client_mqtt STATIC include/MqttTransport.h src/MqttTransport.cpp)
target_include_directories(client_mqtt PUBLIC include)
target_link_libraries(client_mqtt PUBLIC client_plugin_sdk PRIVATE PkgConfig::MOSQUITTO)
qt_add_plugin(mqtt_mosquitto_plugin SHARED CLASS_NAME MosquittoPlugin src/MosquittoPlugin.cpp)
target_link_libraries(mqtt_mosquitto_plugin PRIVATE client_mqtt)
set_target_properties(mqtt_mosquitto_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS mqtt_mosquitto_plugin LIBRARY DESTINATION lib/robomaster/plugins)
