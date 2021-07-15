import 'dart:math';
import 'dart:typed_data';

// TODO: update Blob tests.

// import 'package:cbl/cbl.dart';
// import 'package:cbl/src/utils.dart';

// import '../test_binding_impl.dart';
// import 'test_binding.dart';
// import 'utils/database_utils.dart';

void main() {
  // setupTestBinding();

  // group('Blob', () {
  //   late Database db;

  //   setUpAll(() async {
  //     db = await openTestDb('Blob-Common');
  //   });

  //   group('Blob', () {
  //     test('length returns the content length', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(content);

  //       expect(blob.length, content.length);
  //     });

  //     test('digest returns the content hash', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(content);

  //       expect(blob.digest, startsWith('sha1-4SnyfFEDvFzES83woV4WDURQZv8='));
  //     });

  //     test('contentType returns null when none exists', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(content);

  //       expect(blob.contentType, isNull);
  //     });

  //     test('contentType returns the value given at creation', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(
  //         content,
  //         contentType: 'application/octet-stream',
  //       );

  //       expect(blob.contentType, 'application/octet-stream');
  //     });

  //     test('properties returns all the properties of the Blob', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(
  //         content,
  //         contentType: 'application/octet-stream',
  //       );

  //       final myData = {'a': 9, 'c': true};

  //       blob.properties['myData'] = myData;

  //       expect(
  //         blob.properties.toObject(),
  //         {
  //           '@type': 'blob',
  //           'content_type': blob.contentType,
  //           'digest': blob.digest,
  //           'length': blob.length,
  //           'myData': myData,
  //         },
  //       );
  //     });
  //   });

  //   group('Value', () {
  //     test('isBlob should return true if Value is blob', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(content);

  //       final dict = MutableDict({'blob': blob});

  //       expect(dict['blob'].asDict!.isBlob, isTrue);
  //     });

  //     test('asBlob should return a Blob if the value is a Blob', () async {
  //       final content = Uint8List(16);
  //       final blob = await db.blobManager.createBlob(content);

  //       final doc = MutableDocument()..properties.addAll({'blob': blob});

  //       final savedDoc = await db.saveDocument(doc);

  //       expect(savedDoc.properties['blob'].asDict!.asBlob, isA<Blob>());
  //     });

  //     test('asBlob should return null if value is not a Blob', () async {
  //       final doc = MutableDocument()
  //         ..properties.addAll({'blob': <String, Object>{}});

  //       expect(doc.properties['blob'].asDict!.asBlob, isNull);
  //     });
  //   });

  //   group('BlobWriteStream', () {
  //     Future<void> blobWriteStreamTestCase(
  //         List<List<Uint8List>> streams) async {
  //       final stream = await db.blobManager.openWriteStream();

  //       for (final inputStream in streams) {
  //         await stream.addStream(Stream.fromIterable(inputStream));
  //       }

  //       final blob = await stream.createBlob();
  //       final mergedInput =
  //           jointUint8Lists(streams.map((e) => jointUint8Lists(e)).toList());

  //       expect(blob.length, mergedInput.length);

  //       final doc =
  //           await db.saveDocument(MutableDocument()..properties['blob'] = blob);

  //       final content =
  //           await db.blobManager.blobContent(doc.properties['blob'].asBlob!);

  //       expect(content, mergedInput);
  //     }

  //     test('empty Blob', () => blobWriteStreamTestCase([]));

  //     test('add empty stream', () => blobWriteStreamTestCase([[]]));

  //     test(
  //       'add stream with one chunk',
  //       () => blobWriteStreamTestCase([
  //         [
  //           Uint8List.fromList([1, 2, 3])
  //         ]
  //       ]),
  //     );

  //     test(
  //       'add stream with two chunks',
  //       () => blobWriteStreamTestCase([
  //         [
  //           Uint8List.fromList([1, 2, 3]),
  //           Uint8List.fromList([4, 5, 6]),
  //         ]
  //       ]),
  //     );

  //     test(
  //       'add two streams with one chunk each',
  //       () => blobWriteStreamTestCase([
  //         [
  //           Uint8List.fromList([1, 2, 3])
  //         ],
  //         [
  //           Uint8List.fromList([4, 5, 6]),
  //         ]
  //       ]),
  //     );

  //     test(
  //       'add two streams with two chunk each',
  //       () => blobWriteStreamTestCase([
  //         [
  //           Uint8List.fromList([1, 2, 3]),
  //           Uint8List.fromList([4, 5, 6]),
  //         ],
  //         [
  //           Uint8List.fromList([7, 8, 9]),
  //           Uint8List.fromList([10, 11, 12]),
  //         ]
  //       ]),
  //     );

  //     test('create Blob with contentType', () async {
  //       final stream = await db.blobManager.openWriteStream();
  //       final blob = await stream.createBlob(contentType: 'a');

  //       expect(blob.contentType, 'a');
  //     });

  //     test('close stream without creating a Blog does not throw', () async {
  //       final stream = await db.blobManager.openWriteStream();
  //       await stream.addStream(Stream.value(Uint8List(16)));
  //       await stream.close();
  //     });
  //   });

  //   group('BlobReadStream', () {
  //     test('loadBlobContent returns whole blob in one chunk', () async {
  //       final stream = await db.blobManager.openWriteStream();
  //       final content = randomizedUint8List(20000);

  //       await stream.addStream(Stream.value(content));
  //       final blob = await stream.createBlob();

  //       final doc = MutableDocument()..properties['blob'] = blob;
  //       final savedDoc = await db.saveDocument(doc);

  //       expect(
  //         db.blobManager.blobContent(savedDoc.properties['blob'].asBlob!),
  //         completion(content),
  //       );
  //     });

  //     test('emits chunks of requested size', () async {
  //       final stream = await db.blobManager.openWriteStream();
  //       final content = randomizedUint8List(50);

  //       await stream.addStream(Stream.value(content));
  //       final blob = await stream.createBlob();

  //       final doc = MutableDocument()..properties['blob'] = blob;
  //       final savedDoc = await db.saveDocument(doc);

  //       final readStream = await db.blobManager
  //           .readStream(
  //             savedDoc.properties['blob'].asBlob!,
  //             chunkSize: 20,
  //           )
  //           .toList();

  //       expect(readStream[0], content.sublist(0, 20));
  //       expect(readStream[1], content.sublist(20, 40));
  //       expect(readStream[2], content.sublist(40, 50));
  //     });
  //   });
  // });
}

Uint8List randomizedUint8List(int size) {
  final random = Random.secure();
  return Uint8List.fromList(
      List.generate(size, (index) => random.nextInt(255)));
}
