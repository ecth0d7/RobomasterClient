qt_add_library(client_speech STATIC include/QueuedSpeech.h src/QueuedSpeech.cpp
    include/EspeakSpeech.h src/EspeakSpeech.cpp include/HttpSpeech.h src/HttpSpeech.cpp
    include/WavAudio.h src/WavAudio.cpp)
target_include_directories(client_speech PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
    "$<INSTALL_INTERFACE:include/robomaster>")
target_link_libraries(client_speech PUBLIC client_plugin_sdk Qt6::Network)
set_target_properties(client_speech PROPERTIES EXPORT_NAME speech)
install(TARGETS client_speech EXPORT ClientPluginSDKTargets
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT PluginSDK)
install(FILES include/QueuedSpeech.h include/EspeakSpeech.h include/HttpSpeech.h include/WavAudio.h
    DESTINATION include/robomaster COMPONENT PluginSDK)
target_compile_options(client_speech PRIVATE $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall;-Wextra;-Wpedantic>)

qt_add_plugin(speech_espeak_plugin SHARED CLASS_NAME EspeakSpeechPlugin src/EspeakSpeechPlugin.cpp)
target_link_libraries(speech_espeak_plugin PRIVATE client_speech)
set_target_properties(speech_espeak_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS speech_espeak_plugin LIBRARY DESTINATION lib/robomaster/plugins)
qt_add_plugin(speech_http_plugin SHARED CLASS_NAME HttpSpeechPlugin src/HttpSpeechPlugin.cpp)
target_link_libraries(speech_http_plugin PRIVATE client_speech)
set_target_properties(speech_http_plugin PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins")
install(TARGETS speech_http_plugin LIBRARY DESTINATION lib/robomaster/plugins)

target_sources(client_app PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalSpeechHost.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalSpeechHost.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/include/TerminalVoiceCoordinator.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/TerminalVoiceCoordinator.cpp")
target_include_directories(client_app PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(client_app PRIVATE client_plugin_packages)
if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/runtime")
add_custom_target(situation_voice_runtime ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/runtime" "${CMAKE_BINARY_DIR}/extensions/speech/runtime")
install(DIRECTORY runtime DESTINATION share/robomaster/extensions/speech PATTERN "__pycache__" EXCLUDE)
endif()
