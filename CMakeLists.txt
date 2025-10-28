cmake_minimum_required(VERSION 3.22)
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
FetchContent_Populate(eigen3)
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
FetchContent_Populate(urdfdom_headers_src)
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


# cmake_minimum_required(VERSION 3.22)
# project(mini_pinocchio_superbuild LANGUAGES CXX)

# set(CMAKE_CXX_STANDARD 17)
# set(CMAKE_CXX_STANDARD_REQUIRED ON)
# set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# # Avoid test/gtests targets from 3rd-parties
# set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

# # Our custom find-modules
# list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# include(FetchContent)

# # -------------------- Eigen (header-only, no subproject) --------------------
# FetchContent_Declare(
#   eigen3
#   GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
#   GIT_TAG        3.4.0
# )
# FetchContent_Populate(eigen3) # downloads/unpacks only

# # Help CONFIG-mode consumers; but we’ll also provide module-mode in cmake/FindEigen3.cmake
# set(Eigen3_DIR "${eigen3_SOURCE_DIR}/cmake" CACHE PATH "" FORCE)
# list(PREPEND CMAKE_PREFIX_PATH "${eigen3_SOURCE_DIR}" "${eigen3_SOURCE_DIR}/cmake")
# find_package(Eigen3 QUIET) # will be satisfied by our module if CONFIG isn’t there

# if(NOT TARGET Eigen3::Eigen)
#   add_library(Eigen3::Eigen INTERFACE IMPORTED)
#   target_include_directories(Eigen3::Eigen INTERFACE "${eigen3_SOURCE_DIR}")
# endif()

# # -------------------- TinyXML2 (build it) -----------------------------------
# set(TINYXML2_GIT_TAG "10.0.0" CACHE STRING "Git tag for tinyxml2")
# set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)

# FetchContent_Declare(
#   tinyxml2
#   GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
#   GIT_TAG        ${TINYXML2_GIT_TAG}
# )
# FetchContent_MakeAvailable(tinyxml2)

# # Make urdfdom’s FindTinyXML2.cmake happy (module-mode vars)
# set(TINYXML2_INCLUDE_DIR "${tinyxml2_SOURCE_DIR}" CACHE PATH "" FORCE)
# # Reasonable first-config guess for the library; urdfdom only checks that it’s set
# if(UNIX)
#   set(TINYXML2_LIBRARY "${tinyxml2_BINARY_DIR}/libtinyxml2.so" CACHE FILEPATH "" FORCE)
# else()
#   set(TINYXML2_LIBRARY "${tinyxml2_BINARY_DIR}/tinyxml2.lib"  CACHE FILEPATH "" FORCE)
# endif()
# # Also expose config-mode, just in case
# list(PREPEND CMAKE_PREFIX_PATH "${tinyxml2_BINARY_DIR}")
# set(TinyXML2_DIR "${tinyxml2_BINARY_DIR}" CACHE PATH "" FORCE)

# # -------------------- console_bridge (build it) -----------------------------
# set(CONSOLE_BRIDGE_GIT_TAG "1.0.2" CACHE STRING "Git tag for console_bridge")
# FetchContent_Declare(
#   console_bridge
#   GIT_REPOSITORY https://github.com/ros/console_bridge.git
#   GIT_TAG        ${CONSOLE_BRIDGE_GIT_TAG}
# )
# FetchContent_MakeAvailable(console_bridge)

# # Ensure source include has the export header (console.h does a relative include)
# set(_CB_SRC_INCLUDE_DIR "${console_bridge_SOURCE_DIR}/include/console_bridge")
# file(MAKE_DIRECTORY "${_CB_SRC_INCLUDE_DIR}")
# set(_CB_EXPORT_HDR_SRC "${_CB_SRC_INCLUDE_DIR}/console_bridge_export.h")
# if(NOT EXISTS "${_CB_EXPORT_HDR_SRC}")
#   file(WRITE "${_CB_EXPORT_HDR_SRC}" [=[
# #pragma once
# #ifndef CONSOLE_BRIDGE_DLLAPI
# #  define CONSOLE_BRIDGE_DLLAPI
# #endif
# ]=])
# endif()


# # Try to locate a compiled console_bridge library (optional)
# set(_CB_LIB "")
# set(_cb_candidates
#   "${console_bridge_BINARY_DIR}/libconsole_bridge.so"
#   "${console_bridge_BINARY_DIR}/src/libconsole_bridge.so"
#   "${console_bridge_BINARY_DIR}/libconsole_bridge.a"
#   "${console_bridge_BINARY_DIR}/Release/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/Debug/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/lib/console_bridge.lib"
# )
# foreach(_p IN LISTS _cb_candidates)
#   if(EXISTS "${_p}")
#     set(_CB_LIB "${_p}")
#     break()
#   endif()
# endforeach()

# # Decide which target to link everywhere
# set(CONSOLE_BRIDGE_TARGET "")

# if(TARGET console_bridge::console_bridge)
#   # Prefer upstream namespaced target if provided
#   set(CONSOLE_BRIDGE_TARGET console_bridge::console_bridge)

# elseif(TARGET console_bridge)
#   # Some versions export an un-namespaced compiled target
#   set(CONSOLE_BRIDGE_TARGET console_bridge)

# elseif(_CB_LIB)
#   # No exported target, but a library exists: import it (include ONLY source include!)
#   add_library(console_bridge::console_bridge UNKNOWN IMPORTED)
#   set_target_properties(console_bridge::console_bridge PROPERTIES
#     IMPORTED_LOCATION "${_CB_LIB}"
#     INTERFACE_INCLUDE_DIRECTORIES
#       "$<BUILD_INTERFACE:${console_bridge_SOURCE_DIR}/include>;$<INSTALL_INTERFACE:include>")
#   set(CONSOLE_BRIDGE_TARGET console_bridge::console_bridge)

