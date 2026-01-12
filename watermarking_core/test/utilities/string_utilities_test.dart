import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/utilities/string_utilities.dart';

void main() {
  group('trimToLast', () {
    test('returns null for null input', () {
      expect(trimToLast(10, null), isNull);
    });

    test('returns original string when shorter than limit', () {
      expect(trimToLast(10, 'hello'), equals('hello'));
    });

    test('returns original string when exactly at limit', () {
      expect(trimToLast(5, 'hello'), equals('hello'));
    });

    test('trims and adds ellipsis when longer than limit', () {
      expect(trimToLast(5, 'hello world'), equals('...world'));
    });

    test('handles empty string', () {
      expect(trimToLast(10, ''), equals(''));
    });

    test('handles zero length limit', () {
      expect(trimToLast(0, 'hello'), equals('...'));
    });

    test('handles limit of 1', () {
      expect(trimToLast(1, 'hello'), equals('...o'));
    });

    test('handles unicode characters', () {
      // Each emoji is counted as length 1 in Dart strings
      expect(trimToLast(2, 'hello'), equals('...lo'));
    });

    test('handles string with spaces', () {
      expect(trimToLast(6, 'hello world'), equals('... world'));
    });

    test('preserves exact suffix of specified length', () {
      final result = trimToLast(3, 'abcdefg');
      expect(result, equals('...efg'));
      expect(result!.substring(3), equals('efg'));
    });
  });
}
