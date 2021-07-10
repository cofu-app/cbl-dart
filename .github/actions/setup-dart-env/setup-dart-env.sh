#!/bin/bash

set -e

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dartVersion="$1"
flutterVersion="$2"
melosVersion="$3"
os="$4"

echo ::group::Setup Dart

"$scriptDir/setup-dart.sh" "$dartVersion" "$os" "x64"

echo ::endgroup::

echo ::group::Setup Flutter

"$scriptDir/setup-flutter.sh" "$flutterVersion"

echo ::endgroup::

echo ::group::Setup Melos

"$scriptDir/setup-melos.sh" "$melosVersion"

echo ::endgroup::
