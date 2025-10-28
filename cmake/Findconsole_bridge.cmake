# Custom finder for console_bridge used by urdfdom.
# We deliberately ONLY expose the *source* include dir because console.h
# includes "./console_bridge_export.h" relatively. We put a stub there.

# Expect the superbuild to have fetched console_bridge:
#   console_bridge_SOURCE_DIR is set by FetchContent.
if(NOT DEFINED console_bridge_SOURCE_DIR)
  message(FATAL_ERROR "console_bridge_SOURCE_DIR not defined; ensure you FetchContent_MakeAvailable(console_bridge) before add_subdirectory(urdfdom)")
endif()

# Include dir (source only)
set(CONSOLE_BRIDGE_INCLUDE_DIRS "${console_bridge_SOURCE_DIR}/include")

# Simple package 'found' result.
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(console_bridge
  REQUIRED_VARS CONSOLE_BRIDGE_INCLUDE_DIRS)

# Provide an imported INTERFACE target so urdfdom's CMake can attach to it.
if(console_bridge_FOUND AND NOT TARGET console_bridge::console_bridge)
  add_library(console_bridge::console_bridge INTERFACE IMPORTED)
  set_target_properties(console_bridge::console_bridge PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${CONSOLE_BRIDGE_INCLUDE_DIRS}")
endif()


# # --- Findconsole_bridge.cmake (tolerant) -------------------------------------
# # Works with FetchContent. Exposes:
# #   CONSOLE_BRIDGE_INCLUDE_DIRS  (genex with source+build includes)
# #   CONSOLE_BRIDGE_LIBRARY       (optional; set if found)
# # Targets:
# #   console_bridge::console_bridge (IMPORTED; INTERFACE if no lib yet)
# #   console_bridge                (alias INTERFACE)

# # Where headers are
# set(_CB_BUILD_INCLUDES "${console_bridge_BINARY_DIR}/include")
# set(_CB_SRC_INCLUDES   "${console_bridge_SOURCE_DIR}/include")

# # Use both while building; 'include' after install
# set(CONSOLE_BRIDGE_INCLUDE_DIRS
#   "$<BUILD_INTERFACE:${_CB_SRC_INCLUDES};${_CB_BUILD_INCLUDES}>;$<INSTALL_INTERFACE:include>")

# # Try to locate a library now (optional — may not exist at configure time)
# set(_cb_lib_candidates
#   "${console_bridge_BINARY_DIR}/libconsole_bridge.so"
#   "${console_bridge_BINARY_DIR}/src/libconsole_bridge.so"
#   "${console_bridge_BINARY_DIR}/console_bridge/libconsole_bridge.so"
#   "${console_bridge_BINARY_DIR}/libconsole_bridge.a"
#   "${console_bridge_BINARY_DIR}/src/libconsole_bridge.a"
#   "${console_bridge_BINARY_DIR}/Release/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/Debug/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/console_bridge.lib"
#   "${console_bridge_BINARY_DIR}/lib/console_bridge.lib"
# )
# foreach(p IN LISTS _cb_lib_candidates)
#   if(EXISTS "${p}")
#     set(CONSOLE_BRIDGE_LIBRARY "${p}")
#     break()
#   endif()
# endforeach()

# include(FindPackageHandleStandardArgs)
# # Only require includes; library is optional
# find_package_handle_standard_args(console_bridge
#   REQUIRED_VARS CONSOLE_BRIDGE_INCLUDE_DIRS)

# # Build the imported target
# if(NOT TARGET console_bridge::console_bridge)
#   if(CONSOLE_BRIDGE_LIBRARY)
#     add_library(console_bridge::console_bridge UNKNOWN IMPORTED)
#     set_target_properties(console_bridge::console_bridge PROPERTIES
#       IMPORTED_LOCATION             "${CONSOLE_BRIDGE_LIBRARY}"
#       INTERFACE_INCLUDE_DIRECTORIES "${CONSOLE_BRIDGE_INCLUDE_DIRS}")
#   else()
#     # Header-only fallback so configure doesn’t fail
#     add_library(console_bridge::console_bridge INTERFACE IMPORTED)
#     set_target_properties(console_bridge::console_bridge PROPERTIES
#       INTERFACE_INCLUDE_DIRECTORIES "${CONSOLE_BRIDGE_INCLUDE_DIRS}")
#   endif()
# endif()

# # if(NOT TARGET console_bridge)
# #   add_library(console_bridge INTERFACE IMPORTED)
# #   set_target_properties(console_bridge PROPERTIES
# #     INTERFACE_LINK_LIBRARIES console_bridge::console_bridge)
# # endif()


# # After creating console_bridge::console_bridge (IMPORTED)
# # DO NOT create a separate 'console_bridge' target if one already exists.
# if(console_bridge_FOUND AND NOT TARGET console_bridge)
#   # Prefer an alias to the namespaced target (if policy allows); otherwise skip.
#   add_library(console_bridge INTERFACE IMPORTED)
#   set_target_properties(console_bridge PROPERTIES
#     INTERFACE_LINK_LIBRARIES console_bridge::console_bridge)
# endif()