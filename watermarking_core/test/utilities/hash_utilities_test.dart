import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

void main() {
  group('hash2', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash2('a', 'b');
      final hash2Result = hash2('a', 'b');
      expect(hash1, equals(hash2Result));
    });

    test('returns different hash for different inputs', () {
      final hashAB = hash2('a', 'b');
      final hashBA = hash2('b', 'a');
      expect(hashAB, isNot(equals(hashBA)));
    });

    test('handles null values', () {
      final hashWithNull = hash2(null, 'b');
      final hashWithNull2 = hash2(null, 'b');
      expect(hashWithNull, equals(hashWithNull2));
    });

    test('handles integers', () {
      final hash1 = hash2(1, 2);
      final hash2Result = hash2(1, 2);
      expect(hash1, equals(hash2Result));
    });
  });

  group('hash3', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash3('a', 'b', 'c');
      final hash2 = hash3('a', 'b', 'c');
      expect(hash1, equals(hash2));
    });

    test('is order sensitive', () {
      final hashABC = hash3('a', 'b', 'c');
      final hashCBA = hash3('c', 'b', 'a');
      expect(hashABC, isNot(equals(hashCBA)));
    });
  });

  group('hash4', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash4('a', 'b', 'c', 'd');
      final hash2 = hash4('a', 'b', 'c', 'd');
      expect(hash1, equals(hash2));
    });
  });

  group('hash5', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash5('a', 'b', 'c', 'd', 'e');
      final hash2 = hash5('a', 'b', 'c', 'd', 'e');
      expect(hash1, equals(hash2));
    });
  });

  group('hash6', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash6('a', 'b', 'c', 'd', 'e', 'f');
      final hash2 = hash6('a', 'b', 'c', 'd', 'e', 'f');
      expect(hash1, equals(hash2));
    });
  });

  group('hash7', () {
    test('returns consistent hash for same inputs', () {
      final hash1 = hash7('a', 'b', 'c', 'd', 'e', 'f', 'g');
      final hash2 = hash7('a', 'b', 'c', 'd', 'e', 'f', 'g');
      expect(hash1, equals(hash2));
    });

    test('handles mixed types', () {
      // Note: Using same object references for consistent hash codes
      final list = <String>[];
      final map = <String, int>{};
      final hash1 = hash7('a', 1, null, 3.14, true, list, map);
      final hash2 = hash7('a', 1, null, 3.14, true, list, map);
      expect(hash1, equals(hash2));
    });

    test('different objects produce different hashes', () {
      final hash1 = hash7('a', 1, null, 3.14, true, 'x', 'y');
      final hash2 = hash7('a', 1, null, 3.14, true, 'y', 'x');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('hashObjects', () {
    test('returns consistent hash for same iterable', () {
      final hash1 = hashObjects(['a', 'b', 'c']);
      final hash2 = hashObjects(['a', 'b', 'c']);
      expect(hash1, equals(hash2));
    });

    test('returns different hash for different order', () {
      final hashABC = hashObjects(['a', 'b', 'c']);
      final hashCBA = hashObjects(['c', 'b', 'a']);
      expect(hashABC, isNot(equals(hashCBA)));
    });

    test('handles empty iterable', () {
      final hash1 = hashObjects([]);
      final hash2 = hashObjects([]);
      expect(hash1, equals(hash2));
    });

    test('handles null values in iterable', () {
      final hash1 = hashObjects([null, 'a', null]);
      final hash2 = hashObjects([null, 'a', null]);
      expect(hash1, equals(hash2));
    });

    test('hash2 equals hashObjects with 2 elements', () {
      final h2 = hash2('a', 'b');
      final hObj = hashObjects(['a', 'b']);
      expect(h2, equals(hObj));
    });

    test('hash3 equals hashObjects with 3 elements', () {
      final h3 = hash3('a', 'b', 'c');
      final hObj = hashObjects(['a', 'b', 'c']);
      expect(h3, equals(hObj));
    });
  });
}
