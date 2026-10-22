qt_add_library(client_decision STATIC include/HttpDecision.h src/HttpDecision.cpp)
target_include_directories(client_decision PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include/robomaster>)
set_target_properties(client_decision PROPERTIES EXPORT_NAME http_decision)
target_link_libraries(client_decision PUBLIC client_plugin_sdk Qt6::Network)
target_compile_options(client_decision PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
qt_add_plugin(decision_http_plugin SHARED CLASS_NAME HttpDecisionPlugin src/HttpDecisionPlugin.cpp)
target_link_libraries(decision_http_plugin PRIVATE client_decision)
set_target_properties(decision_http_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS decision_http_plugin LIBRARY DESTINATION lib/robomaster/plugins)

qt_add_library(client_codex_decision STATIC include/CodexDecision.h src/CodexDecision.cpp
    include/CodexDecisionContract.h src/CodexDecisionContract.cpp)
target_include_directories(client_codex_decision PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include/robomaster>)
set_target_properties(client_codex_decision PROPERTIES EXPORT_NAME codex_decision)
target_link_libraries(client_codex_decision PUBLIC client_plugin_sdk Qt6::Core)
target_compile_options(client_codex_decision PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)
qt_add_plugin(decision_codex_plugin SHARED CLASS_NAME CodexDecisionPlugin src/CodexDecisionPlugin.cpp)
target_link_libraries(decision_codex_plugin PRIVATE client_codex_decision)
set_target_properties(decision_codex_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS decision_codex_plugin LIBRARY DESTINATION lib/robomaster/plugins)

# Community factories reuse the same reviewed HTTP/process adapters. Exporting
# their static implementations avoids copies of credential/parser/lifecycle code.
install(TARGETS client_decision client_codex_decision EXPORT ClientPluginSDKTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/HttpDecision.h include/CodexDecision.h include/CodexDecisionContract.h
    DESTINATION include/robomaster COMPONENT PluginSDK)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalAdviceHost.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalAdviceHost.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/ProviderConfiguration.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/ProviderConfiguration.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/DecisionConfiguration.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/DecisionConfiguration.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/DecisionContext.h" "${CMAKE_CURRENT_SOURCE_DIR}/src/DecisionContext.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/runtime")
add_custom_target(decision_model_runtime ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/runtime" "${CMAKE_BINARY_DIR}/extensions/decision/runtime")
install(DIRECTORY runtime DESTINATION share/robomaster/extensions/decision PATTERN "__pycache__" EXCLUDE)
endif()
