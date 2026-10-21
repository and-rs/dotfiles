cmake_minimum_required(VERSION 3.21)
project(NiriPlugin LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS Core Network Qml)

qt_standard_project_setup()

qt_add_qml_module(niriplugin
  URI Niri
  VERSION 0.1
  PLUGIN_TARGET niriplugin
  OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../dot_config/quickshell/Niri"
  SOURCES
    src/niri.cpp
    src/niri.h
    src/niriipc.cpp
    src/niriipc.h
    src/window.cpp
    src/window.h
    src/windowmodel.cpp
    src/windowmodel.h
    src/workspacemodel.cpp
    src/workspacemodel.h
)

target_compile_features(niriplugin PRIVATE cxx_std_20)
target_include_directories(niriplugin PRIVATE src)
target_link_libraries(niriplugin PRIVATE Qt6::Core Qt6::Network Qt6::Qml)
