import 'dart:async';
import 'dart:convert';

import 'package:cbl/src/fleece/decoder.dart';
import 'package:cbl/src/fleece/encoder.dart';
import 'package:cbl/src/fleece/slice.dart';
import 'package:cbl_ffi/cbl_ffi.dart';

import '../../test_binding_impl.dart';
import '../fixtures/large_json_doc.dart';
import '../test_binding.dart';
import '../utils/benchmark.dart';

void main() {
  setupTestBinding();

  group('Fleece Decoding', () {
    test('SharedStrings should only cache strings encoded as shared strings',
        () {
      final encoder = FleeceEncoder();
      final decoder = FleeceDecoder();
      final data = encoder
          .convertJson('[".", "..", "...............", "................"]');
      final root = decoder.loadValueFromData(data)!;
      decoder.loadedValueToDartObject(root);

      expect(decoder.sharedStrings.hasString('.'), isFalse);
      expect(decoder.sharedStrings.hasString('..'), isTrue);
      expect(decoder.sharedStrings.hasString('...............'), isTrue);
      expect(decoder.sharedStrings.hasString('................'), isFalse);
    });

    test('Decoding Benchmark', () {
      return runBenchmarks(
        [
          JsonInDartDecodingBenchmark(),
          FleeceDecodingBenchmark(),
        ],
        repetitions: 250,
      );
    });

    group('FleeceDecoder', () {
      test('dumpData shows the internal structure of Fleece data', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('{"a": true}');

        expect(
          decoder.dumpData(data),
          '''
 0000: 70 01       : Dict {
 0002: 41 61       :   "a":
 0004: 38 00       :     true }
 0006: 80 03       : &Dict @0000
''',
        );
      });

      test('loadValueFromData returns root value from data', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('[]');

        expect(
          decoder.loadValueFromData(data),
          isA<CollectionFLValue>()
              .having((it) => it.isArray, 'isArray', true)
              .having((it) => it.length, 'length', 0),
        );
      });

      test('loadValueFromData returns null when the data is invalid', () {
        final decoder = FleeceDecoder();
        final data = SliceResult(0);
        expect(decoder.loadValueFromData(data), isNull);
      });

      test('loadValue returns loaded value for given FLValue', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('[]');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;
        expect(decoder.loadValue(root.value), root);
      });

      test('loadValueFromArray returns loaded value at index', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('[true]');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;
        final value = decoder.loadValueFromArray(root.value.cast(), 0);
        expect(value, SimpleFLValue(true));
      });

      test('loadValueFromArray returns null if index is out of bounds', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('[]');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;
        final value = decoder.loadValueFromArray(root.value.cast(), 0);
        expect(value, isNull);
      });

      test('loadValueFromDict returns loaded value for key', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('{"a": true}');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;
        final value = decoder.loadValueFromDict(root.value.cast(), 'a');
        expect(value, SimpleFLValue(true));
      });

      test('loadValueFromDict returns null if entry for key does not exits',
          () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('{}');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;
        final value = decoder.loadValueFromDict(root.value.cast(), 'a');
        expect(value, isNull);
      });

      test('loadedValueToDartObject returns Dart object of value', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('''
[
  null, 41, 3.14, true, false, "a", 
  {
    "a": null,
    "b": 41, 
    "c": 3.14, 
    "d": true, 
    "e": false, 
    "f": 
    "a", 
    "g": {}, 
    "h":[]
  }, 
  []
]
''');
        final root = decoder.loadValueFromData(data)!;
        expect(decoder.loadedValueToDartObject(root), [
          null,
          41,
          3.14,
          true,
          false,
          'a',
          {
            'a': null,
            'b': 41,
            'c': 3.14,
            'd': true,
            'e': false,
            'f': 'a',
            'g': <String, dynamic>{},
            'h': <dynamic>[]
          },
          <dynamic>[],
        ]);
      });

      test('dictIterable iterates over keys and values of dict', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('{"a": true, "b": null, "c": 3.14}');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;

        expect(
          Map.fromEntries(decoder.dictIterable(root.value.cast())),
          {
            'a': SimpleFLValue(true),
            'b': SimpleFLValue(null),
            'c': SimpleFLValue(3.14),
          },
        );
      });

      test('dictKeyIterable iterates over keys of dict', () {
        final encoder = FleeceEncoder();
        final decoder = FleeceDecoder();
        final data = encoder.convertJson('{"a": null, "b": null, "c": null}');
        final root = decoder.loadValueFromData(data)! as CollectionFLValue;

        expect(
          decoder.dictKeyIterable(root.value.cast()),
          ['a', 'b', 'c'],
        );
      });
    });
  });

  group('Fleece Encoding', () {
    test('convert JSON to Fleece data', () {
      final encoder = FleeceEncoder();
      final decoder = FleeceDecoder();
      final data = encoder.convertJson(
        '''
        {
          "a": true, 
          "foo": [true, false, null, 43, 43, 1.3, 1.3, "foo"], 
          "buz": 1.3, 
          "bzz": 1.3
        }
        ''',
      );
      final value = decoder.loadValueFromData(data) as CollectionFLValue;

      expect(
        decoder.loadedValueToDartObject(value),
        {
          'a': true,
          'buz': 1.3,
          'bzz': 1.3,
          'foo': [true, false, null, 43, 43, 1.3, 1.3, 'foo']
        },
      );
    });

    group('FleeceEncoder', () {
      test('writeDartObject writes Dart object to encoder', () {
        final decoder = FleeceDecoder();
        final encoder = FleeceEncoder()
          ..writeDartObject([
            null,
            true,
            false,
            41,
            3.14,
            'a',
            <dynamic>[true],
            {'a': true},
            {true}
          ]);

        final root = decoder.loadValueFromData(encoder.finish())!;

        expect(decoder.loadedValueToDartObject(root), [
          null,
          true,
          false,
          41,
          3.14,
          'a',
          <dynamic>[true],
          {'a': true},
          [true]
        ]);
      });

      test('writeLoadedValue writes loaded value to encoder', () {
        final decoder = FleeceDecoder();
        final encoder = FleeceEncoder()..writeDartObject([true, 'a']);
        final array =
            decoder.loadValueFromData(encoder.finish()) as CollectionFLValue;
        final simpleValue = decoder.loadValueFromArray(array.value.cast(), 0)!;
        final sliceValue = decoder.loadValueFromArray(array.value.cast(), 1)!;

        encoder.reset();
        encoder.beginArray(3);
        encoder.writeLoadedValue(array);
        encoder.writeLoadedValue(simpleValue);
        encoder.writeLoadedValue(sliceValue);
        encoder.endArray();

        expect(decoder.dataToDartObject(encoder.finish()), [
          [true, 'a'],
          true,
          'a'
        ]);
      });

      test('write values', () {
        final decoder = FleeceDecoder();
        final encoder = FleeceEncoder();

        encoder.beginArray(0);
        encoder.writeNull();
        encoder.writeBool(true);
        encoder.writeBool(false);
        encoder.writeInt(41);
        encoder.writeDouble(3.14);
        encoder.writeString('a');
        encoder.beginArray(0);
        encoder.endArray();
        encoder.beginDict(0);
        encoder.writeKey('a');
        encoder.writeBool(true);
        encoder.endDict();
        encoder.endArray();

        final data = encoder.finish();
        final root = decoder.loadValueFromData(data)!;

        expect(
          decoder.loadedValueToDartObject(root),
          [
            null,
            true,
            false,
            41,
            3.14,
            'a',
            <dynamic>[],
            {'a': true}
          ],
        );
      });
    });
  });
}

abstract class DecodingBenchmark extends Benchmark {
  DecodingBenchmark(String description) : super('Decoding: $description');

  late final jsonString = largeJsonDoc;

  late final dynamic _expectedResult = jsonDecode(jsonString);

  dynamic result;

  @override
  FutureOr<void> validate() {
    expect(result, _expectedResult);
  }
}

class JsonInDartDecodingBenchmark extends DecodingBenchmark {
  JsonInDartDecodingBenchmark() : super('JSON (in Dart)');

  late JsonDecoder _decoder;

  @override
  FutureOr<void> setUp() {
    _decoder = JsonDecoder();
  }

  @override
  FutureOr<void> run() {
    result = _decoder.convert(jsonString);
  }
}

class FleeceDecodingBenchmark extends DecodingBenchmark {
  FleeceDecodingBenchmark() : super('Fleece');

  late FleeceDecoder _decoder;

  late final SliceResult data = FleeceEncoder().convertJson(jsonString);

  @override
  FutureOr<void> setUp() {
    _decoder = FleeceDecoder();
  }

  @override
  FutureOr<void> run() {
    final value = _decoder.loadValueFromData(data, trust: FLTrust.trusted)!;
    result = _decoder.loadedValueToDartObject(value);
  }
}
