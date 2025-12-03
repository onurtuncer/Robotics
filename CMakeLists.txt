cmake_minimum_required(VERSION 3.26)
# Workaround for jrl-cmakemodules expecting this variable:
set(CMAKE_MINIMUM_REQUIRED_VERSION 3.26)

project(mini_pinocchio_superbuild LANGUAGES CXX)

# --- HACK 1: jrl-cmakemodules root paketleme hatasını sustur ---
# Bazı jrl makroları PROJ_ADI Targets isimli bir export set bekliyor.
# Aşağıda boş bir hedefi bu export set'e ekleyiyoruz

add_library(mini_superbuild_dummy_target INTERFACE)
install(
  TARGETS mini_superbuild_dummy_target
  EXPORT mini_pinocchio_superbuildTargets
)

# --- Compatibility for old WRITE_BASIC_CONFIG_VERSION_FILE() behavior ---
# jrl-cmakemodules calls write_basic_package_version_file() without VERSION.
# New CMake requires VERSION unless this policy is set to OLD.
if (POLICY CMP0164)
  cmake_policy(SET CMP0164 OLD)
endif()

# Allow duplicate custom targets like "uninstall" from external deps (Eigen, urdfdom, ...)
if (CMAKE_GENERATOR MATCHES "Makefiles")
    set(ALLOW_DUPLICATE_CUSTOM_TARGETS TRUE)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

# Our custom finders first
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# -------------------------------------------------------------------------
# Force ZLIB to use shared on Linux so hpp-fcl shared lib doesn't link
# against non-PIC /usr/lib/.../libz.a
# -------------------------------------------------------------------------
if(UNIX AND NOT APPLE)
  # We may already have bad values in the cache from previous runs
  unset(ZLIB_LIBRARY CACHE)
  unset(ZLIB_LIBRARY_RELEASE CACHE)
  unset(ZLIB_LIBRARY_DEBUG CACHE)
  unset(ZLIB_LIBRARIES CACHE)
  set(ZLIB_USE_STATIC_LIBS OFF CACHE BOOL "Use shared ZLIB" FORCE)

  find_package(ZLIB REQUIRED)

  if (TARGET ZLIB::ZLIB)
    # Make subsequent find_package(ZLIB) and users (Assimp/hpp-fcl)
    # reuse the imported target instead of hardcoded .a paths.
    set(ZLIB_LIBRARIES ZLIB::ZLIB CACHE STRING "" FORCE)
  else()
    # Fallback if the module is old and doesn't create a target
    set(ZLIB_LIBRARIES "-lz" CACHE STRING "" FORCE)
  endif()
endif()

include(FetchContent)

# -------------------- Eigen (headers) --------------------
FetchContent_Declare(
  eigen3
  GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
  GIT_TAG        3.4.0
)

# Eigen options (in case Eigen is fetched by something in your tree)
set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)

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

FetchContent_GetProperties(console_bridge)
if(NOT console_bridge_POPULATED)
  FetchContent_Populate(console_bridge)

  # --- PATCH: bump cmake_minimum_required in console_bridge CMakeLists ---
  file(READ "${console_bridge_SOURCE_DIR}/CMakeLists.txt" _cb_cmakelists)

  string(REGEX REPLACE
    "cmake_minimum_required\\([^)]*\\)"
    "cmake_minimum_required(VERSION 3.10)"
    _cb_cmakelists "${_cb_cmakelists}"
  )

  file(WRITE "${console_bridge_SOURCE_DIR}/CMakeLists.txt" "${_cb_cmakelists}")

  # Now add console_bridge as a normal subdir
  add_subdirectory("${console_bridge_SOURCE_DIR}" "${console_bridge_BINARY_DIR}")
endif()

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
  GIT_REPOSITORY https://github.com/onurtuncer/urdfdom_headers.git
  GIT_TAG        rolling
)
FetchContent_MakeAvailable(urdfdom_headers_src)
set(URDFDOM_HEADERS_INCLUDE_DIR
    "${urdfdom_headers_src_SOURCE_DIR}/include" CACHE PATH "" FORCE)

# -------------------- urdfdom (uses our finders) --------
FetchContent_Declare(
  urdfdom_src
  GIT_REPOSITORY https://github.com/onurtuncer/urdfdom.git
  GIT_TAG        rolling
)
FetchContent_MakeAvailable(urdfdom_src)
# IMPORTANT: our finders are already in CMAKE_MODULE_PATH
#add_subdirectory("${urdfdom_src_SOURCE_DIR}" "${urdfdom_src_BINARY_DIR}")

# Force urdfdom libs to link our shim (transitively fixes final link)
foreach(_t IN ITEMS urdfdom_model urdfdom_sensor urdfdom_world urdfdom_model_state)
  if(TARGET ${_t})
    target_include_directories(${_t} PUBLIC
      "$<BUILD_INTERFACE:${URDFDOM_HEADERS_INCLUDE_DIR}>"
      "$<INSTALL_INTERFACE:include>")
    target_link_libraries(${_t} PRIVATE console_bridge_shim)
  endif()
