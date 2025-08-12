include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(DKEngine_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(DKEngine_setup_options)
  option(DKEngine_ENABLE_HARDENING "Enable hardening" ON)
  option(DKEngine_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    DKEngine_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    DKEngine_ENABLE_HARDENING
    OFF)

  DKEngine_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR DKEngine_PACKAGING_MAINTAINER_MODE)
    option(DKEngine_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(DKEngine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(DKEngine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DKEngine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DKEngine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DKEngine_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(DKEngine_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(DKEngine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DKEngine_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(DKEngine_ENABLE_IPO "Enable IPO/LTO" ON)
    option(DKEngine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(DKEngine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DKEngine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(DKEngine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(DKEngine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DKEngine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DKEngine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DKEngine_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(DKEngine_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(DKEngine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DKEngine_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      DKEngine_ENABLE_IPO
      DKEngine_WARNINGS_AS_ERRORS
      DKEngine_ENABLE_USER_LINKER
      DKEngine_ENABLE_SANITIZER_ADDRESS
      DKEngine_ENABLE_SANITIZER_LEAK
      DKEngine_ENABLE_SANITIZER_UNDEFINED
      DKEngine_ENABLE_SANITIZER_THREAD
      DKEngine_ENABLE_SANITIZER_MEMORY
      DKEngine_ENABLE_UNITY_BUILD
      DKEngine_ENABLE_CLANG_TIDY
      DKEngine_ENABLE_CPPCHECK
      DKEngine_ENABLE_COVERAGE
      DKEngine_ENABLE_PCH
      DKEngine_ENABLE_CACHE)
  endif()

  DKEngine_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (DKEngine_ENABLE_SANITIZER_ADDRESS OR DKEngine_ENABLE_SANITIZER_THREAD OR DKEngine_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(DKEngine_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(DKEngine_global_options)
  if(DKEngine_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    DKEngine_enable_ipo()
  endif()

  DKEngine_supports_sanitizers()

  if(DKEngine_ENABLE_HARDENING AND DKEngine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DKEngine_ENABLE_SANITIZER_UNDEFINED
       OR DKEngine_ENABLE_SANITIZER_ADDRESS
       OR DKEngine_ENABLE_SANITIZER_THREAD
       OR DKEngine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${DKEngine_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${DKEngine_ENABLE_SANITIZER_UNDEFINED}")
    DKEngine_enable_hardening(DKEngine_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(DKEngine_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(DKEngine_warnings INTERFACE)
  add_library(DKEngine_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  DKEngine_set_project_warnings(
    DKEngine_warnings
    ${DKEngine_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(DKEngine_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    DKEngine_configure_linker(DKEngine_options)
  endif()

  include(cmake/Sanitizers.cmake)
  DKEngine_enable_sanitizers(
    DKEngine_options
    ${DKEngine_ENABLE_SANITIZER_ADDRESS}
    ${DKEngine_ENABLE_SANITIZER_LEAK}
    ${DKEngine_ENABLE_SANITIZER_UNDEFINED}
    ${DKEngine_ENABLE_SANITIZER_THREAD}
    ${DKEngine_ENABLE_SANITIZER_MEMORY})

  set_target_properties(DKEngine_options PROPERTIES UNITY_BUILD ${DKEngine_ENABLE_UNITY_BUILD})

  if(DKEngine_ENABLE_PCH)
    target_precompile_headers(
      DKEngine_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(DKEngine_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    DKEngine_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(DKEngine_ENABLE_CLANG_TIDY)
    DKEngine_enable_clang_tidy(DKEngine_options ${DKEngine_WARNINGS_AS_ERRORS})
  endif()

  if(DKEngine_ENABLE_CPPCHECK)
    DKEngine_enable_cppcheck(${DKEngine_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(DKEngine_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    DKEngine_enable_coverage(DKEngine_options)
  endif()

  if(DKEngine_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(DKEngine_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(DKEngine_ENABLE_HARDENING AND NOT DKEngine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DKEngine_ENABLE_SANITIZER_UNDEFINED
       OR DKEngine_ENABLE_SANITIZER_ADDRESS
       OR DKEngine_ENABLE_SANITIZER_THREAD
       OR DKEngine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    DKEngine_enable_hardening(DKEngine_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
