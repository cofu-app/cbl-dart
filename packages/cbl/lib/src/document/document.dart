import 'dart:collection';
import 'dart:ffi';

import 'package:cbl_ffi/cbl_ffi.dart';
import 'package:meta/meta.dart';

import '../fleece/containers.dart' as fl;
import '../fleece/integration/integration.dart';
import '../native_object.dart';
import '../resource.dart';
import 'array.dart';
import 'blob.dart';
import 'dictionary.dart';
import 'fragment.dart';

late final _documentBindings = CBLBindings.instance.document;
late final _mutableDocumentBindings = CBLBindings.instance.mutableDocument;

/// A Couchbase Lite document.
///
/// The [Document] is immutable.
@immutable
abstract class Document implements DictionaryInterface, Iterable<String> {
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

/// A mutable version of [Document].
abstract class MutableDocument implements Document, MutableDictionaryInterface {
  /// Creates a new [MutableDocument] with a random UUID, optionally
  /// initialized with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument([Map<String, Object?>? data]) =>
      MutableDocumentImpl.create(data: data, debugCreator: 'MutableDocument()');

  /// Creates a new [MutableDocument] with a given [id], optionally
  /// initialized with [data].
  ///
  /// {@macro cbl.MutableArray.allowedValueTypes}
  factory MutableDocument.withId(String id, [Map<String, Object?>? data]) =>
      MutableDocumentImpl.create(
        id: id,
        data: data,
        debugCreator: 'MutableDocument.withId()',
      );
}

/// The context for [MCollection]s within a [DocumentImpl].
class DocumentMContext extends MContext {
  DocumentMContext(this.document);

  /// The [DocumentImpl] to which [MCollection]s with this context belong to.
  ///
  /// It is important that [MCollection] values have a reference to the
  /// document in their context, because this ensures that the document is not
  /// garbage collected before them. Otherwise the finalizer which
  /// releases the native document would potentially be executed while
  /// a [MCollection], which relies on the documents data, stays alive.
  final DocumentImpl document;
}

class DocumentImpl with IterableMixin<String> implements Document {
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

  late final _root = doc.keepAlive((pointer) => MRoot.fromValue(
        _documentBindings.properties(pointer).cast(),
        context: DocumentMContext(this),
        isMutable: false,
      ));

  late final Dictionary _properties = _root.asNative as Dictionary;

  @override
  String get id => doc.keepAlive(_documentBindings.id);

  @override
  String? get revisionId => doc.keepAlive(_documentBindings.revisionId);

  @override
  int get sequence => doc.keepAlive(_documentBindings.sequence);

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
        doc: doc.keepAlive(_mutableDocumentBindings.mutableCopy),
        // `mutableCopy` returns a new instance with +1 ref count.
        retain: false,
        debugCreator: 'Document.toMutable()',
      );

  @override
  Iterator<String> get iterator => _properties.iterator;

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

  final _typeName = 'Document';

  @override
  String toString() => '$_typeName('
      'id: $id, '
      'revisionId: $revisionId, '
      'sequence: $sequence'
      ')';
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

  factory MutableDocumentImpl.create({
    String? id,
    Map<String, Object?>? data,
    required String debugCreator,
  }) {
    final result = MutableDocumentImpl(
      doc: _mutableDocumentBindings.createWithID(id),
      // `createWithID` returns a new instance with +1 ref count.
      retain: false,
      debugCreator: debugCreator,
    );

    if (data != null) {
      result.setData(data);
    }

    return result;
  }

  @override
  late final _root = doc.keepAlive((pointer) => MRoot.fromValue(
        _documentBindings.properties(pointer).cast(),
        context: DocumentMContext(this),
        isMutable: true,
      ));

  @override
  late final MutableDictionary _properties =
      _root.asNative as MutableDictionary;

  @override
  MutableArray? array(String key) => _properties.array(key);

  @override
  MutableDictionary? dictionary(String key) => _properties.dictionary(key);

  @override
  MutableFragment operator [](String key) => _properties[key];

  @override
  MutableDocument toMutable() => this;

  @override
  void setValue(Object? value, {required String key}) =>
      _properties.setValue(value, key: key);

  @override
  void setString(String? value, {required String key}) =>
      _properties.setString(value, key: key);

  @override
  void setInteger(int value, {required String key}) =>
      _properties.setInteger(value, key: key);

  @override
  void setFloat(double value, {required String key}) =>
      _properties.setFloat(value, key: key);

  @override
  void setNumber(num? value, {required String key}) =>
      _properties.setNumber(value, key: key);

  @override
  void setBoolean(bool value, {required String key}) =>
      _properties.setBoolean(value, key: key);

  @override
  void setDate(DateTime? value, {required String key}) =>
      _properties.setDate(value, key: key);

  @override
  void setBlob(Blob? value, {required String key}) =>
      _properties.setBlob(value, key: key);

  @override
  void setArray(Array? value, {required String key}) =>
      _properties.setArray(value, key: key);

  @override
  void setDictionary(Dictionary? value, {required String key}) =>
      _properties.setDictionary(value, key: key);

  @override
  void setData(Map<String, Object?> data) => _properties.setData(data);

  @override
  void removeValue(String key) => _properties.removeValue(key);

  /// Encodes `_properties` and sets the result as the new properties of the
  /// native `Document`.
  void flushProperties() {
    final data = _root.encode();
    final doc = fl.Doc.fromResultData(data, FLTrust.trusted);
    final dict = doc.root.asDict!;
    final mutableDict = fl.MutableDict.mutableCopy(dict);
    runKeepAlive(() => _mutableDocumentBindings.setProperties(
          this.doc.pointer.cast(),
          mutableDict.native.pointer.cast(),
        ));
  }

  @override
  final _typeName = 'MutableDocument';
}
