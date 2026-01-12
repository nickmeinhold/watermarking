import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/marked_image_reference.dart';

void main() {
  group('MarkedImageReference', () {
    test('default constructor creates reference with null fields', () {
      const ref = MarkedImageReference();

      expect(ref.id, isNull);
      expect(ref.message, isNull);
      expect(ref.name, isNull);
      expect(ref.strength, isNull);
      expect(ref.path, isNull);
      expect(ref.servingUrl, isNull);
      expect(ref.progress, isNull);
    });

    test('constructor with all fields', () {
      const ref = MarkedImageReference(
        id: 'marked-1',
        message: 'TEST',
        name: 'test-image.png',
        strength: 100,
        path: 'gs://bucket/path',
        servingUrl: 'https://example.com/image.png',
        progress: null,
      );

      expect(ref.id, equals('marked-1'));
      expect(ref.message, equals('TEST'));
      expect(ref.name, equals('test-image.png'));
      expect(ref.strength, equals(100));
      expect(ref.path, equals('gs://bucket/path'));
      expect(ref.servingUrl, equals('https://example.com/image.png'));
    });

    group('isProcessing', () {
      test('returns true when servingUrl is null', () {
        const ref = MarkedImageReference(
          id: 'test',
          servingUrl: null,
        );

        expect(ref.isProcessing, isTrue);
      });

      test('returns true when servingUrl is empty', () {
        const ref = MarkedImageReference(
          id: 'test',
          servingUrl: '',
        );

        expect(ref.isProcessing, isTrue);
      });

      test('returns false when servingUrl has value', () {
        const ref = MarkedImageReference(
          id: 'test',
          servingUrl: 'https://example.com/image.png',
        );

        expect(ref.isProcessing, isFalse);
      });
    });

    group('copyWith', () {
      test('copies all fields when none specified', () {
        const original = MarkedImageReference(
          id: 'original-id',
          message: 'ORIG',
          strength: 50,
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.message, equals(original.message));
        expect(copied.strength, equals(original.strength));
      });

      test('replaces specified fields', () {
        const original = MarkedImageReference(
          id: 'original-id',
          message: 'ORIG',
          strength: 50,
        );

        final copied = original.copyWith(
          message: 'NEW',
          servingUrl: 'https://new.url',
        );

        expect(copied.id, equals('original-id')); // unchanged
        expect(copied.message, equals('NEW'));
        expect(copied.strength, equals(50)); // unchanged
        expect(copied.servingUrl, equals('https://new.url'));
      });
    });

    group('equality', () {
      test('equal references have same hashCode', () {
        const ref1 = MarkedImageReference(
          id: 'test',
          message: 'MSG',
          name: 'name.png',
          strength: 100,
          path: 'path',
          servingUrl: 'url',
          progress: null,
        );
        const ref2 = MarkedImageReference(
          id: 'test',
          message: 'MSG',
          name: 'name.png',
          strength: 100,
          path: 'path',
          servingUrl: 'url',
          progress: null,
        );

        expect(ref1, equals(ref2));
        expect(ref1.hashCode, equals(ref2.hashCode));
      });

      test('different references are not equal', () {
        const ref1 = MarkedImageReference(id: 'test1');
        const ref2 = MarkedImageReference(id: 'test2');

        expect(ref1, isNot(equals(ref2)));
      });

      test('references with different message are not equal', () {
        const ref1 = MarkedImageReference(id: 'test', message: 'A');
        const ref2 = MarkedImageReference(id: 'test', message: 'B');

        expect(ref1, isNot(equals(ref2)));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        const ref = MarkedImageReference(
          id: 'marked-1',
          message: 'TEST',
          name: 'test.png',
          strength: 100,
          path: 'gs://bucket/path',
          servingUrl: 'https://example.com/img.png',
          progress: 'Processing...',
        );

        final json = ref.toJson();

        expect(json['id'], equals('marked-1'));
        expect(json['message'], equals('TEST'));
        expect(json['name'], equals('test.png'));
        expect(json['strength'], equals(100));
        expect(json['path'], equals('gs://bucket/path'));
        expect(json['servingUrl'], equals('https://example.com/img.png'));
        expect(json['progress'], equals('Processing...'));
      });

      test('handles null fields', () {
        const ref = MarkedImageReference(id: 'test');

        final json = ref.toJson();

        expect(json['id'], equals('test'));
        expect(json['message'], isNull);
        expect(json['strength'], isNull);
      });
    });

    group('toString', () {
      test('includes isProcessing status', () {
        const ref = MarkedImageReference(
          id: 'test-id',
          message: 'MSG',
          strength: 100,
          progress: 'Working...',
        );

        final str = ref.toString();

        expect(str, contains('test-id'));
        expect(str, contains('MSG'));
        expect(str, contains('100'));
        expect(str, contains('isProcessing: true'));
      });
    });
  });
}
