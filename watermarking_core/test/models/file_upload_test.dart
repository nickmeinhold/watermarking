import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/file_upload.dart';

void main() {
  group('FileUpload', () {
    test('default constructor creates upload with null fields', () {
      const upload = FileUpload();

      expect(upload.started, isNull);
      expect(upload.bytesSent, isNull);
      expect(upload.latestEvent, isNull);
      expect(upload.percent, isNull);
    });

    test('constructor with all fields', () {
      final started = DateTime(2024, 1, 15, 10, 30);
      final upload = FileUpload(
        started: started,
        bytesSent: 1024,
        latestEvent: UploadingEvent.progress,
        percent: 0.5,
      );

      expect(upload.started, equals(started));
      expect(upload.bytesSent, equals(1024));
      expect(upload.latestEvent, equals(UploadingEvent.progress));
      expect(upload.percent, equals(0.5));
    });

    group('copyWith', () {
      test('copies all fields when none specified', () {
        final original = FileUpload(
          started: DateTime(2024, 1, 1),
          bytesSent: 512,
          latestEvent: UploadingEvent.started,
          percent: 0.25,
        );

        final copied = original.copyWith();

        expect(copied.started, equals(original.started));
        expect(copied.bytesSent, equals(original.bytesSent));
        expect(copied.latestEvent, equals(original.latestEvent));
        expect(copied.percent, equals(original.percent));
      });

      test('replaces specified fields', () {
        const original = FileUpload(
          bytesSent: 512,
          latestEvent: UploadingEvent.started,
          percent: 0.25,
        );

        final copied = original.copyWith(
          bytesSent: 1024,
          percent: 0.5,
        );

        expect(copied.bytesSent, equals(1024));
        expect(copied.latestEvent, equals(UploadingEvent.started)); // unchanged
        expect(copied.percent, equals(0.5));
      });

      test('can update latestEvent', () {
        const original = FileUpload(
          latestEvent: UploadingEvent.started,
        );

        final copied = original.copyWith(
          latestEvent: UploadingEvent.success,
        );

        expect(copied.latestEvent, equals(UploadingEvent.success));
      });
    });

    group('equality', () {
      test('equal uploads have same hashCode', () {
        final started = DateTime(2024, 1, 1);
        final upload1 = FileUpload(
          started: started,
          bytesSent: 1024,
          latestEvent: UploadingEvent.progress,
          percent: 0.5,
        );
        final upload2 = FileUpload(
          started: started,
          bytesSent: 1024,
          latestEvent: UploadingEvent.progress,
          percent: 0.5,
        );

        expect(upload1, equals(upload2));
        expect(upload1.hashCode, equals(upload2.hashCode));
      });

      test('different uploads are not equal', () {
        const upload1 = FileUpload(bytesSent: 100);
        const upload2 = FileUpload(bytesSent: 200);

        expect(upload1, isNot(equals(upload2)));
      });

      test('uploads with different events are not equal', () {
        const upload1 = FileUpload(latestEvent: UploadingEvent.started);
        const upload2 = FileUpload(latestEvent: UploadingEvent.success);

        expect(upload1, isNot(equals(upload2)));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final started = DateTime(2024, 1, 15, 10, 30, 45);
        final upload = FileUpload(
          started: started,
          bytesSent: 2048,
          latestEvent: UploadingEvent.progress,
          percent: 0.75,
        );

        final json = upload.toJson();

        expect(json['started'], equals(started.toIso8601String()));
        expect(json['bytesSent'], equals(2048));
        expect(json['latestEvent'], equals(UploadingEvent.progress.index));
        expect(json['percent'], equals(0.75));
      });

      test('handles null DateTime', () {
        const upload = FileUpload(bytesSent: 100);

        final json = upload.toJson();

        expect(json['started'], isNull);
      });

      test('handles null latestEvent', () {
        const upload = FileUpload(bytesSent: 100);

        final json = upload.toJson();

        expect(json['latestEvent'], isNull);
      });

      test('serializes all event types correctly', () {
        for (final event in UploadingEvent.values) {
          final upload = FileUpload(latestEvent: event);
          final json = upload.toJson();
          expect(json['latestEvent'], equals(event.index));
        }
      });
    });

    group('toString', () {
      test('produces readable output', () {
        const upload = FileUpload(
          bytesSent: 1024,
          latestEvent: UploadingEvent.progress,
          percent: 0.5,
        );

        final str = upload.toString();

        expect(str, contains('1024'));
        expect(str, contains('progress'));
        expect(str, contains('0.5'));
      });
    });
  });

  group('UploadingEvent', () {
    test('has all expected values', () {
      expect(UploadingEvent.values.length, equals(6));
      expect(UploadingEvent.started.index, equals(0));
      expect(UploadingEvent.paused.index, equals(1));
      expect(UploadingEvent.resumed.index, equals(2));
      expect(UploadingEvent.progress.index, equals(3));
      expect(UploadingEvent.failure.index, equals(4));
      expect(UploadingEvent.success.index, equals(5));
    });
  });
}