# else()
#   # Last resort: tiny shim that implements console_bridge::log
#   add_library(console_bridge_shim STATIC src/console_bridge_shim.cpp)
#   target_include_directories(console_bridge_shim PUBLIC
#     "${console_bridge_SOURCE_DIR}/include")
#   set(CONSOLE_BRIDGE_TARGET console_bridge_shim)
# endif()

# if(NOT CONSOLE_BRIDGE_TARGET)
#   message(FATAL_ERROR "Failed to resolve a console_bridge target")
# endif()



# # -------------------- urdfdom_headers (headers only; no subproject!) --------
# set(URDFDOM_HEADERS_GIT_TAG "1.1.2" CACHE STRING "Git tag for urdfdom_headers")
# FetchContent_Declare(
#   urdfdom_headers_src
#   GIT_REPOSITORY https://github.com/ros/urdfdom_headers.git
#   GIT_TAG        ${URDFDOM_HEADERS_GIT_TAG}
# )
# FetchContent_Populate(urdfdom_headers_src) # we DO NOT add_subdirectory => no 'uninstall' target
# # # Tell our Findurdfdom_headers.cmake where the headers are
# # set(URDFDOM_HEADERS_INCLUDE_DIR "${urdfdom_headers_src_SOURCE_DIR}" CACHE PATH "" FORCE)

# # AFTER
# set(URDFDOM_HEADERS_INCLUDE_DIR
#     "${urdfdom_headers_src_SOURCE_DIR}/include"
#     CACHE PATH "" FORCE)
# # -------------------- urdfdom (build it; will call find_package on the above) ---
# set(URDFDOM_GIT_TAG "4.0.1" CACHE STRING "Git tag for urdfdom")
# FetchContent_Declare(
#   urdfdom_src
#   GIT_REPOSITORY https://github.com/ros/urdfdom.git
#   GIT_TAG        ${URDFDOM_GIT_TAG}
# )
# # Use add_subdirectory so that resulting targets are visible in this build
# FetchContent_Populate(urdfdom_src)
# add_subdirectory("${urdfdom_src_SOURCE_DIR}" "${urdfdom_src_BINARY_DIR}")

# foreach(_t IN ITEMS urdfdom_model urdfdom_sensor urdfdom_world)
#   if(TARGET ${_t})
#     target_include_directories(${_t} PUBLIC
#       "$<BUILD_INTERFACE:${URDFDOM_HEADERS_INCLUDE_DIR}>"
#       "$<INSTALL_INTERFACE:include>")
#   endif()
# endforeach()

# # Provide a friendly alias target if consumers look for urdfdom::urdfdom
# if(TARGET urdfdom_model AND NOT TARGET urdfdom::urdfdom)
#   add_library(urdfdom::urdfdom INTERFACE IMPORTED)
#   set_target_properties(urdfdom::urdfdom PROPERTIES
#     INTERFACE_LINK_LIBRARIES "urdfdom_model;urdfdom_sensor;urdfdom_world")
# endif()

# # Make urdfdom shared libs link to console_bridge transitively
# foreach(_t IN ITEMS urdfdom_model urdfdom_sensor urdfdom_world)
#   if(TARGET ${_t})
#     target_link_libraries(${_t} PUBLIC "${CONSOLE_BRIDGE_TARGET}")
#   endif()
# endforeach()

# # -------------------- Pinocchio (in-tree) -----------------------------------
# set(BUILD_WITH_URDF_SUPPORT       ON  CACHE BOOL "" FORCE)
# set(BUILD_PYTHON_INTERFACE        OFF CACHE BOOL "" FORCE)
# set(BUILD_TESTING                 OFF CACHE BOOL "" FORCE)
# set(BUILD_EXAMPLES                OFF CACHE BOOL "" FORCE)
# set(BUILD_WITH_COLLISION_SUPPORT  OFF CACHE BOOL "" FORCE)

# add_subdirectory(vendor/pinocchio)

# # Ensure exported includes don’t point to a build-tree absolute path
# if(TARGET pinocchio_parsers)
#   # Use already-fetched urdfdom_headers source dir for BUILD side,
#   # and a normal 'include' path for the INSTALL side.
#   set(_URDFHDRS_DIR "${URDFDOM_HEADERS_INCLUDE_DIR}")  # e.g. .../_deps/urdfdom_headers_src-src
#   set_property(TARGET pinocchio_parsers PROPERTY
#     INTERFACE_INCLUDE_DIRECTORIES
#       "$<BUILD_INTERFACE:${_URDFHDRS_DIR}>;$<INSTALL_INTERFACE:include>")
# endif()

# # Resolve pinocchio target name
# set(_PINOCCHIO_TARGET "")
# if(TARGET pinocchio::pinocchio)
#   set(_PINOCCHIO_TARGET pinocchio::pinocchio)
# elseif(TARGET pinocchio)
#   set(_PINOCCHIO_TARGET pinocchio)
# else()
#   message(FATAL_ERROR "Pinocchio target not found after add_subdirectory(vendor/pinocchio)")
# endif()

# # -------------------- Your app ------------------------------------------------
# add_executable(mini src/main.cpp)
# target_link_libraries(mini
#   PRIVATE
#     "${_PINOCCHIO_TARGET}"
#     Eigen3::Eigen
#     tinyxml2
#     urdfdom_model
#     urdfdom_sensor
#     urdfdom_world
#     "${CONSOLE_BRIDGE_TARGET}"
# )

