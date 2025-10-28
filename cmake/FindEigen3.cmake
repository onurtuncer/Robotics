# Minimal Eigen3 finder (module-mode) for header-only usage
# Expects the superbuild to have set eigen3_SOURCE_DIR; but we also try common hints.

if(NOT DEFINED EIGEN3_INCLUDE_DIR)
  # First, prefer a hint injected by the superbuild via CMake cache (optional)
  if(DEFINED ENV{EIGEN3_INCLUDE_DIR})
    set(EIGEN3_INCLUDE_DIR "$ENV{EIGEN3_INCLUDE_DIR}")
  elseif(EXISTS "${CMAKE_SOURCE_DIR}/_deps/eigen3-src/Eigen")
    set(EIGEN3_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/_deps/eigen3-src")
  elseif(EXISTS "${CMAKE_BINARY_DIR}/_deps/eigen3-src/Eigen")
    set(EIGEN3_INCLUDE_DIR "${CMAKE_BINARY_DIR}/_deps/eigen3-src")
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Eigen3 DEFAULT_MSG EIGEN3_INCLUDE_DIR)

if(Eigen3_FOUND AND NOT TARGET Eigen3::Eigen)
  add_library(Eigen3::Eigen INTERFACE IMPORTED)
  set_target_properties(Eigen3::Eigen PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${EIGEN3_INCLUDE_DIR}")
endif()
