import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/marked_image_reference.dart';
import 'package:watermarking_core/models/original_image_reference.dart';

void main() {
  group('OriginalImageReference', () {
    test('default constructor creates reference with empty markedImages', () {
      const ref = OriginalImageReference();

      expect(ref.id, isNull);
      expect(ref.name, isNull);
      expect(ref.filePath, isNull);
      expect(ref.url, isNull);
      expect(ref.markedImages, isEmpty);
    });

    test('constructor with all fields', () {
      const markedRef = MarkedImageReference(id: 'marked-1', message: 'TEST');
      const ref = OriginalImageReference(
        id: 'orig-1',
        name: 'original.png',
        filePath: '/path/to/file',
        url: 'https://example.com/original.png',
        markedImages: [markedRef],
      );

      expect(ref.id, equals('orig-1'));
      expect(ref.name, equals('original.png'));
      expect(ref.filePath, equals('/path/to/file'));
      expect(ref.url, equals('https://example.com/original.png'));
      expect(ref.markedImages.length, equals(1));
      expect(ref.markedImages[0].message, equals('TEST'));
    });

    group('markedCount', () {
      test('returns 0 for empty list', () {
        const ref = OriginalImageReference();
        expect(ref.markedCount, equals(0));
      });

      test('returns correct count', () {
        const ref = OriginalImageReference(
          markedImages: [
            MarkedImageReference(id: '1'),
            MarkedImageReference(id: '2'),
            MarkedImageReference(id: '3'),
          ],
        );
        expect(ref.markedCount, equals(3));
      });
    });

    group('copyWith', () {
      test('copies all fields when none specified', () {
        const original = OriginalImageReference(
          id: 'orig-id',
          name: 'test.png',
          url: 'https://example.com',
          markedImages: [MarkedImageReference(id: 'marked-1')],
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.name, equals(original.name));
        expect(copied.url, equals(original.url));
        expect(copied.markedImages.length, equals(1));
      });

      test('replaces specified fields', () {
        const original = OriginalImageReference(
          id: 'orig-id',
          name: 'test.png',
        );

        final copied = original.copyWith(
          name: 'new-name.png',
          url: 'https://new.url',
        );

        expect(copied.id, equals('orig-id')); // unchanged
        expect(copied.name, equals('new-name.png'));
        expect(copied.url, equals('https://new.url'));
      });

      test('replaces markedImages list', () {
        const original = OriginalImageReference(
          id: 'orig-id',
          markedImages: [MarkedImageReference(id: 'marked-1')],
        );

        final copied = original.copyWith(
          markedImages: [
            const MarkedImageReference(id: 'marked-2'),
            const MarkedImageReference(id: 'marked-3'),
          ],
        );

        expect(copied.markedImages.length, equals(2));
        expect(copied.markedImages[0].id, equals('marked-2'));
      });
    });

    group('equality', () {
      test('equal references are equal', () {
        const ref1 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
          url: 'https://url',
        );
        const ref2 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
          url: 'https://url',
        );

        expect(ref1, equals(ref2));
      });

      test('references with different ids are not equal', () {
        const ref1 = OriginalImageReference(id: 'test1');
        const ref2 = OriginalImageReference(id: 'test2');

        expect(ref1, isNot(equals(ref2)));
      });

      // Note: This tests the current behavior which only compares markedImages.length
      test('references with same markedImages length are equal', () {
        const ref1 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
          url: 'https://url',
          markedImages: [MarkedImageReference(id: 'a')],
        );
        const ref2 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
          url: 'https://url',
          markedImages: [MarkedImageReference(id: 'b')], // different id!
        );

        // Current implementation only compares length, not contents
        expect(ref1, equals(ref2));
      });
    });

    group('hashCode', () {
      test('equal references have same hashCode', () {
        const ref1 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
        );
        const ref2 = OriginalImageReference(
          id: 'test',
          name: 'name.png',
          filePath: '/path',
        );

        expect(ref1.hashCode, equals(ref2.hashCode));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        const ref = OriginalImageReference(
          id: 'orig-1',
          name: 'test.png',
          filePath: '/path/to/file',
          url: 'https://example.com/image.png',
          markedImages: [
            MarkedImageReference(id: 'marked-1', message: 'TEST'),
          ],
        );

        final json = ref.toJson();

        expect(json['id'], equals('orig-1'));
        expect(json['name'], equals('test.png'));
        expect(json['filePath'], equals('/path/to/file'));
        expect(json['url'], equals('https://example.com/image.png'));
        expect(json['markedImages'], isA<List>());
        expect((json['markedImages'] as List).length, equals(1));
      });

      test('handles empty markedImages', () {
        const ref = OriginalImageReference(id: 'test');

        final json = ref.toJson();

        expect(json['markedImages'], isA<List>());
        expect((json['markedImages'] as List).isEmpty, isTrue);
      });

      test('serializes nested markedImages correctly', () {
        const ref = OriginalImageReference(
          id: 'orig-1',
          markedImages: [
            MarkedImageReference(
              id: 'marked-1',
              message: 'MSG',
              strength: 100,
            ),
          ],
        );

        final json = ref.toJson();
        final markedJson = (json['markedImages'] as List)[0];

        expect(markedJson['id'], equals('marked-1'));
        expect(markedJson['message'], equals('MSG'));
        expect(markedJson['strength'], equals(100));
      });
    });

    group('toString', () {
      test('includes markedCount', () {
        const ref = OriginalImageReference(
          id: 'test-id',
          name: 'test.png',
          markedImages: [
            MarkedImageReference(id: '1'),
            MarkedImageReference(id: '2'),
          ],
        );

        final str = ref.toString();

        expect(str, contains('test-id'));
        expect(str, contains('test.png'));
        expect(str, contains('markedCount: 2'));
      });

      test('trims long URLs', () {
        const ref = OriginalImageReference(
          id: 'test',
          url: 'https://example.com/very/long/path/to/image.png',
        );

        final str = ref.toString();

        expect(str, contains('...'));
      });
    });
  });
}
