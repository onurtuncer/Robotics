cmake_minimum_required(VERSION 3.22)
project(mini_pinocchio_superbuild LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ------------------ Fetch Eigen3 ------------------
include(FetchContent)

# Choose a stable release tag; 3.4.x works well
FetchContent_Declare(
  eigen3
  GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
  GIT_TAG 3.4.0
)

# Don’t build Eigen’s tests/doc
set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
set(EIGEN_BUILD_PKGCONFIG OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(eigen3)

# Make Pinocchio's "find_package(Eigen3)" succeed.
# Eigen ships its package config under "<eigen_source>/cmake".
set(Eigen3_DIR "${eigen3_SOURCE_DIR}/cmake" CACHE PATH "" FORCE)
# Also help generic search paths, just in case:
list(PREPEND CMAKE_PREFIX_PATH "${eigen3_SOURCE_DIR}")

# Keep Pinocchio lean; flip ON later as needed
set(BUILD_PYTHON_INTERFACE        OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING                 OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES                OFF CACHE BOOL "" FORCE)
set(BUILD_WITH_URDF_SUPPORT       OFF CACHE BOOL "" FORCE)  # ON if you’ll parse URDF
set(BUILD_WITH_COLLISION_SUPPORT  OFF CACHE BOOL "" FORCE)  # ON if you add hpp-fcl

# Bring your forked Pinocchio *into this build* (uses its own CMake)
add_subdirectory(vendor/pinocchio)

# Your app
add_executable(mini src/main.cpp)
# When built in-tree, target is 'pinocchio' (not namespaced)
target_link_libraries(mini PRIVATE pinocchio)
