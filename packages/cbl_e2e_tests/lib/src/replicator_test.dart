import 'dart:typed_data';

import 'package:cbl/cbl.dart';
import 'package:rxdart/rxdart.dart';

import '../test_binding_impl.dart';
import 'test_binding.dart';
import 'utils/database_utils.dart';
import 'utils/replicator_utils.dart';
import 'utils/test_document.dart';

void main() {
  setupTestBinding();

  group('Replicator', () {
    setupTestDocument();
    setUp(clearTestServerDb);

    test('create Replicator smoke test', () async {
      final db = await openTestDb('CreateReplicatorSmoke');

      final replicator = await db.createReplicator(ReplicatorConfiguration(
        endpoint: UrlEndpoint(testSyncGatewayUrl),
        replicatorType: ReplicatorType.pushAndPull,
        continuous: false,
        authenticator: BasicAuthenticator(
          username: 'user',
          password: 'password',
        ),
        headers: {'Client': 'test'},
        proxy: ProxySettings(
          type: ProxyType.http,
          hostname: 'host',
          port: 4444,
          username: 'user',
          password: 'password',
        ),
        pinnedServerCertificate: Uint8List(0),
        trustedRootCertificates: Uint8List(0),
        channels: ['channel'],
        documentIds: ['id'],
        pullFilter: (document, isDeleted) => true,
        pushFilter: (document, isDeleted) => true,
        conflictResolver: (documentId, local, remote) => local,
      ));

      // Throws exception because we don't provide valid certificates.
      await expectLater(
        replicator.startAndWaitUntilStopped(),
        throwsA(isA<CouchbaseLiteException>().having(
          (it) => it.code,
          'code',
          CouchbaseLiteErrorCode.remoteError,
        )),
      );
    });

    test('continuous replication', () async {
      final dbA = await openTestDb('ContinuousReplication-DB-A');
      final dbB = await openTestDb('ContinuousReplication-DB-B');

      final replicatorA = await dbA.createTestReplicator(
        replicatorType: ReplicatorType.push,
        continuous: true,
      );
      await replicatorA.start();

      final replicatorB = await dbB.createTestReplicator(
        replicatorType: ReplicatorType.pull,
        continuous: true,
      );
      await replicatorB.start();

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final doc =
          MutableDocument.withId('continuouslyReplicatedDoc-$timestamp');

      final stream = dbB.watchAllIds().shareReplay();

      // ignore: unawaited_futures
      stream.first.then((_) => dbA.saveDocument(doc));

      expect(
        stream,
        emitsInOrder(<dynamic>[
          isEmpty,
          [doc.id],
        ]),
      );
    });

    test('use documentIds to filter replicated documents', () async {
      // Insert doc A and B into db A
      // Sync db A with server with documentIds == [docA.id]
      // Sync db B with server
      // => db B only contains doc A

      final dbA = await openTestDb('ReplicationWithDocumentIds-DB-A');
      final dbB = await openTestDb('ReplicationWithDocumentIds-DB-B');

      final docA = await dbA.saveDocument(MutableDocument());
      await dbA.saveDocument(MutableDocument());

      final replicatorA = await dbA.createTestReplicator(
        replicatorType: ReplicatorType.push,
        documentIds: [docA.id],
      );
      await replicatorA.startAndWaitUntilStopped();

      final replicatorB = await dbB.createTestReplicator(
        replicatorType: ReplicatorType.pull,
      );
      await replicatorB.startAndWaitUntilStopped();

      final idsInDbB = await dbB.getAllIds().toList();
      expect(idsInDbB, [docA.id]);
    });

    test('use channels to filter pulled documents', () async {
      // Insert doc A and B into db A, where doc A is in channel A
      // Sync db A with server
      // Sync db B with server with channels == ['A']
      // => db B only contains doc A

      final dbA = await openTestDb('ReplicationWithChannels-DB-A');
      final dbB = await openTestDb('ReplicationWithChannels-DB-B');

      final docA = await dbA.saveDocument(MutableDocument({'channels': 'A'}));
      await dbA.saveDocument(MutableDocument());

      final replicatorA = await dbA.createTestReplicator(
        replicatorType: ReplicatorType.push,
      );
      await replicatorA.startAndWaitUntilStopped();

      final replicatorB = await dbB.createTestReplicator(
        replicatorType: ReplicatorType.pull,
        channels: ['A'],
      );
      await replicatorB.startAndWaitUntilStopped();

      final idsInDbB = await dbB.getAllIds().toList();
      expect(idsInDbB, [docA.id]);
    });

    test('use pushFilter to filter pushed documents', () async {
      final dbA = await openTestDb('ReplicationWithPushFilter-DB-A');
      final dbB = await openTestDb('ReplicationWithPushFilter-DB-B');

      final docA = await dbA.saveDocument(MutableDocument());
      final docB = await dbA.saveDocument(MutableDocument());

      final replicatorA = await dbA.createTestReplicator(
        replicatorType: ReplicatorType.push,
        pushFilter: expectAsync2(
          (document, isDeleted) {
            expect(isDeleted, isFalse);
            expect(document.id, anyOf(docA.id, docB.id));
            return docA.id == document.id;
          },
          count: 2,
        ),
      );
      await replicatorA.startAndWaitUntilStopped();

      final replicatorB = await dbB.createTestReplicator(
        replicatorType: ReplicatorType.pull,
      );
      await replicatorB.startAndWaitUntilStopped();

      final idsInDbB = await dbB.getAllIds().toList();
      expect(idsInDbB, [docA.id]);
    });

    test('use pullFilter to filter pulled documents', () async {
      final dbA = await openTestDb('ReplicationWithPullFilter-DB-A');
      final dbB = await openTestDb('ReplicationWithPullFilter-DB-B');

      final docA = await dbA.saveDocument(MutableDocument());
      final docB = await dbA.saveDocument(MutableDocument());

      final replicatorA = await dbA.createTestReplicator(
        replicatorType: ReplicatorType.push,
      );
      await replicatorA.startAndWaitUntilStopped();

      final replicatorB = await dbB.createTestReplicator(
        replicatorType: ReplicatorType.pull,
        pullFilter: expectAsync2(
          (document, isDeleted) {
            expect(isDeleted, isFalse);
            expect(document.id, anyOf(docA.id, docB.id));
            return docA.id == document.id;
          },
          count: 2,
        ),
      );
      await replicatorB.startAndWaitUntilStopped();

      final idsInDbB = await dbB.getAllIds().toList();
      expect(idsInDbB, [docA.id]);
    });

    test('conflict resolver should work correctly', () async {
      // Create document in db A
      // Sync db A with server
      // Sync db B with server
      // Change doc in db A
      // Change doc in db B
      // Sync db B with server
      // Sync db A with server
      // => Conflict in db A

      final dbA = await openTestDb('ConflictResolver-DB-A');
      final replicatorA = await dbA.createTestReplicator(
        conflictResolver: expectAsync3((documentId, local, remote) {
          expect(documentId, testDocumentId);
          expect(local, isTestDocument('DB-A-2'));
          expect(remote, isTestDocument('DB-B-1'));
          return remote;
        }),
      );

      final dbB = await openTestDb('ConflictResolver-DB-B');
      final replicatorB = await dbB.createTestReplicator();

      await dbA.writeTestDocument('DB-A-1');
      await replicatorA.startAndWaitUntilStopped();
      await replicatorB.startAndWaitUntilStopped();
      await dbA.writeTestDocument('DB-A-2');
      await dbB.writeTestDocument('DB-B-1');
      await replicatorB.startAndWaitUntilStopped();
      await replicatorA.startAndWaitUntilStopped();

      expect(await dbA.getTestDocumentOrNull(), isTestDocument('DB-B-1'));
    });

    test('setHostReachable smoke test', () async {
      final db = await openTestDb('SetHostReachableSmoke');
      final replicator = await db.createTestReplicator();
      await replicator.setHostReachable(false);
      await replicator.setHostReachable(true);
    });

    test('setSuspended smoke test', () async {
      final db = await openTestDb('SetSuspendedSmoke');
      final replicator = await db.createTestReplicator();
      await replicator.setSuspended(true);
      await replicator.setSuspended(false);
    });

    test('status returns the current status of the replicator', () async {
      final db = await openTestDb('GetReplicatorStatus');
      final replicator = await db.createTestReplicator();
      final status = await replicator.status();
      expect(status.activity, ReplicatorActivityLevel.stopped);
      expect(status.error, isNull);
      expect(status.progress.documentCount, 0);
      expect(status.progress.fractionComplete, 0.0);
    });

    test('statusChanges emits when the replicators status changes', () async {
      final db = await openTestDb('ReplicatorStatusChanges');
      final replicator = await db.createTestReplicator();

      expect(
        replicator.statusChanges().map((it) => it.activity),
        emitsInOrder(<ReplicatorActivityLevel>[
          ReplicatorActivityLevel.busy,
          ReplicatorActivityLevel.stopped,
        ]),
      );

      await replicator.start();
    });

    test('pendingDocumentIds returns ids of documents waiting to be pushed',
        () async {
      final db = await openTestDb('PendingDocumentIds');
      final replicator = await db.createTestReplicator();
      final doc = await db.saveDocument(MutableDocument());
      final pendingDocumentIds = await replicator.pendingDocumentIds();
      expect(pendingDocumentIds.toObject(), {doc.id: true});
    });

    test('isDocumentPending returns whether a document is waiting to be pushed',
        () async {
      final db = await openTestDb('IsDocumentPending');
      final replicator = await db.createTestReplicator();
      final doc = await db.saveDocument(MutableDocument());
      expect(await replicator.isDocumentPending(doc.id), isTrue);
    });

    test(
        'documentReplications emits events when documents have been replicated',
        () async {
      final db = await openTestDb('DocumentReplications');
      final replicator = await db.createTestReplicator(
        replicatorType: ReplicatorType.push,
      );
      final doc = await db.saveDocument(MutableDocument());

      expect(
        replicator.documentReplications(),
        emits(DocumentsReplicated(
          ReplicationDirection.push,
          [
            ReplicatedDocument(doc.id, {}, null),
          ],
        )),
      );

      await replicator.start();
    });
  });
}
