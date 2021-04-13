import 'package:cbl_e2e_tests/cbl_e2e_tests.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:flutter_test/flutter_test.dart' as ft;
import 'package:path_provider/path_provider.dart';

class FlutterCblE2eTestBinding extends CblE2eTestBinding {
  static void ensureInitialized() {
    CblE2eTestBinding.ensureInitialized(() => FlutterCblE2eTestBinding());
  }

  @override
  final libraries = flutterLibraries();

  @override
  Future<String> resolveTmpDir() => getTemporaryDirectory()
      .then((dir) => dir.uri.resolve('cbl_flutter_e2e_test').path);

  @override
  final testFn = (dynamic description, body) =>
      ft.testWidgets(description as String, (tester) async => await body());

  @override
  final groupFn =
      (dynamic description, body) => ft.group(description as Object, body);

  @override
  final setUpAllFn = ft.setUpAll;

  @override
  final setUpFn = ft.setUp;

  @override
  final tearDownAllFn = ft.tearDownAll;

  @override
  final tearDownFn = ft.tearDown;

  @override
  final addTearDownFn = ft.addTearDown;
}
