import 'dart:io';

import 'package:cbl_ffi/cbl_ffi.dart';

/// Locates and returns the [Libraries] shipped by this package (`cbl_flutter`),
/// handling the differences between platforms.
Libraries flutterLibraries() {
  if (Platform.isIOS || Platform.isMacOS) {
    return Libraries(
      cbl: LibraryConfiguration.executable(),
      cblDart: LibraryConfiguration.executable(),
    );
  } else if (Platform.isAndroid || Platform.isLinux) {
    return Libraries(
      cbl: LibraryConfiguration.dynamic('libCouchbaseLiteC'),
      cblDart: LibraryConfiguration.dynamic('libCouchbaseLiteDart'),
    );
  } else {
    throw UnsupportedError('This platform is not supported.');
  }
}
