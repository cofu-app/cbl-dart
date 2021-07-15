import 'blob_test.dart' as blob;
import 'database_test.dart' as database;
import 'fleece/coding_test.dart' as fleece_coding;
import 'fleece/containers_test.dart' as fleece_containers;
import 'fleece/integration_test.dart' as fleece_integration;
import 'fleece/slice_test.dart' as fleece_slice;
import 'logging_test.dart' as logging;
import 'native_callback_test.dart' as native_callback;
import 'replicator_test.dart' as replicator;

final tests = {
  'blob': blob.main,
  'database': database.main,
  'fleece_coding': fleece_coding.main,
  'fleece_integration': fleece_integration.main,
  'fleece_slice': fleece_slice.main,
  'fleece_containers': fleece_containers.main,
  'logging': logging.main,
  'native_callback': native_callback.main,
  'replicator': replicator.main,
};

void main() {
  for (final main in tests.values) {
    main();
  }
}
