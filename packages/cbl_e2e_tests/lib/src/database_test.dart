import 'package:cbl/cbl.dart';
import 'package:rxdart/rxdart.dart';

import '../test_binding_impl.dart';
import 'test_binding.dart';
import 'utils/database_utils.dart';
import 'utils/matchers.dart';

void main() {
  setupTestBinding();

  group('Database', () {
    group('exists', () {
      test('works with inDirectory', () async {
        final dbName = testDbName('DatabaseExistsWithDir');

        expect(
          await Database.exists(dbName, directory: tmpDir),
          isFalse,
        );

        final db = await Database.open(
          dbName,
          config: DatabaseConfiguration(directory: tmpDir),
        );
        await db.close();

        expect(
          await Database.exists(dbName, directory: tmpDir),
          isTrue,
        );
      });
    });

    group('open', () {
      test('creates database if it does not exist', () async {
        final db = await Database.open(
          testDbName('OpenNonExistingDatabase'),
          config: DatabaseConfiguration(
            directory: tmpDir,
          ),
        );

        expect(db.path, completion(isDirectory));
      });
    });

    late String dbName;
    late DatabaseConfiguration dbConfig;
    late Database db;

    setUpAll(() async {
      dbName = testDbName('Common');
      dbConfig = DatabaseConfiguration(directory: tmpDir);
      db = await Database.open(dbName, config: dbConfig);
      addTearDown(db.close);
    });

    group('Database', () {
      test('name returns name of Database', () {
        expect(db.name, completion(equals(dbName)));
      });

      test('path returns full path of Database', () {
        expect(db.path, completion(equals('$tmpDir/$dbName.cblite2/')));
      });

      test('config returns config of Database', () {
        expect(db.config, completion(equals(dbConfig)));
      });

      test('close does not throw', () async {
        final db = await Database.open(
          testDbName('CloseDatabase'),
          config: dbConfig,
        );

        await db.close();
      });

      test('delete deletes the database file', () async {
        final name = testDbName('DeleteDatabase');
        final db = await Database.open(name, config: dbConfig);

        await db.delete();

        expect(
          Database.exists(name, directory: dbConfig.directory!),
          completion(isFalse),
        );
      });

      test('performMaintenance: compact', () async {
        await db.performMaintenance(MaintenanceType.compact);
      });

      test('performMaintenance: reindex', () async {
        final db = await openTestDb('PerformMaintenance|Reindex');
        await db.createIndex('a', ValueIndex('[".type"]'));
        final doc = MutableDocument({'type': 'A'});
        await db.saveDocument(doc);
        await db.performMaintenance(MaintenanceType.reindex);
      });

      test('performMaintenance: integrityCheck', () async {
        await db.performMaintenance(MaintenanceType.integrityCheck);
      });

      test('batch operations do not throw', () async {
        await db.beginBatch();
        await db.saveDocument(MutableDocument());
        await db.endBatch();
      });

      test('getDocument returns null when the document does not exist',
          () async {
        expect(db.getDocument('x'), completion(isNull));
      });

      test('getDocument returns the document when it exist', () async {
        final doc = await db.saveDocument(MutableDocument());
        final loadedDoc = await db.getDocument(doc.id);
        expect(loadedDoc, doc);
      });

      test('getMutableDocument returns null when the document does not exist',
          () async {
        expect(db.getMutableDocument('x'), completion(isNull));
      });

      test('getMutableDocument returns the document when it exist', () async {
        final doc = await db.saveDocument(MutableDocument());
        final result = await db.getMutableDocument(doc.id);
        expect(result!.id, equals(doc.id));
      });

      test('saveDocument saves the document', () async {
        final doc = MutableDocument({'a': 'b', 'c': 4});

        final savedDoc = await db.saveDocument(doc);

        expect(savedDoc.toMap(), equals(doc.toMap()));
      });

      test('saveDocumentResolving invokes the callback on conflict', () async {
        final versionA = await db.saveDocument(MutableDocument());
        final versionB = await db
            .saveDocument(versionA.toMutable()..setValue('b', key: 'a'));

        await db.saveDocumentResolving(
          versionA.toMutable(),
          expectAsync2((documentBeingSaved, conflictingDocument) async {
            expect(documentBeingSaved, equals(versionA));
            expect(conflictingDocument, equals(versionB));
            return true;
          }),
        );
      });

      test('saveDocumentResolving cancels save if handler returns false',
          () async {
        final versionA = await db.saveDocument(MutableDocument());
        final versionB = await db
            .saveDocument(versionA.toMutable()..setValue('b', key: 'a'));

        expect(
          db.saveDocumentResolving(
            versionA.toMutable(),
            expectAsync2((documentBeingSaved, conflictingDocument) async {
              expect(documentBeingSaved, equals(versionA));
              expect(conflictingDocument, equals(versionB));
              return false;
            }),
          ),
          throwsA(isA<CouchbaseLiteException>().having(
            (it) => it.code,
            'code',
            equals(CouchbaseLiteErrorCode.conflict),
          )),
        );
      });

      test('deleteDocument should remove document from the database', () async {
        final doc = await db.saveDocument(MutableDocument());
        await db.deleteDocument(doc);
        expect(db.getDocument(doc.id), completion(isNull));
      });

      test('purgeDocumentById purges a document by id', () async {
        final doc = await db.saveDocument(MutableDocument());

        await db.purgeDocumentById(doc.id);

        expect(db.getDocument(doc.id), completion(isNull));
      });

      test(
          'getDocumentExpiration returns null if the document has no expiration',
          () async {
        final doc = await db.saveDocument(MutableDocument());

        expect(db.getDocumentExpiration(doc.id), completion(isNull));
      });

      test(
          'getDocumentExpiration returns the time of expiration if the document has one',
          () async {
        final expiration = DateTime.now().add(Duration(days: 1));
        final doc = await db.saveDocument(MutableDocument());

        await db.setDocumentExpiration(doc.id, expiration);

        final storedExpiration = await db.getDocumentExpiration(doc.id);

        expect(
          storedExpiration!.millisecondsSinceEpoch,
          equals(expiration.millisecondsSinceEpoch),
        );
      });

      test('setDocumentExpiration sets a new time of expiration', () async {
        final expiration = DateTime.now().add(Duration(days: 1));
        final doc = await db.saveDocument(MutableDocument());

        await db.setDocumentExpiration(doc.id, expiration);

        final storedExpiration = await db.getDocumentExpiration(doc.id);

        expect(
          storedExpiration!.millisecondsSinceEpoch,
          equals(expiration.millisecondsSinceEpoch),
        );
      });

      test('setDocumentExpiration sets the time of expiration to null',
          () async {
        final expiration = DateTime.now().add(Duration(days: 1));
        final doc = await db.saveDocument(MutableDocument());

        await db.setDocumentExpiration(doc.id, expiration);
        await db.setDocumentExpiration(doc.id, null);

        expect(db.getDocumentExpiration(doc.id), completion(isNull));
      });

      test('document change listener is called when the document changes',
          () async {
        final doc = MutableDocument();

        expect(
          db.changesOfDocument(doc.id),
          emitsInOrder(<dynamic>[null]),
        );

        await db.saveDocument(doc);
      });

      test('database change listener is called when a document changes',
          () async {
        final doc = MutableDocument();

        expect(
          db.changesOfAllDocuments(),
          emitsInOrder(<dynamic>[
            [doc.id]
          ]),
        );

        await db.saveDocument(doc);
      });
    });

    group('Document', () {
      test("id returns the document's id", () {
        final doc = MutableDocument.withId('a');

        expect(doc.id, 'a');
      });

      test('revisionId returns `null` when the document is new', () {
        final doc = MutableDocument();

        expect(doc.revisionId, isNull);
      });

      test('revisionId returns string when document has been saved', () async {
        final doc = await db.saveDocument(MutableDocument());

        expect(doc.revisionId, '1-581ad726ee407c8376fc94aad966051d013893c4');
      });

      test('sequence returns the documents sequence', () async {
        final doc = await db.saveDocument(MutableDocument());

        expect(doc.sequence, isPositive);
      });

      test('toMap returns the documents properties', () async {
        final props = {'a': 'b'};
        final doc = MutableDocument(props);

        expect(doc.toMap(), equals(props));
      });

      test('toMutable() returns a mutable copy of the document', () async {
        final doc = await db.saveDocument(MutableDocument({'a': 'b'}));

        expect(
          doc.toMutable(),
          isA<MutableDocument>().having(
            (it) => it.toMap(),
            'toMap()',
            doc.toMap(),
          ),
        );
      });
    });

    group('MutableDocument', () {
      test('supports specifying an id', () {
        final doc = MutableDocument.withId('id');

        expect(doc.id, equals('id'));
      });

      test('supports generating an id', () {
        final doc = MutableDocument();

        expect(doc.id, isNotEmpty);
      });
    });

    group('Index', () {
      late Database db;

      setUp(() async {
        db = await openTestDb('Index');
      });

      test('createIndex should work with ValueIndex', () async {
        await db.createIndex('a', ValueIndex('[[".a"]]'));

        final q = await db.query(N1QLQuery('SELECT * WHERE a = "a"'));

        final explain = await q.explain();

        expect(explain, contains('USING INDEX a'));
      });

      test('createIndex should work with FullTextIndex', () async {
        await db.createIndex('a', FullTextIndex('[[".a"]]'));

        final q = await db.query(N1QLQuery(
          "SELECT * WHERE MATCH('a', 'query')",
        ));

        final explain = await q.explain();

        expect(explain, contains('["MATCH()","a","query"]'));
      });

      test('deleteIndex should delete the given index', () async {
        await db.createIndex('a', ValueIndex('[[".a"]]'));

        expect(await db.indexNames(), equals(['a']));

        await db.deleteIndex('a');

        expect(await db.indexNames(), isEmpty);
      });

      test('indexNames should return the names of all existing indexes',
          () async {
        expect(await db.indexNames(), isEmpty);

        await db.createIndex('a', ValueIndex('[[".a"]]'));

        expect(db.indexNames(), completion(equals(['a'])));
      });
    });

    group('Query', () {
      late Database db;

      setUp(() async {
        db = await openTestDb('Query');
      });

      test('execute query with parameters', () async {
        final q =
            await db.query(N1QLQuery(r'SELECT doc WHERE META().id = $ID'));
        await db.saveDocument(MutableDocument.withId('A'));

        q.parameters.setValue('A', name: 'ID');
        expect((await q.execute()), isNotEmpty);

        q.parameters.setValue('B', name: 'ID');
        expect((await q.execute()), isEmpty);
      });

      test('listen to query with parameters', () async {
        final q =
            await db.query(N1QLQuery(r'SELECT doc WHERE META().id = $ID'));
        await db.saveDocument(MutableDocument.withId('A'));

        q.parameters.setValue('A', name: 'ID');
        expect((await q.changes().first), isNotEmpty);

        q.parameters.setValue('B', name: 'ID');
        expect((await q.changes().first), isEmpty);
      });

      test('execute does not throw', () async {
        final q = await db.query(N1QLQuery('SELECT doc'));
        expect(q.execute(), completion(isEmpty));
      });

      test('explain returns the query plan explanation', () async {
        final q = await db.query(N1QLQuery('SELECT doc'));
        final queryPlan = await q.explain();

        expect(
          queryPlan,
          allOf([
            contains('SCAN TABLE'),
            contains('{"WHAT":[[".doc"]]}'),
          ]),
        );
      });

      test('columCount returns correct count', () async {
        final q = await db.query(N1QLQuery('SELECT a'));
        expect(q.columnCount(), completion(equals(1)));
      });

      test('columnName returns correct name', () async {
        final q = await db.query(N1QLQuery('SELECT a'));
        expect(q.columnName(0), completion(equals('a')));
      });

      test('listener is notified of changes', () async {
        final q = await db.query(N1QLQuery(
          'SELECT a FROM _default AS a WHERE a.b = "c"',
        ));

        final doc = MutableDocument({'b': 'c'});
        final result = {'a': doc.toMap()};
        final stream = q
            .changes()
            .map((resultSet) =>
                resultSet.asDictionaries.map((dict) => dict.toMap()).toList())
            .shareReplay();

        // ignore: unawaited_futures
        stream.first.then((_) => db.saveDocument(doc));

        expect(
          stream,
          emitsInOrder(<dynamic>[
            isEmpty,
            [result],
          ]),
        );
      });

      test('bad query: error position highlighting', () {
        expect(
          db.query(N1QLQuery('SELECT foo()')),
          throwsA(isA<CouchbaseLiteException>().having(
            (it) => it.toString(),
            'toString()',
            '''
CouchbaseLiteException(message: query syntax error, code: CouchbaseLiteErrorCode.invalidQuery)
SELECT foo()
          ^
''',
          )),
        );
      });

      group('ResultSet', () {
        // TODO: fix bug which prevents id from being used an alias
        // The test uses id_ as a workaround.
        // https://github.com/couchbase/couchbase-lite-C/issues/149
        test('supports getting column by name', () async {
          final doc = MutableDocument.withId('ResultSetColumnByName');
          await db.saveDocument(doc);

          final q = await db.query(
              N1QLQuery(r'SELECT META().id AS id_ WHERE META().id = $ID'));
          q.parameters.setString(doc.id, name: 'ID');

          final resultSet = await q.execute();
          final iterator = resultSet.iterator..moveNext();
          expect(iterator.current['id_'] as String, doc.id);
        });

        test('supports getting column by index', () async {
          final doc = MutableDocument.withId('ResultSetColumnIndex');
          await db.saveDocument(doc);

          final q = await db
              .query(N1QLQuery(r'SELECT META().id WHERE META().id = $ID'));
          q.parameters.setString(doc.id, name: 'ID');

          final resultSet = await q.execute();
          final iterator = resultSet.iterator..moveNext();
          expect(iterator.current[0] as String, doc.id);
        });
      });
    });

    group('Scenarios', () {
      test('open the same database twice and receive change notifications',
          () async {
        final dbName = testDbName('OpenDbTwice');
        final dbA = await openTestDb(dbName, useNameDirectly: true);
        final dbB = await openTestDb(dbName, useNameDirectly: true);
        final doc = MutableDocument();

        expect(
          dbA.changesOfAllDocuments(),
          emitsInOrder(<dynamic>[
            [doc.id]
          ]),
        );

        // Streams such as `changesOfAllDocuments` are doing async work
        // when being listened to. That means we cannot assume the stream
        // is fully setup and will see changes at this point. In the context
        // of a single database this usually does not matter because all
        // resources related to that database share a single worker. A worker
        // behaves like a queue, so once a stream has been listened to, its
        // request to the worker will be handled before all other requests which
        // could affect it. In this case there are two database and two workers
        // handling requests in parallel. To prevent the doc from being saved
        // before the stream is ready, we wait a few milliseconds.
        // TODO: when streams expose a method to wait until they are fully
        // ready use that instead of this workaround
        await Future<void>.delayed(Duration(milliseconds: 50));

        await dbB.saveDocument(doc);
      });

      test('N1QL meal planner example', () async {
        await db.createIndex('date', ValueIndex('[".type"]'));
        await db.createIndex('group_index', ValueIndex('[".group"]'));

        final dish = await db.saveDocument(MutableDocument({
          'type': 'dish',
          'title': 'Lasagna',
        }));

        await db.saveDocument(MutableDocument({
          'type': 'meal',
          'dishes': [dish.id],
          'group': 'fam',
          'date': '2020-06-30',
        }));

        await db.saveDocument(MutableDocument({
          'type': 'meal',
          'dishes': [dish.id],
          'group': 'fam',
          'date': '2021-01-15',
        }));

        final q = await db.query(N1QLQuery(
          r'''
          SELECT dish, max(meal.date) AS last_used, count(meal._id) AS in_meals, meal 
          FROM _default AS dish
          JOIN _default AS meal ON array_contains(meal.dishes, dish._id)
          WHERE dish.type = "dish" AND meal.type = "meal"  AND meal.`group` = "fam"
          GROUP BY dish._id
          ORDER BY max(meal.date)
          ''',
        ));

        print(await q.explain());

        var resultSet = await q.execute();

        for (final result in resultSet.asDictionaries) {
          print(result);
        }
      });
    });
  });
}
