import 'dart:typed_data';

import 'package:cbl/cbl.dart' show FleeceErrorCode, FleeceException;
import 'package:cbl/src/fleece.dart';

import '../test_binding_impl.dart';
import 'test_binding.dart';

/// A test value which can be used to test [Value]s with [ValueType.data].
final testDataUint8List = Uint8List.fromList([1, 2, 3]);

void main() {
  setupTestBinding();

  group('Fleece', () {
    group('Doc', () {
      group('fromJson', () {
        test('accept valid json', () {
          Doc.fromJson('{"Hello" : "World"}');
        });

        test('throw when given invalid json', () {
          expect(
            () => Doc.fromJson('x'),
            throwsA(
              isA<FleeceException>().having(
                (it) => it.code,
                'code',
                equals(FleeceErrorCode.jsonError),
              ),
            ),
          );
        });
      });

      test('root returns root value', () {
        final doc = Doc.fromJson('{}');
        final root = doc.root;
        expect(root.type, equals(ValueType.dict));
      });
    });

    group('Value', () {
      test('findDoc returns Doc which backs the Value', () {
        final doc = Doc.fromJson('{}');
        final root = doc.root;
        final foundDoc = root.doc;

        expect(foundDoc, equals(doc));
      });

      test('findDoc returns null if value is not backed by Doc', () {
        final value = MutableDict();
        expect(value.doc, isNull);
      });

      test('isUndefined returns true when type is `undefined`', () {
        final doc = Doc.fromJson('{}');
        final value = doc.root.asDict!['a'];
        expect(value.type, equals(ValueType.undefined));
        expect(value.isUndefined, isTrue);
      });

      test('isNull returns true when type is `Null`', () {
        final doc = Doc.fromJson('{"a": null}');
        final value = doc.root.asDict!['a'];
        expect(value.type, equals(ValueType.Null));
        expect(value.isNull, isTrue);
      });

      test('isInteger returns true when value is an integer', () {
        final doc = Doc.fromJson('{"a": 42}');
        final value = doc.root.asDict!['a'];
        expect(value.isInteger, isTrue);
      });

      test('isDouble returns true when value is a double', () {
        final doc = Doc.fromJson('{"a": 0.1}');
        final value = doc.root.asDict!['a'];
        expect(value.isDouble, isTrue);
      });

      test('asBool returns value as bool', () {
        final doc = Doc.fromJson('{"a": false}');
        final value = doc.root.asDict!['a'];
        expect(value.asBool, isFalse);
      });

      test('asInt returns value as int', () {
        final number = 9223372036854775807;
        final doc = Doc.fromJson('{"a": $number}');
        final value = doc.root.asDict!['a'];
        expect(value.asInt, equals(number));
      });

      test('asDouble returns value as double', () {
        final doc = Doc.fromJson('{"a": 0.1}');
        final value = doc.root.asDict!['a'];
        expect(value.asDouble, equals(.1));
      });

      test('asString returns value as string', () {
        final doc = Doc.fromJson('{"a": "b"}');
        final value = doc.root.asDict!['a'];
        expect(value.asString, equals('b'));
      });

      test('asData returns value as Uint8List', () {
        final dict = MutableDict();
        dict['a'] = testDataUint8List;
        expect(dict['a'].asData, equals(testDataUint8List));
      });

      test('scalarToString returns scalar value as string', () {
        final doc = Doc.fromJson('{"a": 1234}');
        final value = doc.root.asDict!['a'];
        expect(value.scalarToString, equals('1234'));
      });

      test('scalarToString returns null for non-scalar value', () {
        final doc = Doc.fromJson('{"a": {}}');
        final value = doc.root.asDict!['a'];
        expect(value.scalarToString, isNull);
      });

      test('asDict returns Dict when value is a dict', () {
        final doc = Doc.fromJson('{}');
        final value = doc.root;
        expect(value.asDict, isNotNull);
      });

      test('asArray returns Array when value is an array', () {
        final doc = Doc.fromJson('[]');
        final value = doc.root;
        expect(value.asArray, isNotNull);
      });

      test('toJson returns json representation of value', () {
        final json = '[{"a":42},"b"]';
        final doc = Doc.fromJson(json);
        final value = doc.root;
        expect(value.toJson(), equals(json));
      });

      test('== works for null values', () {
        final doc = Doc.fromJson('[null, null, 1]');
        final array = doc.root.asArray!;
        expect(array[0], array[1]);
        expect(array[0], isNot(array[2]));

        final mutArray = MutableArray([null, null, 1]);
        expect(mutArray[0], mutArray[1]);
        expect(mutArray[0], isNot(mutArray[2]));
      });

      test('toString returns debug description', () {
        final doc = Doc.fromJson(r'''
      {
        "null": null,
        "int": 1,
        "bool": true,
        "double": 0.5,
        "string": "a",
        "dict": {},
        "array": []
      }
      ''');

        final root = doc.root.asDict!;

        expect(
          root.toString(),
          equals(
            '{array: [], bool: true, dict: {}, double: 0.5, int: 1, null: null, string: "a"}',
          ),
        );

        expect(root['XXX'].toString(), equals('undefined'));
      });
    });

    group('Array', () {
      test('length returns count of items in array', () {
        final doc = Doc.fromJson('[null]');
        expect(doc.root.asArray!.length, equals(1));
      });

      test('setting length throw UnsupportedError', () {
        final doc = Doc.fromJson('[]');
        expect(() => doc.root.asArray!.length = 0, throwsUnsupportedError);
      });

      test('isEmpty returns whether array is empty', () {
        final doc = Doc.fromJson('[]');
        expect(doc.root.asArray!.isEmpty, isTrue);
      });

      test('asMutable returns null if array is not mutable', () {
        final doc = Doc.fromJson('[]');
        expect(doc.root.asArray!.asMutable, isNull);
      });

      test('asMutable returns array if array is mutable', () {
        final array = MutableArray();
        expect(array.asMutable, equals(array));
      });

      test('[] returns value at give index', () {
        final doc = Doc.fromJson('[42]');
        expect(doc.root.asArray![0].asInt, equals(42));
      });

      test('[] returns undefined Value when index is out of range', () {
        final doc = Doc.fromJson('[]');
        expect(doc.root.asArray![0].isUndefined, isTrue);
      });

      test('[]= throws UnsupportedError', () {
        final doc = Doc.fromJson('[]');
        expect(() => doc.root.asArray![0] = null, throwsUnsupportedError);
      });

      test('toString returns debug description', () {
        final array = MutableArray()..addAll([null, 42]);
        expect(array.toString(), equals('[null, 42]'));
      });
    });

    group('MutableArray', () {
      test('unnamed constructor creates a new empty array', () {
        final array = MutableArray();
        expect(array, isEmpty);
      });

      test('mutableCopy creates a copy of other array', () {
        final doc = Doc.fromJson('["a"]');
        final source = doc.root.asArray;
        final array = MutableArray.mutableCopy(source!);
        expect(array, equals(source));
      });

      test('source returns source of array if it has one', () {
        final doc = Doc.fromJson('["a"]');
        final source = doc.root.asArray;
        final array = MutableArray.mutableCopy(source!);
        expect(array.source, equals(source));
      });

      test('source returns null if array has one', () {
        final array = MutableArray();
        expect(array.source, isNull);
      });

      test('isChanged returns true if array was changed from source', () {
        final doc = Doc.fromJson('["a"]');
        final source = doc.root.asArray;
        final array = MutableArray.mutableCopy(source!);
        array.removeAt(0);
        expect(array.isChanged, isTrue);
      });

      test('[]= throws ArgumentError if value is not compatible with Fleece',
          () {
        final array = MutableArray();
        expect(() => array[0] = Object(), throwsArgumentError);
      });

      test('[]= throws RangeError if index is out of range', () {
        final array = MutableArray();
        expect(() => array[0] = null, throwsRangeError);
      });

      test('[]= sets value at index', () {
        final array = MutableArray();
        array.length = 1;
        array[0] = true;
        expect(array[0].asBool, equals(true));
      });

      test('add throws ArgumentError if value is not compatible with Fleece',
          () {
        final array = MutableArray();
        expect(() => array.add(Object()), throwsArgumentError);
      });

      test('add appends value at end of array', () {
        final array = MutableArray();
        array.add(true);
        expect(array[0].asBool, equals(true));
      });

      test('removeRange removes range of values from array', () {
        final array = MutableArray();
        array.addAll([0, 1, 2, 3]);
        array.removeRange(1, 3);
        expect(array, equals(MutableArray()..addAll([0, 3])));
      });

      test('insertNulls insert nulls into array', () {
        final array = MutableArray();
        array.addAll([1, 2]);
        array.insertNulls(1, 2);
        final expected = MutableArray([1, null, null, 2]);
        expect(array[0], expected[0]);
        expect(array[1].type, expected[1].type);
        expect(array[2].type, expected[2].type);
        expect(array[3], expected[3]);
      });

      test('setting length resizes the array', () {
        final array = MutableArray();
        expect(array, isEmpty);
        array.length = 3;
        expect(array[0].type, ValueType.Null);
        expect(array[1].type, ValueType.Null);
        expect(array[2].type, ValueType.Null);
      });

      test('mutableDict returns null when value at index is not an dict', () {
        final array = MutableArray();
        array.add(true);
        expect(array.mutableDict(0), isNull);
      });

      test('mutableDict returns dict when value at index is a dict', () {
        final array = MutableArray();
        array.add(MutableDict());
        expect(array.mutableDict(0), isNotNull);
      });

      test('mutableArray returns null when value at index is not an array', () {
        final array = MutableArray();
        array.add(true);
        expect(array.mutableArray(0), isNull);
      });

      test('mutableArray returns dict when value at index is a dict', () {
        final array = MutableArray();
        array.add(MutableArray());
        expect(array.mutableArray(0), isNotNull);
      });
    });

    group('Dict', () {
      test('length returns count of entries', () {
        final doc = Doc.fromJson('{}');
        final value = doc.root;
        expect(value.asDict!.length, equals(0));
      });

      test('isEmpty returns whether dict has no entries', () {
        final doc = Doc.fromJson('{}');
        final value = doc.root;
        expect(value.asDict!.isEmpty, isTrue);
      });

      test('asMutable returns null when the dict is not mutable', () {
        final doc = Doc.fromJson('{}');
        final value = doc.root;
        expect(value.asDict!.asMutable, isNull);
      });

      test('asMutable returns a MutableDict when the dict is mutable', () {
        final dict = MutableDict();
        expect(dict.asMutable, isNotNull);
      });

      test('keys returns iterator of keys of Dict', () {
        final doc = Doc.fromJson('{"a": "b", "c": "d"}');
        final keys = doc.root.asDict!.keys.toList();
        expect(keys, equals(['a', 'c']));
      });

      test('keys works when dict is empty', () {
        final doc = Doc.fromJson('{}');
        final keys = doc.root.asDict!.keys.toList();
        expect(keys, isEmpty);
      });

      test('get value for key', () {
        final doc = Doc.fromJson('{"a": "b"}');
        expect(doc.root.asDict!['a'].asString, equals('b'));
      });

      test('[]= throws UnsupportedError', () {
        final doc = Doc.fromJson('{}');
        final dict = doc.root.asDict!;
        expect(() => dict['a'] = 'b', throwsUnsupportedError);
      });

      test('clear throws UnsupportedError', () {
        final doc = Doc.fromJson('{}');
        final dict = doc.root.asDict!;
        expect(dict.clear, throwsUnsupportedError);
      });

      test('remove throws UnsupportedError', () {
        final doc = Doc.fromJson('{}');
        final dict = doc.root.asDict!;
        expect(() => dict.remove('a'), throwsUnsupportedError);
      });

      test('toString returns debug description', () {
        final dict = MutableDict()..addAll({'a': 42});
        expect(dict.toString(), equals('{a: 42}'));
      });
    });

    group('MutableDict', () {
      test('create mutable copy', () {
        final doc = Doc.fromJson('{"a": "b"}');
        final dict = MutableDict.mutableCopy(
          doc.root.asDict!,
          flags: {CopyFlag.deepCopy},
        );
        expect(dict.length, equals(1));
      });

      test('new instance', () {
        final dict = MutableDict();
        expect(dict.length, equals(0));
      });

      test('source returns null when it has none', () {
        final dict = MutableDict();
        expect(dict.source, isNull);
      });

      test('source returns source of dict', () {
        final doc = Doc.fromJson('{}');
        final dict = MutableDict.mutableCopy(doc.root.asDict!);
        expect(dict.source, isNotNull);
      });

      test('isChanged returns true when the dict was changed', () {
        final doc = Doc.fromJson('{}');
        final dict = MutableDict.mutableCopy(doc.root.asDict!);
        dict['a'] = 'b';
        expect(dict.isChanged, isTrue);
      });

      test('[]= sets compatible values', () {
        final dict = MutableDict();
        dict['null'] = null;
        dict['bool'] = true;
        dict['int'] = 42;
        dict['double'] = .5;
        dict['str'] = 'a';
        dict['value'] = MutableDict();

        expect(dict['null'].isNull, isTrue);
        expect(dict['bool'].asBool, isTrue);
        expect(dict['int'].asInt, equals(42));
        expect(dict['double'].asDouble, equals(.5));
        expect(dict['str'].asString, equals('a'));
        expect(dict['value'].asDict, equals(MutableDict()));
      });

      test('[]= throws with incompatible value', () {
        final dict = MutableDict();

        expect(() => dict['a'] = Object(), throwsArgumentError);
      });

      test('clear removes all entries', () {
        final dict = MutableDict();
        dict['a'] = 'b';
        dict.clear();
        expect(dict, isEmpty);
      });

      test('remove removes value by key', () {
        final dict = MutableDict();
        dict['a'] = 'b';
        dict.remove('a');
        expect(dict['a'].isUndefined, isTrue);
      });

      test('mutableDict returns null when value is not a dict', () {
        final dict = MutableDict();
        expect(dict.mutableDict('a'), isNull);
      });

      test('mutableDict returns value if it is a dict', () {
        final dict = MutableDict();
        dict['a'] = MutableDict();
        expect(dict.mutableDict('a'), isNotNull);
      });

      test('mutableArray returns null when value is not an array', () {
        final dict = MutableDict();
        expect(dict.mutableArray('a'), isNull);
      });

      test('mutableArray returns value if it is an array', () {
        final dict = MutableDict();
        dict['a'] = MutableArray();
        expect(dict.mutableArray('a'), isNotNull);
      });
    });

    group('conversion when setting values in containers', () {
      test('should set TypedData as ValueType.data', () {
        expect(MutableArray([ByteData(0)]).first.type, ValueType.data);
        expect(MutableArray([Float32List(0)]).first.type, ValueType.data);
        expect(MutableArray([Float32x4List(0)]).first.type, ValueType.data);
        expect(MutableArray([Float64List(0)]).first.type, ValueType.data);
        expect(MutableArray([Float64x2List(0)]).first.type, ValueType.data);
        expect(MutableArray([Int8List(0)]).first.type, ValueType.data);
        expect(MutableArray([Int16List(0)]).first.type, ValueType.data);
        expect(MutableArray([Int32List(0)]).first.type, ValueType.data);
        expect(MutableArray([Int32x4List(0)]).first.type, ValueType.data);
        expect(MutableArray([Int64List(0)]).first.type, ValueType.data);
        expect(MutableArray([Uint8ClampedList(0)]).first.type, ValueType.data);
        expect(MutableArray([Uint8List(0)]).first.type, ValueType.data);
        expect(MutableArray([Uint16List(0)]).first.type, ValueType.data);
        expect(MutableArray([Uint32List(0)]).first.type, ValueType.data);
        expect(MutableArray([Uint64List(0)]).first.type, ValueType.data);
      });
    });

    group('plain object conversion', () {
      test('throws when a incompatible type is added to collection', () {
        expect(() => MutableArray([Object()]), throwsArgumentError);

        expect(() => MutableDict({'a': Object()}), throwsArgumentError);
      });

      test('throws UnsupportedError if value is undefined', () {
        expect(() => MutableArray([]).first.toObject(), throwsUnsupportedError);
      });

      test('converts null value to null', () {
        expect(MutableArray([null]).first.toObject(), isNull);
      });

      test('converts bool value to bool', () {
        expect(MutableArray([true]).first.toObject(), isTrue);
      });

      test('converts integer value to int', () {
        expect(MutableArray([1]).first.toObject(), 1);
      });

      test('converts double value to double', () {
        expect(MutableArray([.5]).first.toObject(), .5);
      });

      test('converts string value to String', () {
        expect(MutableArray(['a']).first.toObject(), 'a');
      });

      test('converts data value to Uint8List', () {
        expect(MutableArray([testDataUint8List]).first.toObject(),
            testDataUint8List);
      });

      test('converts Array to List', () {
        final array = MutableArray([
          MutableDict({'a': 'b'}),
          'c'
        ]);

        final result = [
          {'a': 'b'},
          'c'
        ];

        expect(array.toObject(), result);
      });

      test('converts Dict to Map', () {
        final array = MutableDict({
          'a': 'b',
          'c': MutableArray(['d'])
        });

        final result = {
          'a': 'b',
          'c': ['d']
        };

        expect(array.toObject(), result);
      });
    });

    test('usage example', () {
      final doc = Doc.fromJson('''
      {
        "glossary": {
          "title": "example glossary",
          "GlossDiv": {
            "title": "S",
            "GlossList": {
              "GlossEntry": {
                "ID": "SGML",
                "SortAs": "SGML",
                "GlossTerm": "Standard Generalized Markup Language",
                "Acronym": "SGML",
                "Abbrev": "ISO 8879:1986",
                "GlossDef": {
                  "para": "A meta-markup language, used to create markup languages such as DocBook.",
                  "GlossSeeAlso": ["GML", "XML"]
                },
                "GlossSee": "markup"
              }
            }
          }
        }
      }
      ''');

      print(doc.root.asDict!.toObject());

      print(doc
          .root
          .asDict!['glossary']
          .asDict!['GlossDiv']
          .asDict!['GlossList']
          .asDict!['GlossEntry']
          .asDict!['GlossDef']
          .asDict!['GlossSeeAlso']
          .asArray![0]
          .asString);

      print(MutableDict({
        'a': {
          'b': [
            {'c': 'd'},
            .378,
            null,
            [42]
          ]
        }
      }));

      print(MutableArray([
        null,
        [null],
        {'a': true},
        53,
        {
          'b': {
            'c': {
              'd': {'e': .64597484}
            }
          }
        }
      ]));
    });
  });
}

@pragma('vm:never-inline')
void keepAlive(Object? object) {}
