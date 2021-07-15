[![Version](https://badgen.net/pub/v/cbl)](https://pub.dev/packages/cbl)
[![License](https://badgen.net/pub/license/cbl)](https://github.com/cofu-app/cbl-dart/blob/main/packages/cbl/LICENSE)
[![CI](https://github.com/cofu-app/cbl-dart/actions/workflows/ci.yaml/badge.svg)](https://github.com/cofu-app/cbl-dart/actions/workflows/ci.yaml)

> :warning: This project has not yet reached a stable production release.

## Features - Couchbase Lite

- Schemaless JSON documents
- Binary JSON format (Fleece)
  - Reading without parsing
- Blobs
  - A binary data value associated with a document
- Queries
  - Supports large subset of N1QL query language
  - Machine readable representation of queries as JSON
  - Full text search
  - Indexes
  - Observable queries
- Replication
  - Synchronize with Couchbase Server through Sync Gateway

## Features - Dart API

- Calls Couchbase Lite C API through FFI
- Expensive operations run in separate isolate
  - No blocking of calling isolate
- Streams for event based APIs
- Support for Flutter apps
- Support for standalone Dart (for example a CLI)
- Well documented

## Supported Platforms

| Platform | Minimum version |
| -------: | --------------- |
|      iOS | 11              |
|    macOS | 10.13           |
|  Android | 19              |

## Installation

This package only contains Dart code and requires binary libraries to be
packaged with any app that wants to use it. For Flutter apps, you need to add
[`cbl_flutter`](https://pub.dev/packages/cbl_flutter) as a dependency to include
those libraries in the build. `cbl_flutter` currently supports iOS, macOS and
Android.

```pubspec
dependencies:
    cbl: ...
    cbl_flutter: ...
```

## Getting started

Make sure you have set the required minimum target version in the build systems
of the platforms you support.

Before you access any part of the library, `CouchbaseLite` needs to be
initialized with a configuration of how to load the binary libraries.

```dart
import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';

void initCbl() {
  CouchbaseLite.initialize(libraries: flutterLibraries());
}
```

Now you can use `Database.open` to open a database:

```dart
import 'package:cbl/cbl.dart';
import 'package:path_provider/path_provider.dart';

Future<void> openDatabase() async {
  final documentsDir = await getApplicationDocumentsDirectory();

  final db = await Database.open(
      'MyFirstDB',
      config: DatabaseConfiguration(directory: documentsDir.path),
  )

  final doc = MutableDocument({
    'type': 'message',
    'body': 'Heyo',
    'from': 'Alice',
  });

  final savedDoc = await db.saveDocument(doc)
}
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to
discuss what you would like to change.

Please make sure to update tests as appropriate.

Read the [contributor guide] to get started developing.

# Disclaimer

> **Warning:** This is not an official Couchbase product.

[contributor guide]: ../../docs/CONTRIBUTOR_GUIDE.md
