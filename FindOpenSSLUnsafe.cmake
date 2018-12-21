# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

if (UNIX)
  find_package(PkgConfig QUIET)
  pkg_check_modules(_OPENSSL QUIET openssl-unsafe)
endif ()

# Support preference of static libs by adjusting CMAKE_FIND_LIBRARY_SUFFIXES
if(OPENSSL_USE_STATIC_LIBS)
  set(_openssl_ORIG_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
  if(WIN32)
    set(CMAKE_FIND_LIBRARY_SUFFIXES .lib .a ${CMAKE_FIND_LIBRARY_SUFFIXES})
  else()
    set(CMAKE_FIND_LIBRARY_SUFFIXES .a )
  endif()
endif()

if (WIN32)
else ()
  set(_OPENSSL_ROOT_HINTS
    ${OPENSSL_ROOT_DIR}
    ENV OPENSSL_ROOT_DIR
    )
endif ()

set(_OPENSSL_ROOT_HINTS_AND_PATHS
    HINTS ${_OPENSSL_ROOT_HINTS}
    PATHS ${_OPENSSL_ROOT_PATHS}
    )

find_path(OPENSSL_UNSAFE_INCLUDE_DIR
  NAMES
    openssl-unsafe/ssl.h
  ${_OPENSSL_ROOT_HINTS_AND_PATHS}
  HINTS
    ${_OPENSSL_INCLUDEDIR}
  PATH_SUFFIXES
    include
)

if(WIN32 AND NOT CYGWIN)
else()

  find_library(OPENSSL_UNSAFE_SSL_LIBRARY
    NAMES
      unsafessl
    NAMES_PER_DIR
    ${_OPENSSL_ROOT_HINTS_AND_PATHS}
    HINTS
      ${_OPENSSL_LIBDIR}
    PATH_SUFFIXES
      lib
  )

  find_library(OPENSSL_UNSAFE_CRYPTO_LIBRARY
    NAMES
      unsafecrypto
    NAMES_PER_DIR
    ${_OPENSSL_ROOT_HINTS_AND_PATHS}
    HINTS
      ${_OPENSSL_LIBDIR}
    PATH_SUFFIXES
      lib
  )

  mark_as_advanced(OPENSSL_UNSAFE_CRYPTO_LIBRARY OPENSSL_UNSAFE_SSL_LIBRARY)

  # compat defines
  set(OPENSSL_UNSAFE_SSL_LIBRARIES ${OPENSSL_SSL_LIBRARY})
  set(OPENSSL_UNSAFE_CRYPTO_LIBRARIES ${OPENSSL_CRYPTO_LIBRARY})

endif()

function(from_hex HEX DEC)
  string(TOUPPER "${HEX}" HEX)
  set(_res 0)
  string(LENGTH "${HEX}" _strlen)

  while (_strlen GREATER 0)
    math(EXPR _res "${_res} * 16")
    string(SUBSTRING "${HEX}" 0 1 NIBBLE)
    string(SUBSTRING "${HEX}" 1 -1 HEX)
    if (NIBBLE STREQUAL "A")
      math(EXPR _res "${_res} + 10")
    elseif (NIBBLE STREQUAL "B")
      math(EXPR _res "${_res} + 11")
    elseif (NIBBLE STREQUAL "C")
      math(EXPR _res "${_res} + 12")
    elseif (NIBBLE STREQUAL "D")
      math(EXPR _res "${_res} + 13")
    elseif (NIBBLE STREQUAL "E")
      math(EXPR _res "${_res} + 14")
    elseif (NIBBLE STREQUAL "F")
      math(EXPR _res "${_res} + 15")
    else()
      math(EXPR _res "${_res} + ${NIBBLE}")
    endif()

    string(LENGTH "${HEX}" _strlen)
  endwhile()

  set(${DEC} ${_res} PARENT_SCOPE)
endfunction()

if(OPENSSL_UNSAFE_INCLUDE_DIR AND EXISTS "${OPENSSL_UNSAFE_INCLUDE_DIR}/openssl-unsafe/opensslv.h")
  file(STRINGS "${OPENSSL_UNSAFE_INCLUDE_DIR}/openssl-unsafe/opensslv.h" openssl_version_str
       REGEX "^#[\t ]*define[\t ]+OPENSSL_VERSION_NUMBER[\t ]+0x([0-9a-fA-F])+.*")

  if(openssl_version_str)
    # The version number is encoded as 0xMNNFFPPS: major minor fix patch status
    # The status gives if this is a developer or prerelease and is ignored here.
    # Major, minor, and fix directly translate into the version numbers shown in
    # the string. The patch field translates to the single character suffix that
    # indicates the bug fix state, which 00 -> nothing, 01 -> a, 02 -> b and so
    # on.

    string(REGEX REPLACE "^.*OPENSSL_VERSION_NUMBER[\t ]+0x([0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F][0-9a-fA-F])([0-9a-fA-F]).*$"
           "\\1;\\2;\\3;\\4;\\5" OPENSSL_VERSION_LIST "${openssl_version_str}")
    list(GET OPENSSL_VERSION_LIST 0 OPENSSL_VERSION_MAJOR)
    list(GET OPENSSL_VERSION_LIST 1 OPENSSL_VERSION_MINOR)
    from_hex("${OPENSSL_VERSION_MINOR}" OPENSSL_VERSION_MINOR)
    list(GET OPENSSL_VERSION_LIST 2 OPENSSL_VERSION_FIX)
    from_hex("${OPENSSL_VERSION_FIX}" OPENSSL_VERSION_FIX)
    list(GET OPENSSL_VERSION_LIST 3 OPENSSL_VERSION_PATCH)

    if (NOT OPENSSL_VERSION_PATCH STREQUAL "00")
      from_hex("${OPENSSL_VERSION_PATCH}" _tmp)
      # 96 is the ASCII code of 'a' minus 1
      math(EXPR OPENSSL_VERSION_PATCH_ASCII "${_tmp} + 96")
      unset(_tmp)
      # Once anyone knows how OpenSSL would call the patch versions beyond 'z'
      # this should be updated to handle that, too. This has not happened yet
      # so it is simply ignored here for now.
      string(ASCII "${OPENSSL_VERSION_PATCH_ASCII}" OPENSSL_VERSION_PATCH_STRING)
    endif ()

    set(OPENSSL_UNSAFE_VERSION "${OPENSSL_VERSION_MAJOR}.${OPENSSL_VERSION_MINOR}.${OPENSSL_VERSION_FIX}${OPENSSL_VERSION_PATCH_STRING}")
  endif ()
endif ()

set(OPENSSL_UNSAFE_LIBRARIES ${OPENSSL_UNSAFE_SSL_LIBRARY} ${OPENSSL_UNSAFE_CRYPTO_LIBRARY} )

foreach(_comp IN LISTS OpenSSLUnsafe_FIND_COMPONENTS)
  if(_comp STREQUAL "Crypto")
    if(EXISTS "${OPENSSL_UNSAFE_INCLUDE_DIR}" AND
        (EXISTS "${OPENSSL_UNSAFE_CRYPTO_LIBRARY}" OR
        EXISTS "${LIB_EAY_LIBRARY_DEBUG}" OR
        EXISTS "${LIB_EAY_LIBRARY_RELEASE}")
    )
      set(OpenSSLUnsafe_${_comp}_FOUND TRUE)
    else()
      set(OpenSSLUnsafe_${_comp}_FOUND FALSE)
    endif()
  elseif(_comp STREQUAL "SSL")
    if(EXISTS "${OPENSSL_UNSAFE_INCLUDE_DIR}" AND
        (EXISTS "${OPENSSL_UNSAFE_SSL_LIBRARY}" OR
        EXISTS "${SSL_EAY_LIBRARY_DEBUG}" OR
        EXISTS "${SSL_EAY_LIBRARY_RELEASE}")
    )
      set(OpenSSLUnsafe_${_comp}_FOUND TRUE)
    else()
      set(OpenSSLUnsafe_${_comp}_FOUND FALSE)
    endif()
  else()
    message(WARNING "${_comp} is not a valid OpenSSL component")
    set(OpenSSLUnsafe_${_comp}_FOUND FALSE)
  endif()
endforeach()
unset(_comp)

include(${CMAKE_ROOT}/Modules/FindPackageHandleStandardArgs.cmake)
find_package_handle_standard_args(OpenSSLUnsafe
  REQUIRED_VARS
    OPENSSL_UNSAFE_CRYPTO_LIBRARY
    OPENSSL_UNSAFE_INCLUDE_DIR
  VERSION_VAR
    OPENSSL_UNSAFE_VERSION
  HANDLE_COMPONENTS
  FAIL_MESSAGE
    "Could NOT find OpenSSLUnsafe, try to set the path to OpenSSLUnsafe root folder in the system variable OPENSSL_ROOT_DIR"
)

mark_as_advanced(OPENSSL_UNSAFE_INCLUDE_DIR OPENSSL_UNSAFE_LIBRARIES)

if(OPENSSLUNSAFE_FOUND)
  if(NOT TARGET OpenSSLUnsafe::Crypto AND
      (EXISTS "${OPENSSL_UNSAFE_CRYPTO_LIBRARY}" OR
        EXISTS "${LIB_EAY_LIBRARY_DEBUG}" OR
        EXISTS "${LIB_EAY_LIBRARY_RELEASE}")
      )
    add_library(OpenSSLUnsafe::Crypto UNKNOWN IMPORTED)
    set_target_properties(OpenSSLUnsafe::Crypto PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_UNSAFE_INCLUDE_DIR}")
    if(EXISTS "${OPENSSL_UNSAFE_CRYPTO_LIBRARY}")
      set_target_properties(OpenSSLUnsafe::Crypto PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES "C"
        IMPORTED_LOCATION "${OPENSSL_UNSAFE_CRYPTO_LIBRARY}")
    endif()
    if(EXISTS "${LIB_EAY_LIBRARY_RELEASE}")
      set_property(TARGET OpenSSLUnsafe::Crypto APPEND PROPERTY
        IMPORTED_CONFIGURATIONS RELEASE)
      set_target_properties(OpenSSLUnsafe::Crypto PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C"
        IMPORTED_LOCATION_RELEASE "${LIB_EAY_LIBRARY_RELEASE}")
    endif()
    if(EXISTS "${LIB_EAY_LIBRARY_DEBUG}")
      set_property(TARGET OpenSSLUnsafe::Crypto APPEND PROPERTY
        IMPORTED_CONFIGURATIONS DEBUG)
      set_target_properties(OpenSSLUnsafe::Crypto PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
        IMPORTED_LOCATION_DEBUG "${LIB_EAY_LIBRARY_DEBUG}")
    endif()
  endif()

  if(NOT TARGET OpenSSLUnsafe::SSL AND
      (EXISTS "${OPENSSL_UNSAFE_SSL_LIBRARY}" OR
        EXISTS "${SSL_EAY_LIBRARY_DEBUG}" OR
        EXISTS "${SSL_EAY_LIBRARY_RELEASE}")
      )
    add_library(OpenSSLUnsafe::SSL UNKNOWN IMPORTED)
    set_target_properties(OpenSSLUnsafe::SSL PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES "${OPENSSL_UNSAFE_INCLUDE_DIR}")
    if(EXISTS "${OPENSSL_UNSAFE_SSL_LIBRARY}")
      set_target_properties(OpenSSLUnsafe::SSL PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES "C"
        IMPORTED_LOCATION "${OPENSSL_UNSAFE_SSL_LIBRARY}")
    endif()
    if(EXISTS "${SSL_EAY_LIBRARY_RELEASE}")
      set_property(TARGET OpenSSLUnsafe::SSL APPEND PROPERTY
        IMPORTED_CONFIGURATIONS RELEASE)
      set_target_properties(OpenSSLUnsafe::SSL PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "C"
        IMPORTED_LOCATION_RELEASE "${SSL_EAY_LIBRARY_RELEASE}")
    endif()
    if(EXISTS "${SSL_EAY_LIBRARY_DEBUG}")
      set_property(TARGET OpenSSLUnsafe::SSL APPEND PROPERTY
        IMPORTED_CONFIGURATIONS DEBUG)
      set_target_properties(OpenSSLUnsafe::SSL PROPERTIES
        IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "C"
        IMPORTED_LOCATION_DEBUG "${SSL_EAY_LIBRARY_DEBUG}")
    endif()
    if(TARGET OpenSSLUnsafe::Crypto)
      set_target_properties(OpenSSLUnsafe::SSL PROPERTIES
        INTERFACE_LINK_LIBRARIES OpenSSLUnsafe::Crypto)
    endif()
  endif()
endif()

# Restore the original find library ordering
if(OPENSSL_USE_STATIC_LIBS)
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${_openssl_ORIG_CMAKE_FIND_LIBRARY_SUFFIXES})
endif()
