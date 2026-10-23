cmake_minimum_required(VERSION 3.21)
project(IwdNetworking LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS Core DBus Network Qml)

qt_standard_project_setup()

qt_add_qml_module(iwdplugin
  URI Iwd
  VERSION 0.1
  PLUGIN_TARGET iwdplugin
  OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../dot_config/quickshell/Iwd"
  SOURCES
    src/iwdnetworking.cpp
    src/iwdnetworking.h
)

target_compile_features(iwdplugin PRIVATE cxx_std_20)
target_include_directories(iwdplugin PRIVATE src)
target_link_libraries(iwdplugin PRIVATE Qt6::Core Qt6::DBus Qt6::Network Qt6::Qml)
