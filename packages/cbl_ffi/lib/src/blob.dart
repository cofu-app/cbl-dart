import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'base.dart';
import 'bindings.dart';
import 'database.dart';
import 'fleece.dart';
import 'utils.dart';

// === CBLBlob =================================================================

class CBLBlob extends Opaque {}

typedef FLDict_IsBlob_C = Int8 Function(Pointer<FLDict> dict);
typedef FLDict_IsBlob = int Function(Pointer<FLDict> dict);

typedef FLDict_GetBlob = Pointer<CBLBlob> Function(Pointer<FLDict> dict);

typedef CBLBlob_Length_C = Uint64 Function(Pointer<CBLBlob> blob);
typedef CBLBlob_Length = int Function(Pointer<CBLBlob> blob);

typedef CBLDart_CBLBlob_Digest = FLString Function(Pointer<CBLBlob> blob);

typedef CBLDart_CBLBlob_ContentType = FLString Function(Pointer<CBLBlob> blob);

typedef CBLBlob_Properties = Pointer<FLDict> Function(Pointer<CBLBlob> blob);

typedef FLSlot_SetBlob_C = Void Function(
  Pointer<FLSlot> slot,
  Pointer<CBLBlob> blob,
);
typedef FLSlot_SetBlob = void Function(
  Pointer<FLSlot> slot,
  Pointer<CBLBlob> blob,
);

class BlobBindings extends Bindings {
  BlobBindings(Bindings parent) : super(parent) {
    _isBlob = libs.cbl.lookupFunction<FLDict_IsBlob_C, FLDict_IsBlob>(
      'FLDict_IsBlob',
    );
    _getBlob = libs.cbl.lookupFunction<FLDict_GetBlob, FLDict_GetBlob>(
      'FLDict_GetBlob',
    );
    _length = libs.cbl.lookupFunction<CBLBlob_Length_C, CBLBlob_Length>(
      'CBLBlob_Length',
    );
    _digest = libs.cblDart
        .lookupFunction<CBLDart_CBLBlob_Digest, CBLDart_CBLBlob_Digest>(
      'CBLDart_CBLBlob_Digest',
    );
    _contentType = libs.cblDart.lookupFunction<CBLDart_CBLBlob_ContentType,
        CBLDart_CBLBlob_ContentType>(
      'CBLDart_CBLBlob_ContentType',
    );
    _properties =
        libs.cbl.lookupFunction<CBLBlob_Properties, CBLBlob_Properties>(
      'CBLBlob_Properties',
    );
    _setBlob = libs.cbl.lookupFunction<FLSlot_SetBlob_C, FLSlot_SetBlob>(
      'FLSlot_SetBlob',
    );
  }

  late final FLDict_IsBlob _isBlob;
  late final FLDict_GetBlob _getBlob;
  late final FLSlot_SetBlob _setBlob;
  late final CBLBlob_Length _length;
  late final CBLDart_CBLBlob_Digest _digest;
  late final CBLDart_CBLBlob_ContentType _contentType;
  late final CBLBlob_Properties _properties;

  bool isBlob(Pointer<FLDict> dict) {
    return _isBlob(dict).toBool();
  }

  Pointer<CBLBlob>? getBlob(Pointer<FLDict> dict) {
    return _getBlob(dict).toNullable();
  }

  void setBlob(Pointer<FLSlot> slot, Pointer<CBLBlob> blob) {
    _setBlob(slot, blob);
  }

  int length(Pointer<CBLBlob> blob) {
    return _length(blob);
  }

  String digest(Pointer<CBLBlob> blob) {
    return _digest(blob).toDartString()!;
  }

  String? contentType(Pointer<CBLBlob> blob) {
    return _contentType(blob).toDartString();
  }

  Pointer<FLDict> properties(Pointer<CBLBlob> blob) {
    return _properties(blob);
  }
}

// === CBLBlobReadStream =======================================================

class CBLBlobReadStream extends Opaque {}

typedef CBLBlob_OpenContentStream = Pointer<CBLBlobReadStream> Function(
  Pointer<CBLBlob> blob,
  Pointer<CBLError> errorOut,
);

typedef CBLDart_CBLBlobReader_Read_C = Uint64 Function(
  Pointer<CBLBlobReadStream> stream,
  Pointer<Uint8> buf,
  Uint64 bufSize,
  Pointer<CBLError> errorOut,
);
typedef CBLDart_CBLBlobReader_Read = int Function(
  Pointer<CBLBlobReadStream> stream,
  Pointer<Uint8> buf,
  int bufSize,
  Pointer<CBLError> errorOut,
);

typedef CBLBlobReader_Close_C = Void Function(
  Pointer<CBLBlobReadStream> stream,
);
typedef CBLBlobReader_Close = void Function(
  Pointer<CBLBlobReadStream> stream,
);

class BlobStreamBuffer {
  BlobStreamBuffer._(int size)
      : _size = size,
        _bufferAddress = malloc<Uint8>(size).address;

  final int _bufferAddress;
  final int _size;
  int? _length;

  Pointer<Uint8> get _pointer => _bufferAddress.toPointer();

  Uint8List get bytes {
    assert(_length != null, 'no data has been read into buffer');
    return _pointer.asTypedList(_length!);
  }

  void _dispose() => malloc.free(_pointer);
}

