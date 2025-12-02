# Findhpp-fcl.cmake
# Custom Find module so that `find_package(hpp-fcl)` works when hpp-fcl
# is built as a subproject (add_subdirectory / FetchContent) in the same tree.

# Try several possible target names that hpp-fcl might define.
set(_HPP_FCL_TARGET "")

if(TARGET hpp-fcl::hpp-fcl)
  set(_HPP_FCL_TARGET hpp-fcl::hpp-fcl)
elseif(TARGET hpp-fcl)
  set(_HPP_FCL_TARGET hpp-fcl)
elseif(TARGET hppfcl)
  set(_HPP_FCL_TARGET hppfcl)
endif()

if(NOT _HPP_FCL_TARGET)
  message(FATAL_ERROR
    "Findhpp-fcl.cmake: could not find an hpp-fcl target in the current build.\n"
    "Make sure you add hpp-fcl (via add_subdirectory or FetchContent) BEFORE "
    "calling find_package(hpp-fcl) / configuring Pinocchio.")
endif()

# Expose the standard variables used by jrl-cmakemodules / consumers:
get_target_property(HPP_FCL_INCLUDE_DIRS ${_HPP_FCL_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
if(NOT HPP_FCL_INCLUDE_DIRS)
  # Fallback: if target has no INTERFACE_INCLUDE_DIRECTORIES, try source dir
  if(DEFINED hppfcl_SOURCE_DIR)
    set(HPP_FCL_INCLUDE_DIRS "${hppfcl_SOURCE_DIR}/include")
  endif()
endif()

set(HPP_FCL_LIBRARIES ${_HPP_FCL_TARGET})

# Mark as found
set(HPP_FCL_FOUND TRUE)
# `find_package(hpp-fcl)` will look at this:
set(hpp-fcl_FOUND TRUE)  # Note: CMake auto-normalizes to HPP_FCL internally
