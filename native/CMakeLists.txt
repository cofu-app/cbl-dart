cmake_minimum_required (VERSION 3.1)
cmake_policy(VERSION 3.1)

project(Root)

if(ANDROID)
    add_compile_options(-Wno-elaborated-enum-base)
endif()

add_subdirectory(vendor/couchbase-lite-C)

add_subdirectory(cbl-dart)
