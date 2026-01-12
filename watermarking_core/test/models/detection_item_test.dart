import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/detection_stats.dart';

void main() {
  group('DetectionItem', () {
    test('default constructor creates item with null fields', () {
      const item = DetectionItem();

      expect(item.id, isNull);
      expect(item.started, isNull);
      expect(item.progress, isNull);
      expect(item.result, isNull);
      expect(item.confidence, isNull);
    });

    test('constructor with all fields', () {
      final started = DateTime(2024, 1, 15, 10, 30);
      final item = DetectionItem(
        id: 'test-id',
        started: started,
        progress: 'Processing...',
        result: 'TEST',
        confidence: 0.95,
        error: null,
        detected: true,
        isCaptured: true,
      );

      expect(item.id, equals('test-id'));
      expect(item.started, equals(started));
      expect(item.progress, equals('Processing...'));
      expect(item.result, equals('TEST'));
      expect(item.confidence, equals(0.95));
      expect(item.detected, isTrue);
      expect(item.isCaptured, isTrue);
    });

    group('copyWith', () {
      test('copies all fields when none specified', () {
        final original = DetectionItem(
          id: 'original-id',
          started: DateTime(2024, 1, 1),
          result: 'ABC',
          confidence: 0.9,
        );

        final copied = original.copyWith();

        expect(copied.id, equals(original.id));
        expect(copied.started, equals(original.started));
        expect(copied.result, equals(original.result));
        expect(copied.confidence, equals(original.confidence));
      });

      test('replaces specified fields', () {
        const original = DetectionItem(
          id: 'original-id',
          result: 'ABC',
        );

        final copied = original.copyWith(
          id: 'new-id',
          confidence: 0.75,
        );

        expect(copied.id, equals('new-id'));
        expect(copied.result, equals('ABC')); // unchanged
        expect(copied.confidence, equals(0.75));
      });
    });

    group('equality', () {
      test('equal items have same hashCode', () {
        final item1 = DetectionItem(
          id: 'test',
          started: DateTime(2024, 1, 1),
          result: 'ABC',
        );
        final item2 = DetectionItem(
          id: 'test',
          started: DateTime(2024, 1, 1),
          result: 'ABC',
        );

        expect(item1, equals(item2));
        expect(item1.hashCode, equals(item2.hashCode));
      });

      test('different items are not equal', () {
        const item1 = DetectionItem(id: 'test1');
        const item2 = DetectionItem(id: 'test2');

        expect(item1, isNot(equals(item2)));
      });

      test('items with different confidence are not equal', () {
        const item1 = DetectionItem(id: 'test', confidence: 0.9);
        const item2 = DetectionItem(id: 'test', confidence: 0.8);

        expect(item1, isNot(equals(item2)));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final started = DateTime(2024, 1, 15, 10, 30, 45);
        final item = DetectionItem(
          id: 'test-id',
          started: started,
          progress: 'Done',
          result: 'TEST',
          confidence: 0.95,
          error: null,
          detected: true,
          isCaptured: false,
        );

        final json = item.toJson();

        expect(json['id'], equals('test-id'));
        expect(json['started'], equals(started.toIso8601String()));
        expect(json['progress'], equals('Done'));
        expect(json['result'], equals('TEST'));
        expect(json['confidence'], equals(0.95));
        expect(json['error'], isNull);
        expect(json['detected'], isTrue);
        expect(json['isCaptured'], isFalse);
      });

      test('handles null DateTime', () {
        const item = DetectionItem(
          id: 'test-id',
          started: null,
        );

        final json = item.toJson();

        expect(json['started'], isNull);
      });

      test('includes statistics when present', () {
        const stats = DetectionStatistics(
          imageWidth: 1920,
          imageHeight: 1080,
        );
        const item = DetectionItem(
          id: 'test-id',
          statistics: stats,
        );

        final json = item.toJson();

        expect(json['statistics'], isNotNull);
        expect(json['statistics']['imageWidth'], equals(1920));
      });
    });

    group('toString', () {
      test('produces readable output', () {
        const item = DetectionItem(
          id: 'test-id',
          result: 'ABC',
          confidence: 0.95,
          detected: true,
        );

        final str = item.toString();

        expect(str, contains('test-id'));
        expect(str, contains('ABC'));
        expect(str, contains('0.95'));
        expect(str, contains('true'));
      });
    });
  });

  group('ProcessExtractedImageEvent', () {
    test('enum values exist', () {
      expect(ProcessExtractedImageEvent.values.length, equals(2));
      expect(ProcessExtractedImageEvent.started, isNotNull);
      expect(ProcessExtractedImageEvent.processed, isNotNull);
    });
  });
}
