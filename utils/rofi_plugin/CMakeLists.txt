cmake_minimum_required(VERSION 3.21)
project(RofiPlugin LANGUAGES CXX)

set(CMAKE_SKIP_RPATH TRUE)
# Also prevent the Nix compiler wrapper from adding store paths.
set(CMAKE_CXX_LINKER_LAUNCHER "${CMAKE_COMMAND};-E;env;--unset=NIX_LDFLAGS;NIX_DONT_SET_RPATH=1")
add_link_options("LINKER:--as-needed")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(ROFI REQUIRED IMPORTED_TARGET rofi>=2.0 glib-2.0 cairo)

add_library(tabmemory MODULE src/tabmemory.cpp)
target_compile_features(tabmemory PRIVATE cxx_std_20)
target_link_libraries(tabmemory PRIVATE PkgConfig::ROFI)
set_target_properties(tabmemory PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../dot_config/rofi/plugins"
)