class BlobReadStreamBindings extends Bindings {
  BlobReadStreamBindings(Bindings parent) : super(parent) {
    _openContentStream = libs.cbl
        .lookupFunction<CBLBlob_OpenContentStream, CBLBlob_OpenContentStream>(
      'CBLBlob_OpenContentStream',
    );
    _read = libs.cblDart.lookupFunction<CBLDart_CBLBlobReader_Read_C,
        CBLDart_CBLBlobReader_Read>(
      'CBLDart_CBLBlobReader_Read',
    );
    _close =
        libs.cblDart.lookupFunction<CBLBlobReader_Close_C, CBLBlobReader_Close>(
      'CBLBlobReader_Close',
    );
  }

  late final CBLBlob_OpenContentStream _openContentStream;
  late final CBLDart_CBLBlobReader_Read _read;
  late final CBLBlobReader_Close _close;

  final _readStreamBuffers = <int, BlobStreamBuffer>{};

  Pointer<CBLBlobReadStream> openContentStream(
    Pointer<CBLBlob> blob,
    int bufferSize,
  ) {
    final stream = _openContentStream(blob, globalCBLError).checkCBLError();
    _readStreamBuffers[stream.address] = BlobStreamBuffer._(bufferSize);
    return stream;
  }

  BlobStreamBuffer? read(Pointer<CBLBlobReadStream> stream) {
    final buffer = _readStreamBuffers[stream.address]!;

    final result = _read(
      stream,
      buffer._pointer,
      buffer._size,
      globalCBLError,
    );

    //  A result of -1 signals an error.
    if (result == -1) {
      checkCBLError();
    } else {
      buffer._length = result;
    }

    // If 0 bytes were read there are no more byte to read.
    return buffer._length == 0 ? null : buffer;
  }

  void close(Pointer<CBLBlobReadStream> stream) {
    _readStreamBuffers.remove(stream.address)!._dispose();
    _close(stream);
  }
}

// === CBLBlobWriteStream ======================================================

class CBLBlobWriteStream extends Opaque {}

typedef CBLBlobWriter_Create = Pointer<CBLBlobWriteStream> Function(
  Pointer<CBLDatabase> db,
  Pointer<CBLError> errorOut,
);

typedef CBLBlobWriter_Close_C = Void Function(
  Pointer<CBLBlobWriteStream> stream,
);
typedef CBLBlobWriter_Close = void Function(
  Pointer<CBLBlobWriteStream> stream,
);

typedef CBLBlobWriter_Write_C = Uint8 Function(
  Pointer<CBLBlobWriteStream> stream,
  Pointer<Uint8> buf,
  Uint64 bufSize,
  Pointer<CBLError> errorOut,
);
typedef CBLBlobWriter_Write = int Function(
  Pointer<CBLBlobWriteStream> stream,
  Pointer<Uint8> buf,
  int bufSize,
  Pointer<CBLError> errorOut,
);

typedef CBLDart_CBLBlob_CreateWithStream = Pointer<CBLBlob> Function(
  FLString contentType,
  Pointer<CBLBlobWriteStream> stream,
);

class BlobWriteStreamBindings extends Bindings {
  BlobWriteStreamBindings(Bindings parent) : super(parent) {
    _create =
        libs.cbl.lookupFunction<CBLBlobWriter_Create, CBLBlobWriter_Create>(
      'CBLBlobWriter_Create',
    );
    _close =
        libs.cbl.lookupFunction<CBLBlobWriter_Close_C, CBLBlobWriter_Close>(
      'CBLBlobWriter_Close',
    );
    _write =
        libs.cbl.lookupFunction<CBLBlobWriter_Write_C, CBLBlobWriter_Write>(
      'CBLBlobWriter_Write',
    );
    _createBlobWithStream = libs.cblDart.lookupFunction<
        CBLDart_CBLBlob_CreateWithStream, CBLDart_CBLBlob_CreateWithStream>(
      'CBLDart_CBLBlob_CreateWithStream',
    );
  }

  late final CBLBlobWriter_Create _create;
  late final CBLBlobWriter_Close _close;
  late final CBLBlobWriter_Write _write;
  late final CBLDart_CBLBlob_CreateWithStream _createBlobWithStream;

  Pointer<CBLBlobWriteStream> create(Pointer<CBLDatabase> db) {
    return _create(db, globalCBLError).checkCBLError();
  }

  void close(Pointer<CBLBlobWriteStream> stream) {
    _close(stream);
  }

  bool write(Pointer<CBLBlobWriteStream> stream, Uint8List buf) {
    final nativeBuf = malloc<Uint8>(buf.length);
    nativeBuf.asTypedList(buf.length).setAll(0, buf);
    try {
      return _write(stream, nativeBuf, buf.length, globalCBLError)
          .checkCBLError()
          .toBool();
    } finally {
      malloc.free(nativeBuf);
    }
  }

  Pointer<CBLBlob> createBlobWithStream(
    String? contentType,
    Pointer<CBLBlobWriteStream> stream,
  ) {
    return stringTable.autoFree(() {
      return _createBlobWithStream(
        stringTable.flString(contentType).ref,
        stream,
      );
    });
  }
}

// === BlobsBindings ===========================================================

class BlobsBindings extends Bindings {
  BlobsBindings(Bindings parent) : super(parent) {
    blob = BlobBindings(this);
    readStream = BlobReadStreamBindings(this);
    writeStream = BlobWriteStreamBindings(this);
  }

  late final BlobBindings blob;
  late final BlobReadStreamBindings readStream;
  late final BlobWriteStreamBindings writeStream;
}
