import 'package:cbl/cbl.dart';

import '../test_binding_impl.dart';
import 'test_binding.dart';
import 'utils/database_utils.dart';

void main() {
  setupTestBinding();

  group('Logging', () {
    setUpAll(() => CblE2eTestBinding.instance.stopTestLogger());
    tearDownAll(() => CblE2eTestBinding.instance.startTestLogger());

    test('logLevel can be set', () {
      final initialLogLevel = CouchbaseLite.logLevel;
      addTearDown(() => CouchbaseLite.logLevel = initialLogLevel);

      CouchbaseLite.logLevel = LogLevel.verbose;
      expect(CouchbaseLite.logLevel, equals(LogLevel.verbose));
    });

    test(
      'logMessages emits log messages from CouchbaseLite implementation',
      () async {
        expect(
          CouchbaseLite.logMessages().map((it) => it.message),
          emitsThrough(
            matches('SQLiteDataFile.+LogCallback.+\.cblite2'),
          ),
        );

        await openTestDb('LogCallback');
      },
    );
  });
}
