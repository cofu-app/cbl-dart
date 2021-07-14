import 'dart:collection';
import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';

import '../native_object.dart';
import 'array.dart';
import 'blob.dart';
import 'dictionary.dart';
import 'fragment.dart';

late final _bindings = CBLBindings.instance.document;
late final _mutableBindings = CBLBindings.instance.mutableDocument;

/// A Couchbase Lite document.
///
/// The [Document] is immutable.
abstract class Document
    implements DictionaryInterface, Iterable<MapEntry<String, Object?>> {
  /// The document’s id.
  String get id;

  /// The id representing the document’s revision.
  String? get revisionId;

  /// Sequence number of the document in the database.
  ///
  /// This indicates how recently the document has been changed: every time any
  /// document is updated, the database assigns it the next sequential sequence
  /// number. Thus, if a document’s sequence property changes that means it’s
  /// been changed (on-disk); and if one document’s sequence is greater than
  /// another’s, that means it was changed more recently.
  int get sequence;

  /// Returns a mutable copy of the document.
  MutableDocument toMutable();
}

class DocumentImpl
    with IterableMixin<MapEntry<String, Object?>>
    implements Document {
  DocumentImpl({
    required Pointer<CBLDocument> doc,
    required bool retain,
    required String debugCreator,
  }) : this._(
          doc: doc,
          retain: retain,
          debugName: 'Document(creator: $debugCreator)',
        );

  DocumentImpl._({
    required Pointer<CBLDocument> doc,
    required bool retain,
    required String debugName,
  }) : doc = CblRefCountedObject(
          doc,
          release: true,
          retain: retain,
          debugName: debugName,
        );

  final NativeObject<CBLDocument> doc;

  late final Dictionary _properties;

  @override
  String get id => doc.keepAlive(_bindings.id);

  @override
  String? get revisionId => doc.keepAlive(_bindings.revisionId);

  @override
  int get sequence => doc.keepAlive(_bindings.sequence);

  @override
  int get length => _properties.length;

  @override
  List<String> get keys => _properties.keys;

  @override
  Object? value(String key) => _properties.value(key);

  @override
  String? string(String key) => _properties.string(key);

  @override
  int integer(String key) => _properties.integer(key);

  @override
  double float(String key) => _properties.float(key);

  @override
  num? number(String key) => _properties.number(key);

  @override
  bool boolean(String key) => _properties.boolean(key);

  @override
  DateTime? date(String key) => _properties.date(key);

  @override
  Blob? blob(String key) => _properties.blob(key);

  @override
  Array? array(String key) => _properties.array(key);

  @override
  Dictionary? dictionary(String key) => _properties.dictionary(key);

  @override
  Fragment operator [](String key) => _properties[key];

  @override
  Map<String, dynamic> toMap() => _properties.toMap();

  @override
  MutableDocument toMutable() => MutableDocumentImpl(
        doc: doc.keepAlive(_mutableBindings.mutableCopy),
        retain: false,
        debugCreator: 'Document.toMutable()',
      );

  @override
  Iterator<MapEntry<String, Object?>> get iterator => _properties.iterator;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentImpl &&
          id == other.id &&
          revisionId == other.revisionId &&
          sequence == other.sequence &&
          _properties == other._properties;

  @override
  int get hashCode =>
      id.hashCode ^
      revisionId.hashCode ^
      sequence.hashCode ^
      _properties.hashCode;
}

/// A mutable version of [Document].
abstract class MutableDocument implements Document, MutableDictionaryInterface {
  /// Creates a new [MutableDocument] with a random UUID, optionally
  /// initialized with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument([Map<String, Object?>? data]) =>
      throw UnimplementedError();

  /// Creates a new [MutableDocument] with a given [id], optionally
  /// initialized with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument.withId(String id, [Map<String, Object?>? data]) =>
      throw UnimplementedError();
}

class MutableDocumentImpl extends DocumentImpl implements MutableDocument {
  MutableDocumentImpl({
    required Pointer<CBLMutableDocument> doc,
    required bool retain,
    required String debugCreator,
  }) : super._(
          doc: doc.cast(),
          retain: retain,
          debugName: 'MutableDocument(creator: $debugCreator)',
        );
}
