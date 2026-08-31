cmake_minimum_required(VERSION 3.21)
project(IconValidation LANGUAGES CXX)

find_package(Qt6 6.9 REQUIRED COMPONENTS Gui Qml)

qt_standard_project_setup()

qt_add_plugin(iconvalidationplugin
  CLASS_NAME IconValidationPlugin
  iconvalidator.cpp
  iconvalidator.hpp
  plugin.cpp
)

target_compile_features(iconvalidationplugin PRIVATE cxx_std_20)
target_link_libraries(iconvalidationplugin PRIVATE Qt6::Gui Qt6::Qml)

set_target_properties(iconvalidationplugin PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../dot_config/quickshell/IconValidation"
  OUTPUT_NAME "iconvalidationplugin"
)
