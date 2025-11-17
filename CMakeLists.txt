cmake_minimum_required(VERSION 3.26)

# Allow duplicate custom targets like "uninstall" from external deps (Eigen, urdfdom, ...)
if (CMAKE_GENERATOR MATCHES "Makefiles")
    set(ALLOW_DUPLICATE_CUSTOM_TARGETS TRUE)
endif()

project(mini_pinocchio_superbuild LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

# Our custom finders first
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(FetchContent)

# -------------------- Eigen (headers) --------------------
FetchContent_Declare(
  eigen3
  GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
  GIT_TAG        3.4.0
)
FetchContent_MakeAvailable(eigen3)
# Provide Eigen3::Eigen if not present
if(NOT TARGET Eigen3::Eigen)
  add_library(Eigen3::Eigen INTERFACE IMPORTED)
  target_include_directories(Eigen3::Eigen INTERFACE "${eigen3_SOURCE_DIR}")
endif()

# -------------------- tinyxml2 ---------------------------
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
FetchContent_Declare(
  tinyxml2
  GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
  GIT_TAG        10.0.0
)
FetchContent_MakeAvailable(tinyxml2)
# urdfdom's FindTinyXML2.cmake uses module variables:
set(TINYXML2_INCLUDE_DIR "${tinyxml2_SOURCE_DIR}" CACHE PATH "" FORCE)
if(UNIX)
  set(TINYXML2_LIBRARY "${tinyxml2_BINARY_DIR}/libtinyxml2.so" CACHE FILEPATH "" FORCE)
else()
  set(TINYXML2_LIBRARY "${tinyxml2_BINARY_DIR}/tinyxml2.lib"  CACHE FILEPATH "" FORCE)
endif()

# -------------------- console_bridge ---------------------
FetchContent_Declare(
  console_bridge
  GIT_REPOSITORY https://github.com/ros/console_bridge.git
  GIT_TAG        1.0.2
)
FetchContent_MakeAvailable(console_bridge)

# Create a stub export header in the *source* include dir because console.h
# includes "./console_bridge_export.h" relatively.
file(MAKE_DIRECTORY "${console_bridge_SOURCE_DIR}/include/console_bridge")
set(_CB_EXPORT_HDR_SRC "${console_bridge_SOURCE_DIR}/include/console_bridge/console_bridge_export.h")
if(NOT EXISTS "${_CB_EXPORT_HDR_SRC}")
  file(WRITE "${_CB_EXPORT_HDR_SRC}" "#pragma once\n#ifndef CONSOLE_BRIDGE_DLLAPI\n#  define CONSOLE_BRIDGE_DLLAPI\n#endif\n")
endif()

# A tiny shim that provides console_bridge::log for the final link if needed.
add_library(console_bridge_shim STATIC src/console_bridge_shim.cpp)
target_include_directories(console_bridge_shim PUBLIC
  "${console_bridge_SOURCE_DIR}/include")

# -------------------- urdfdom_headers -------------------
FetchContent_Declare(
  urdfdom_headers_src
  GIT_REPOSITORY https://github.com/ros/urdfdom_headers.git
  GIT_TAG        1.1.2
)
FetchContent_MakeAvailable(urdfdom_headers_src)
set(URDFDOM_HEADERS_INCLUDE_DIR
    "${urdfdom_headers_src_SOURCE_DIR}/include" CACHE PATH "" FORCE)

# -------------------- urdfdom (uses our finders) --------
FetchContent_Declare(
  urdfdom_src
  GIT_REPOSITORY https://github.com/ros/urdfdom.git
  GIT_TAG        4.0.1
)
FetchContent_Populate(urdfdom_src)
# IMPORTANT: our finders are already in CMAKE_MODULE_PATH
add_subdirectory("${urdfdom_src_SOURCE_DIR}" "${urdfdom_src_BINARY_DIR}")

# Force urdfdom libs to link our shim (transitively fixes final link)
foreach(_t IN ITEMS urdfdom_model urdfdom_sensor urdfdom_world urdfdom_model_state)
  if(TARGET ${_t})
    target_include_directories(${_t} PUBLIC
      "$<BUILD_INTERFACE:${URDFDOM_HEADERS_INCLUDE_DIR}>"
      "$<INSTALL_INTERFACE:include>")
    target_link_libraries(${_t} PRIVATE console_bridge_shim)
  endif()
endforeach()

# -------------------- Pinocchio -------------------------

set(urdfdom_VERSION "1.1.0" CACHE STRING "" FORCE)

set(BUILD_WITH_URDF_SUPPORT       ON  CACHE BOOL "" FORCE)
set(BUILD_PYTHON_INTERFACE        OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING                 OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES                OFF CACHE BOOL "" FORCE)
set(BUILD_WITH_COLLISION_SUPPORT  OFF CACHE BOOL "" FORCE)

add_subdirectory(vendor/pinocchio)

# Fix pinocchio_parsers exported include dirs (no build-abs paths)
if(TARGET pinocchio_parsers)
  set_property(TARGET pinocchio_parsers PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES
      "$<BUILD_INTERFACE:${URDFDOM_HEADERS_INCLUDE_DIR}>;$<INSTALL_INTERFACE:include>")
endif()

# Resolve pinocchio target
set(_PINOCCHIO_TARGET "")
if(TARGET pinocchio::pinocchio)
  set(_PINOCCHIO_TARGET pinocchio::pinocchio)
elseif(TARGET pinocchio)
  set(_PINOCCHIO_TARGET pinocchio)
else()
  message(FATAL_ERROR "Pinocchio target not found after add_subdirectory(vendor/pinocchio)")
endif()

# -------------------- App -------------------------------
add_executable(mini src/main.cpp)
target_link_libraries(mini PRIVATE
  "${_PINOCCHIO_TARGET}"
  Eigen3::Eigen
  tinyxml2
  urdfdom_model urdfdom_sensor urdfdom_world
  console_bridge_shim
)