endforeach()

# -------------------- ZLIB shim (for Assimp) --------------------
find_package(ZLIB REQUIRED)

# Make sure there's an imported ZLIB::ZLIB target
if(NOT TARGET ZLIB::ZLIB)
  add_library(ZLIB::ZLIB UNKNOWN IMPORTED)
  set_target_properties(ZLIB::ZLIB PROPERTIES
    IMPORTED_LOCATION             "${ZLIB_LIBRARIES}"
    INTERFACE_INCLUDE_DIRECTORIES "${ZLIB_INCLUDE_DIRS}"
  )
endif()

# Some Assimp configs expect a target named "zlib"
if(NOT TARGET zlib)
  add_library(zlib INTERFACE)
  target_link_libraries(zlib INTERFACE ZLIB::ZLIB)
endif()

# Others expect a target named "zlibstatic"
if(NOT TARGET zlibstatic)
  add_library(zlibstatic INTERFACE)
  target_link_libraries(zlibstatic INTERFACE ZLIB::ZLIB)
endif()


# -------- Assimp (mesh importer) --------
# Tell Assimp to use system Zlib and not build contrib/zlib
set(ASSIMP_BUILD_ZLIB          OFF CACHE BOOL "" FORCE)
set(ASSIMP_BUILD_ZLIB_INTERNAL OFF CACHE BOOL "" FORCE)

