# Protocol schema, conversion and validation. No transport or UI dependencies.
if(Protobuf_VERSION VERSION_LESS 3.15)
    set(PROTO_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/robomaster_custom_client.pb.cc")
    set(PROTO_HEADERS "${CMAKE_CURRENT_BINARY_DIR}/robomaster_custom_client.pb.h")
    add_custom_command(OUTPUT ${PROTO_SOURCES} ${PROTO_HEADERS}
        COMMAND "${Protobuf_PROTOC_EXECUTABLE}" --experimental_allow_proto3_optional
            --cpp_out=${CMAKE_CURRENT_BINARY_DIR} --proto_path=${CMAKE_CURRENT_SOURCE_DIR}
            ${CMAKE_CURRENT_SOURCE_DIR}/robomaster_custom_client.proto
        DEPENDS robomaster_custom_client.proto VERBATIM)
else()
    protobuf_generate_cpp(PROTO_SOURCES PROTO_HEADERS robomaster_custom_client.proto)
endif()
qt_add_library(client_protocol SHARED
    include/ProtocolCodec.h src/ProtocolCodec.cpp ${PROTO_SOURCES} ${PROTO_HEADERS})
target_include_directories(client_protocol PUBLIC include "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(client_protocol PUBLIC Qt6::Core protobuf::libprotobuf)
set_target_properties(client_protocol PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib" WINDOWS_EXPORT_ALL_SYMBOLS ON)
install(TARGETS client_protocol LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} RUNTIME DESTINATION bin)
qt_add_plugin(protocol_rm2026_plugin SHARED CLASS_NAME ProtocolPlugin src/ProtocolPlugin.cpp)
target_link_libraries(protocol_rm2026_plugin PRIVATE client_protocol client_plugin_sdk)
set_target_properties(protocol_rm2026_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS protocol_rm2026_plugin LIBRARY DESTINATION lib/robomaster/plugins)

# Transport-independent local development codec. No protobuf schema/version or
# official message mapping is implied by this project-defined JSON contract.
qt_add_library(client_terminal_local_codec STATIC include/TerminalLocalCodec.h src/TerminalLocalCodec.cpp)
target_include_directories(client_terminal_local_codec PUBLIC include)
target_link_libraries(client_terminal_local_codec PUBLIC client_plugin_sdk)
qt_add_plugin(protocol_terminal_local_plugin SHARED CLASS_NAME TerminalLocalPlugin src/TerminalLocalPlugin.cpp)
target_link_libraries(protocol_terminal_local_plugin PRIVATE client_terminal_local_codec)
set_target_properties(protocol_terminal_local_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS protocol_terminal_local_plugin LIBRARY DESTINATION lib/robomaster/plugins)
