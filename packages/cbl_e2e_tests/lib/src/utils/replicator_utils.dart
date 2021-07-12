import 'package:cbl/cbl.dart';

import '../test_binding.dart';
import 'database_utils.dart';

final testSyncGatewayUrl = Uri.parse('ws://localhost:4984/db');

extension ReplicatorUtilsDatabaseExtension on Database {
  /// Creates a replicator which is configured with the test sync gateway
  /// endpoint.
  Future<Replicator> createTestReplicator({
    ReplicatorType? replicatorType,
    bool? continuous,
    List<String>? channels,
    List<String>? documentIds,
    ReplicationFilter? pushFilter,
    ReplicationFilter? pullFilter,
    ConflictResolver? conflictResolver,
  }) =>
      createReplicator(ReplicatorConfiguration(
        endpoint: UrlEndpoint(testSyncGatewayUrl),
        replicatorType: replicatorType,
        continuous: continuous,
        channels: channels,
        documentIds: documentIds,
        pushFilter: pushFilter,
        pullFilter: pullFilter,
        conflictResolver: conflictResolver,
      ));
}

extension ReplicatorUtilsExtension on Replicator {
  /// Starts this replicator and waits until it stops. If it stops with an
  /// error, that error is thrown.
  Future<void> startAndWaitUntilStopped() async {
    var lastStatus = await status();
    if (lastStatus.activity != ReplicatorActivityLevel.stopped) {
      throw StateError('Expected replicator to be stopped');
    }

    final stopped = statusChanges().firstWhere((status) {
      return status.error != null ||
          status.activity == ReplicatorActivityLevel.stopped;
    });

    await start();

    lastStatus = await stopped;

    final error = lastStatus.error;
    if (error != null) {
      throw error;
    }
  }
}

/// Clears the db of the test server by first pulling all documents into a local
/// db, deleting them and then pushing the changes to the server db.
Future<void> clearTestServerDb() async {
  final db = await openTestDb('ClearTestServer', autoClose: false);
  addTearDown(db.delete);

  final pullReplicator =
      await db.createTestReplicator(replicatorType: ReplicatorType.pull);

  await pullReplicator.startAndWaitUntilStopped();

  final didDeleteDocuments = await db.deleteAllDocuments();

  if (didDeleteDocuments) {
    final pushReplicator =
        await db.createTestReplicator(replicatorType: ReplicatorType.push);
    await pushReplicator.startAndWaitUntilStopped();
  }
}
