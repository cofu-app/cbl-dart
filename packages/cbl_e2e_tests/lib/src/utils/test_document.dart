/// This file contains helpers for testing with a single simple document.
library test_document;

import 'package:cbl/cbl.dart';

import '../test_binding.dart';

/// The id of the test document if it has been written to at least once.
String? testDocumentId;

/// Set up a test hook which resets [testDocumentId] for each test.
void setupTestDocument() {
  setUp(() {
    testDocumentId = null;
  });
}

/// Returns a matcher which checks that the matched value is a [Document] with
/// [testDocumentId] which has [value] in its properties.
Matcher isTestDocument(String value) => isA<Document>()
    .having((it) => it.id, 'id', testDocumentId)
    .having((it) => it.toMap(), 'toMap()', {'value': value});

extension TestDocumentDatabaseExtension on Database {
  /// Writes [value] in the properties of the test document. If its does not
  /// exist already in this database, it is created.
  Future<Document> writeTestDocument(String value) async {
    final doc =
        await getTestDocumentOrNull().then((it) => it ?? MutableDocument());

    doc.setValue(value, key: 'value');

    final savedDoc = await saveDocument(doc);

    testDocumentId ??= savedDoc.id;

    return savedDoc;
  }

  /// Gets the test document or `null` if does not exist.
  Future<MutableDocument?> getTestDocumentOrNull() async =>
      testDocumentId == null ? null : getMutableDocument(testDocumentId!);
}
