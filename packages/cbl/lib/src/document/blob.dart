import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../fleece/encoder.dart';
import '../fleece/fleece.dart';
import '../native_object.dart';
import 'common.dart';
import 'document.dart';

late final _blobBindings = CBLBindings.instance.blobs.blob;

final _typeProperty = '@type';
final _blobType = 'blob';

final _blobDigestProperty = 'digest';
final _blobLengthProperty = 'length';
final _blobContentTypeProperty = 'content_type';

// TODO: rework BLOB design

/// A Blob contains arbitrary binary data, tagged with a MIME type.
///
/// Blobs can be arbitrarily large, and their data is loaded only on demand
/// (when the [content] or [contentStream] properties are accessed), not when
/// the [Document] is loaded. The document’s raw JSON form only contains the
/// Blob’s metadata (type, [length] and a [digest] of the data) in a small
/// object. The data itself is stored externally to the document, keyed by the
/// digest.
///
/// ## New Blobs
///
/// [length], [digest] and [properties] of new [Blob]s are not available and
/// attempting to access them will throw an [StateError].
@immutable
abstract class Blob {
  /// Creates a [Blob] with the given in-memory data.
  factory Blob.fromData(String contentType, Uint8List data) =>
      throw UnimplementedError();

  /// Creates a [Blob] with the given stream of data.
  factory Blob.fromStream(String contentType, Stream<Uint8List> stream) =>
      throw UnimplementedError();

  /// Creates a [Blob] with the contents of a file.
  factory Blob.fromFileUrl(String contentType, Uri url) =>
      throw UnimplementedError();

  /// Gets the contents of this [Blob] as a block of memory.
  ///
  /// Not recommended for very large blobs, as it may be slow and use up lots of
  /// RAM.
  ///
  /// See also:
  ///  * [contentStream] for streaming of the Blob's contents in chunks.
  Future<Uint8List> content();

  /// A stream of the content of this [Blob].
  Stream<Uint8List> contentStream();

  /// The type of content this [Blob] represents.
  ///
  /// By convention this is a MIME type.
  String? get contentType;

  /// The binary length of this [Blob].
  int get length;

  /// The cryptographic digest of this [Blob]’s [content], which uniquely
  /// identifies it.
  String get digest;

  /// The metadata associated with this [Blob].
  Map<String, dynamic> get properties;

  /// Wether a plain Dart [Map] represents a [Blob].
  static bool isBlob(Map<String, dynamic> properties) {
    if (!properties.containsKey(_blobDigestProperty) ||
        properties[_blobDigestProperty] is! String ||
        !properties.containsKey(_typeProperty) ||
        properties[_typeProperty] != _blobType ||
        !properties.containsKey(_blobContentTypeProperty) ||
        properties[_blobContentTypeProperty] is! String ||
        !properties.containsKey(_blobLengthProperty) ||
        properties[_blobLengthProperty] is! int) {
      return false;
    }
    return true;
  }
}

class BlobImpl implements Blob, FleeceEncodable {
  BlobImpl({
    required Pointer<CBLBlob> blob,
    required bool retain,
    required String debugCreator,
  }) : _blob = CblRefCountedObject(
          blob,
          release: true,
          retain: retain,
          debugName: 'Blob(creator: $debugCreator)',
        );

  final CblRefCountedObject<CBLBlob> _blob;

  @override
  Future<Uint8List> content() => _dataStreamToFuture(contentStream());

  @override
  Stream<Uint8List> contentStream() {
    // TODO
    throw UnimplementedError();
  }

  @override
  String? get contentType => _blob.keepAlive(_blobBindings.contentType);

  @override
  int get length => _blob.keepAlive(_blobBindings.length);

  @override
  String get digest => _blob.keepAlive(_blobBindings.digest);

  @override
  late final Map<String, dynamic> properties = _blob.keepAlive((pointer) {
    final decoder = FleeceDecoder();
    final properties = _blobBindings.properties(pointer);
    final loadedProperties = decoder.loadValue(properties.cast())!;
    return decoder.loadedValueToDartObject(loadedProperties)
        as Map<String, dynamic>;
  });

  @override
  void encodeTo(FleeceEncoder encoder) {
    encoder.writeDartObject(properties);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobImpl &&
          const DeepCollectionEquality().equals(properties, other.properties);

  @override
  int get hashCode => const DeepCollectionEquality().hash(properties);
}

Future<Uint8List> _dataStreamToFuture(Stream<Uint8List> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.toBytes();
}
