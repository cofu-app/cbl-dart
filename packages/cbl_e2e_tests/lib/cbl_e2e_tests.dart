import 'src/blob_test.dart' as blob;
import 'src/database_test.dart' as database;
import 'src/fleece/coding_test.dart' as fleece_coding;
import 'src/fleece/integration_test.dart' as fleece_integration;
import 'src/fleece/slice_test.dart' as fleece_slice;
import 'src/fleece/containers_test.dart' as fleece;
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
