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

