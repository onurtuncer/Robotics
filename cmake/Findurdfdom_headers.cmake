# Custom finder for urdfdom_headers to avoid subproject/uninstall clashes.
# The top-level CMake sets URDFDOM_HEADERS_INCLUDE_DIR to <repo>/include.

if(NOT DEFINED URDFDOM_HEADERS_INCLUDE_DIR)
  message(FATAL_ERROR "URDFDOM_HEADERS_INCLUDE_DIR not set; set it before add_subdirectory(urdfdom)")
endif()

set(urdfdom_headers_INCLUDE_DIRS "${URDFDOM_HEADERS_INCLUDE_DIR}")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(urdfdom_headers
  REQUIRED_VARS urdfdom_headers_INCLUDE_DIRS)


# # Detect include dir (must end with /include)
# if(NOT DEFINED URDFDOM_HEADERS_INCLUDE_DIR)
#   if(EXISTS "${CMAKE_BINARY_DIR}/_deps/urdfdom_headers_src-src/include/urdf_model")
#     set(URDFDOM_HEADERS_INCLUDE_DIR "${CMAKE_BINARY_DIR}/_deps/urdfdom_headers_src-src/include")
#   elseif(EXISTS "${CMAKE_SOURCE_DIR}/_deps/urdfdom_headers_src-src/include/urdf_model")
#     set(URDFDOM_HEADERS_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/_deps/urdfdom_headers_src-src/include")
#   endif()
# endif()

# # Version (Pinocchio copies this)
# if(NOT DEFINED urdfdom_headers_VERSION)
#   set(urdfdom_headers_VERSION "1.1.2")
# endif()

# # >>> IMPORTANT: expose genex for urdfdom’s CMake <<<
# set(urdfdom_headers_INCLUDE_DIRS
#   "$<BUILD_INTERFACE:${URDFDOM_HEADERS_INCLUDE_DIR}>;$<INSTALL_INTERFACE:include>")

# # Keep the upper-case too (some consumers use it)
# set(URDFDOM_HEADERS_INCLUDE_DIRS "${urdfdom_headers_INCLUDE_DIRS}")

# include(FindPackageHandleStandardArgs)
# find_package_handle_standard_args(
#   urdfdom_headers
#   REQUIRED_VARS URDFDOM_HEADERS_INCLUDE_DIR
#   VERSION_VAR   urdfdom_headers_VERSION
# )

# # Optional imported targets
# if(urdfdom_headers_FOUND)
#   if(NOT TARGET urdfdom_headers::urdfdom_headers)
#     add_library(urdfdom_headers::urdfdom_headers INTERFACE IMPORTED)
#     set_target_properties(urdfdom_headers::urdfdom_headers PROPERTIES
#       INTERFACE_INCLUDE_DIRECTORIES "${urdfdom_headers_INCLUDE_DIRS}")
#   endif()
#   if(NOT TARGET urdfdom_headers)
#     add_library(urdfdom_headers INTERFACE IMPORTED)
#     set_target_properties(urdfdom_headers PROPERTIES
#       INTERFACE_INCLUDE_DIRECTORIES "${urdfdom_headers_INCLUDE_DIRS}")
#   endif()
# endif()

