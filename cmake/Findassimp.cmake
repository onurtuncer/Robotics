# cmake/Findassimp.cmake
# Custom find-module to bridge our FetchContent-built Assimp
# with consumers like hpp-fcl that call `find_package(assimp)`.

# 1) If Assimp was already added as a target (e.g. via FetchContent),
#    just expose it as a "package".
if(TARGET assimp::assimp OR TARGET assimp)
  if(TARGET assimp::assimp)
    set(_assimp_target assimp::assimp)
  else()
    set(_assimp_target assimp)
  endif()

  # Try to get include dirs from the target if available
  get_target_property(_assimp_inc_dirs ${_assimp_target} INTERFACE_INCLUDE_DIRECTORIES)

  if(NOT _assimp_inc_dirs)
    # Fallback: use the usual layout of the FetchContent source dir
    if(DEFINED assimp_SOURCE_DIR)
      set(_assimp_inc_dirs "${assimp_SOURCE_DIR}/include")
    endif()
  endif()

  set(assimp_INCLUDE_DIRS "${_assimp_inc_dirs}")
  set(assimp_LIBRARIES   ${_assimp_target})
  set(assimp_FOUND       TRUE)

  # Be nice and also export uppercase-style vars some projects expect
  set(ASSIMP_INCLUDE_DIRS "${assimp_INCLUDE_DIRS}")
  set(ASSIMP_LIBRARIES   "${assimp_LIBRARIES}")
  set(ASSIMP_FOUND       TRUE)

  return()
endif()

# 2) Fallback: try config mode (system- or externally-installed Assimp)
find_package(assimp CONFIG QUIET)

if(TARGET assimp::assimp)
  set(assimp_LIBRARIES assimp::assimp)
  get_target_property(assimp_INCLUDE_DIRS assimp::assimp INTERFACE_INCLUDE_DIRECTORIES)

  set(ASSIMP_LIBRARIES   "${assimp_LIBRARIES}")
  set(ASSIMP_INCLUDE_DIRS "${assimp_INCLUDE_DIRS}")

  set(assimp_FOUND TRUE)
  set(ASSIMP_FOUND TRUE)
  return()
endif()

# 3) If we reach here, we really couldn’t find it.
set(assimp_FOUND FALSE)
set(ASSIMP_FOUND FALSE)

message(FATAL_ERROR
  "Findassimp.cmake: could not locate Assimp.\n"
  "If you are using FetchContent(assimp), make sure it is called before "
  "hpp-fcl is configured.")
