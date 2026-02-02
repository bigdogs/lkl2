# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_lkl2")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")

# For this local project, we know the rust directory is at the project root.
# In a Flutter Windows build, CMAKE_SOURCE_DIR points to <project_root>/windows,
# so we go one level up to reach <project_root>/rust/liblkl2.
set(RUST_MANIFEST_DIR "${CMAKE_SOURCE_DIR}/../rust/liblkl2")
get_filename_component(RUST_MANIFEST_DIR "${RUST_MANIFEST_DIR}" REALPATH)

apply_cargokit(${PROJECT_NAME} "${RUST_MANIFEST_DIR}" liblkl2 "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_lkl2_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
