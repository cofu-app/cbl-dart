cmake_minimum_required (VERSION 3.1)
cmake_policy(VERSION 3.1)

project(Root)

# Standalone Dart and Flutter is using libc++ on Linux.
if(${CMAKE_SYSTEM_NAME} STREQUAL "Linux")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
endif()

if(ANDROID)
    add_compile_options(-Wno-elaborated-enum-base)
endif()

add_subdirectory(vendor/couchbase-lite-C)

add_subdirectory(cbl-dart)
