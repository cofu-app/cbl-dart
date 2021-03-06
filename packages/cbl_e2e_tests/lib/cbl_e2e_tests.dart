import 'src/blob_test.dart' as blob;
import 'src/database_test.dart' as database;
import 'src/fleece_coding_test.dart' as fleece_coding;
import 'src/fleece_integration_test.dart' as fleece_integration;
import 'src/fleece_slice_test.dart' as fleece_slice;
import 'src/fleece_test.dart' as fleece;
import 'src/logging_test.dart' as logging;
import 'src/native_callback_test.dart' as native_callback;
import 'src/replicator_test.dart' as replicator;

export 'src/test_binding.dart';

final tests = {
  'blob': blob.main,
  'database': database.main,
  'fleece_coding': fleece_coding.main,
  'fleece_integration': fleece_integration.main,
  'fleece_slice': fleece_slice.main,
  'fleece': fleece.main,
  'logging': logging.main,
  'native_callback': native_callback.main,
  'replicator': replicator.main,
};

void cblE2eTests() {
  for (final main in tests.values) {
    main();
  }
}