set(ASSIMP_TAG v5.4.3)
FetchContent_Declare(assimp
  GIT_REPOSITORY https://github.com/assimp/assimp.git
  GIT_TAG        ${ASSIMP_TAG}
)
# Trim Assimp to speed up CI/builds
set(ASSIMP_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(ASSIMP_BUILD_ASSIMP_TOOLS OFF CACHE BOOL "" FORCE)
set(ASSIMP_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(ASSIMP_NO_EXPORT ON CACHE BOOL "" FORCE)
set(ASSIMP_INSTALL ON CACHE BOOL "" FORCE)      # provides AssimpConfig.cmake in build tree
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)  # static simplifies rpaths for superbuilds
FetchContent_MakeAvailable(assimp)

# Make Assimp discoverable by downstream find_package()
# (Assimp generates AssimpConfig.cmake into its *binary* dir)
list(APPEND CMAKE_PREFIX_PATH "${assimp_BINARY_DIR}")

# -------- libccd (hpp-fcl dependency) --------
FetchContent_Declare(
  libccd
  GIT_REPOSITORY https://github.com/danfis/libccd.git
  GIT_TAG        v2.1
)

# Libccd options
set(ENABLE_DOUBLE_PRECISION ON  CACHE BOOL "" FORCE)
set(ENABLE_SSE              OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS       OFF CACHE BOOL "" FORCE)

FetchContent_GetProperties(libccd)
if(NOT libccd_POPULATED)
  FetchContent_Populate(libccd)

  # --- PATCH: bump cmake_minimum_required in libccd CMakeLists.txt ---
  file(READ "${libccd_SOURCE_DIR}/CMakeLists.txt" _libccd_cmakelists)

  string(REGEX REPLACE
    "cmake_minimum_required\\([^)]*\\)"
    "cmake_minimum_required(VERSION 3.10)"
    _libccd_cmakelists "${_libccd_cmakelists}"
  )

  file(WRITE "${libccd_SOURCE_DIR}/CMakeLists.txt" "${_libccd_cmakelists}")

  # Now add libccd as a normal subdir
  add_subdirectory("${libccd_SOURCE_DIR}" "${libccd_BINARY_DIR}")
endif()


include(GNUInstallDirs)

set(PROJECT_VERSION "3.8.0" CACHE INTERNAL "")
set(PROJECT_VERSION_MAJOR 3 CACHE INTERNAL "")
set(PROJECT_VERSION_MINOR 8 CACHE INTERNAL "")
set(PROJECT_VERSION_PATCH 0 CACHE INTERNAL "")

# Directories required by jrl-cmakemodules
set(INSTALL_FULL_INCLUDEDIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}" CACHE PATH "" FORCE)
set(INSTALL_FULL_LIBDIR     "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}"     CACHE PATH "" FORCE)
set(INSTALL_FULL_BINDIR     "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}"     CACHE PATH "" FORCE)

set(INSTALL_DOCUMENTATION OFF CACHE BOOL "" FORCE)
set(INSTALL_PYTHON_INTERFACE OFF CACHE BOOL "" FORCE)
set(INSTALL_LIBS OFF CACHE BOOL "" FORCE)
set(INSTALL_EXAMPLES OFF CACHE BOOL "" FORCE)


# -------- hpp-fcl (collision backend for Pinocchio) --------

set(BUILD_PYTHON_INTERFACE OFF CACHE BOOL "" FORCE)

# hpp-fcl'i shared yerine static olarak derle
set(HPP_FCL_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# >>> ADD THIS BLOCK <<<
set(ZLIB_USE_STATIC_LIBS OFF CACHE BOOL "" FORCE)
set(ZLIB_LIBRARY "/usr/lib/x86_64-linux-gnu/libz.so" CACHE FILEPATH "" FORCE)


FetchContent_Declare(
  hppfcl
  GIT_REPOSITORY https://github.com/humanoid-path-planner/hpp-fcl.git
  GIT_TAG        v2.4.5   # or whichever version you picked
)

# Turn off optional extras to keep it simple & portable
set(HPP_FCL_HAS_QHULL  OFF CACHE BOOL "" FORCE)
set(HPP_FCL_HAS_OCTOMAP OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING      OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS  OFF CACHE BOOL "" FORCE)

# Instead of FetchContent_MakeAvailable(), we hook into the populate step
FetchContent_GetProperties(hppfcl)
if(NOT hppfcl_POPULATED)
  FetchContent_Populate(hppfcl)

  # --- PATCH: bump cmake_minimum_required in hpp-fcl/CMakeLists.txt ---
  file(READ "${hppfcl_SOURCE_DIR}/CMakeLists.txt" _hppfcl_cmakelists)

  # Replace the first cmake_minimum_required(...) with a 3.22+ version
  string(REGEX REPLACE
    "cmake_minimum_required\\([^)]*\\)"
    "cmake_minimum_required(VERSION 3.22)"
    _hppfcl_cmakelists "${_hppfcl_cmakelists}"
  )

  file(WRITE "${hppfcl_SOURCE_DIR}/CMakeLists.txt" "${_hppfcl_cmakelists}")

  # Now configure hpp-fcl as a normal subdirectory
  add_subdirectory("${hppfcl_SOURCE_DIR}" "${hppfcl_BINARY_DIR}")
endif()

# --- HACK 2: hpp-fcl'ı pinocchioTargets export set'ine ekle ---
# Pinocchio, install(EXPORT "pinocchioTargets" ...) çağırırken
# bu set'e dahil hedefler hpp-fcl'e link ediyor.
# Eğer hpp-fcl hiçbir export set'inde değilse CMake şikâyet ediyor.
# Biz burada hpp-fcl'i pinocchioTargets'a da ekleyerek
# "requires target 'hpp-fcl' that is not in any export set" hatasını çözüyoruz.
if(TARGET hpp-fcl)
  install(
    TARGETS hpp-fcl
    EXPORT pinocchioTargets
  )
endif()

list(APPEND CMAKE_PREFIX_PATH "${hppfcl_BINARY_DIR}")

# hpp-fcl alt projesi kendi içinde "hpp-fcl" isimli bir target tanımlıyor,
# fakat Pinocchio "hpp-fcl::hpp-fcl" isimli IMPORTED target bekliyor.
# Eğer henüz yoksa, bizim projede bir ALIAS oluşturalım.
if (TARGET hpp-fcl AND NOT TARGET hpp-fcl::hpp-fcl)
  add_library(hpp-fcl::hpp-fcl ALIAS hpp-fcl)
endif()

# ---------- HPP-FCL include dizinlerini global ekle ----------
# config.hh tipik olarak:
#   ${hppfcl_SOURCE_DIR}/include/hpp/fcl/config.hh.in  (template)
#   ${hppfcl_BINARY_DIR}/include/hpp/fcl/config.hh     (generate edilen)
include_directories(
  "${hppfcl_SOURCE_DIR}/include"
  "${hppfcl_BINARY_DIR}/include"
)

# Pinocchio bazı yerlerde hpp-fcl::hpp-fcl bekliyor: alias oluştur.
if(TARGET hpp-fcl AND NOT TARGET hpp-fcl::hpp-fcl)
  add_library(hpp-fcl::hpp-fcl ALIAS hpp-fcl)
endif()

list(APPEND CMAKE_PREFIX_PATH "${hppfcl_BINARY_DIR}")




# -------------------- Pinocchio -------------------------

set(urdfdom_VERSION "1.1.0" CACHE STRING "" FORCE)

set(BUILD_WITH_URDF_SUPPORT       ON  CACHE BOOL "" FORCE)
set(BUILD_PYTHON_INTERFACE        OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING                 OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES                OFF CACHE BOOL "" FORCE)
set(BUILD_WITH_COLLISION_SUPPORT  ON CACHE BOOL "" FORCE)


# Var olan hpp-fcl’i, jrl-cmakemodules / Pinocchio tarafına "ben bu paketi buldum"
# diye tanıt. Böylece ADD_PROJECT_DEPENDENCY(hpp-fcl) yoluna girmek zorunda kalmaz.
set(HPP_FCL_FOUND TRUE CACHE BOOL "" FORCE)

# HPP_FCL_INCLUDE_DIR / HPP_FCL_LIBRARIES isimlerini, jrl-cmakemodules
# genelde "eski tarz" paketler için kullanıyor.
set(HPP_FCL_INCLUDE_DIR "${hppfcl_SOURCE_DIR}/include" CACHE PATH "" FORCE)
set(HPP_FCL_LIBRARIES hpp-fcl CACHE STRING "" FORCE)


set(PINOCCHIO_DISABLE_JRL_PACKAGING ON CACHE BOOL "" FORCE)

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

