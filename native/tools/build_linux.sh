#!/usr/bin/env bash

set -e

# === Constants ===

toolsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nativeDir="$(cd "$toolsDir/.." && pwd)"
projectDir="$(cd "$nativeDir/.." && pwd)"
buildDir="$projectDir/build/linux"
libDir="$projectDir/build/linux/lib"
embedders=(standalone-dart flutter)

# === Commands ===

function buildForStandaloneDart() {
    local buildDir="$buildDir/standalone-dart"
    export CC=clang-10
    export CXX=clang++-10

    cmake \
        -B "$buildDir" \
        -G Ninja \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_INCLUDE_PATH=/usr/lib/llvm-10 \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
        "$nativeDir"

    cmake --build "$buildDir"
}

function buildForFlutter() {
    local buildDir="$buildDir/flutter"
    export CC=gcc-10
    export CXX=g++-10

    cmake \
        -B "$buildDir" \
        -G Ninja \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        "$nativeDir"

    cmake --build "$buildDir"
}

function copyToLib() {
    for embedder in "${embedders[@]}"; do
        local libDir="$buildDir/lib/$embedder"

        mkdir -p "$libDir"

        cp \
            "$buildDir/$embedder/cbl-dart/libCouchbaseLiteDart.so" \
            "$buildDir/$embedder/vendor/couchbase-lite-C/libCouchbaseLiteC.so" \
            "$libDir"
    done
}

function build() {
    buildForStandaloneDart
    buildForFlutter
    copyToLib
}

function createLinksForDev() {
    for embedder in "${embedders[@]}"; do
        local libDir="$buildDir/lib/$embedder"
        local packageDir=

        case "$embedder" in
        standalone-dart)
            packageDir="$projectDir/packages/cbl_e2e_tests_standalone_dart"
            ;;
        flutter)
            packageDir="$projectDir/packages/cbl_flutter/linux"
            ;;
        *)
            echo "Unknown embedder: $embedder"
            exit 1
            ;;
        esac

        cd "$packageDir"
        rm -f lib
        ln -s "$libDir" lib
    done
}

"$@"
