# Application orchestration is the only layer joining transport and telemetry.
qt_add_library(client_app STATIC
    include/AppConfig.h src/AppConfig.cpp
    include/UiPack.h src/UiPack.cpp
    include/UiViewController.h src/UiViewController.cpp
    include/ClientBackend.h src/ClientBackend.cpp src/BuiltinClientBackend.cpp
    include/OperatorCommandPolicy.h src/OperatorCommandPolicy.cpp
    include/ServiceHub.h src/ServiceHub.cpp
    include/LocalUiSettings.h src/LocalUiSettings.cpp
    include/PluginRuntime.h src/PluginRuntime.cpp
    include/VideoController.h src/VideoController.cpp
    include/OperatorActions.h src/OperatorActions.cpp
    include/OperatorPreferences.h src/OperatorPreferences.cpp
    include/RulesetCatalog.h src/RulesetCatalog.cpp
    include/SeasonConfiguration.h src/SeasonConfiguration.cpp
    include/SeasonMechanics.h src/SeasonMechanics.cpp
    include/UnavailableProtocol.h
    include/TerminalDataBus.h src/TerminalDataBus.cpp include/TerminalPluginSourceIdentity.h
)
target_include_directories(client_app PUBLIC include)
target_link_libraries(client_app PUBLIC client_plugin_sdk Qt6::Network Qt6::Qml Qt6::Gui
    PRIVATE client_core client_mqtt client_protocol client_team_contract client_terminal_team_contract client_terminal_renderer_contract)
qt_add_resources(client_app ruleset_catalog
    PREFIX "/robomaster/rulesets"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/resources"
    FILES resources/rulesets.json)
qt_add_plugin(policy_operator_plugin SHARED CLASS_NAME OperatorPolicyPlugin
    src/OperatorPolicyPlugin.cpp src/OperatorCommandPolicy.cpp)
target_include_directories(policy_operator_plugin PRIVATE include "${PROJECT_SOURCE_DIR}/core/include")
target_link_libraries(policy_operator_plugin PRIVATE client_plugin_sdk)
set_target_properties(policy_operator_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS policy_operator_plugin LIBRARY DESTINATION lib/robomaster/plugins)
