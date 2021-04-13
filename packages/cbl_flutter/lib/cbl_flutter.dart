import 'dart:io';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:path/path.dart' as p;

/// Locates and returns the [Libraries] shipped by this package (`cbl_flutter`),
/// handling the differences between platforms.
Libraries flutterLibraries() {
  if (Platform.isIOS || Platform.isMacOS) {
    return Libraries(
      cbl: LibraryConfiguration.executable(),
      cblDart: LibraryConfiguration.executable(),
    );
  } else if (Platform.isAndroid) {
    return Libraries(
      cbl: LibraryConfiguration.dynamic('libCouchbaseLiteC'),
      cblDart: LibraryConfiguration.dynamic('libCouchbaseLiteDart'),
    );
  } else if (Platform.isLinux) {
    final bundlePath = p.dirname(Platform.resolvedExecutable);
    final libDir = p.join(bundlePath, 'lib');
    return Libraries(
      cbl: LibraryConfiguration.dynamic(p.join(libDir, 'libCouchbaseLiteC')),
      cblDart:
          LibraryConfiguration.dynamic(p.join(libDir, 'libCouchbaseLiteDart')),
    );
  } else {
    throw UnsupportedError('This platform is not supported.');
  }
}
