import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/detection_stats.dart';

void main() {
  group('SequenceStats', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'k': 1,
        'psnr': 25.5,
        'peakX': 100,
        'peakY': 200,
        'peakVal': 0.95,
        'rms': 0.1,
        'shift': 5,
      };

      final stats = SequenceStats.fromJson(json);

      expect(stats.k, equals(1));
      expect(stats.psnr, equals(25.5));
      expect(stats.peakX, equals(100));
      expect(stats.peakY, equals(200));
      expect(stats.peakVal, equals(0.95));
      expect(stats.rms, equals(0.1));
      expect(stats.shift, equals(5));
    });

    test('fromJson handles missing fields with defaults', () {
      final stats = SequenceStats.fromJson({});

      expect(stats.k, equals(0));
      expect(stats.psnr, equals(0.0));
      expect(stats.peakX, equals(0));
      expect(stats.peakY, equals(0));
      expect(stats.peakVal, equals(0.0));
      expect(stats.rms, equals(0.0));
      expect(stats.shift, equals(0));
    });

    test('fromJson handles num as int for double fields', () {
      final json = {
        'k': 1,
        'psnr': 25, // int instead of double
        'peakX': 100,
        'peakY': 200,
        'peakVal': 1, // int instead of double
        'rms': 0, // int instead of double
        'shift': 5,
      };

      final stats = SequenceStats.fromJson(json);

      expect(stats.psnr, equals(25.0));
      expect(stats.peakVal, equals(1.0));
      expect(stats.rms, equals(0.0));
    });

    test('toJson produces correct output', () {
      const stats = SequenceStats(
        k: 1,
        psnr: 25.5,
        peakX: 100,
        peakY: 200,
        peakVal: 0.95,
        rms: 0.1,
        shift: 5,
      );

      final json = stats.toJson();

      expect(json['k'], equals(1));
      expect(json['psnr'], equals(25.5));
      expect(json['peakX'], equals(100));
      expect(json['peakY'], equals(200));
      expect(json['peakVal'], equals(0.95));
      expect(json['rms'], equals(0.1));
      expect(json['shift'], equals(5));
    });

    test('fromJson/toJson round-trip preserves data', () {
      final originalJson = {
        'k': 3,
        'psnr': 30.123,
        'peakX': 512,
        'peakY': 256,
        'peakVal': 0.876,
        'rms': 0.045,
        'shift': 7,
      };

      final stats = SequenceStats.fromJson(originalJson);
      final roundTripped = stats.toJson();

      expect(roundTripped, equals(originalJson));
    });
  });

  group('TimingStats', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'imageLoad': 100.5,
        'extraction': 200.3,
        'correlation': 50.7,
        'total': 351.5,
      };

      final stats = TimingStats.fromJson(json);

      expect(stats.imageLoad, equals(100.5));
      expect(stats.extraction, equals(200.3));
      expect(stats.correlation, equals(50.7));
      expect(stats.total, equals(351.5));
    });

    test('fromJson handles missing fields with defaults', () {
      final stats = TimingStats.fromJson({});

      expect(stats.imageLoad, equals(0.0));
      expect(stats.extraction, equals(0.0));
      expect(stats.correlation, equals(0.0));
      expect(stats.total, equals(0.0));
    });

    test('fromJson handles int values for double fields', () {
      final json = {
        'imageLoad': 100,
        'extraction': 200,
        'correlation': 50,
        'total': 350,
      };

      final stats = TimingStats.fromJson(json);

      expect(stats.imageLoad, equals(100.0));
      expect(stats.extraction, equals(200.0));
      expect(stats.correlation, equals(50.0));
      expect(stats.total, equals(350.0));
    });
  });

  group('PsnrStats', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'min': 15.5,
        'max': 35.2,
        'avg': 25.1,
      };

      final stats = PsnrStats.fromJson(json);

      expect(stats.min, equals(15.5));
      expect(stats.max, equals(35.2));
      expect(stats.avg, equals(25.1));
    });

    test('fromJson handles missing fields with defaults', () {
      final stats = PsnrStats.fromJson({});

      expect(stats.min, equals(0.0));
      expect(stats.max, equals(0.0));
      expect(stats.avg, equals(0.0));
    });
  });

  group('CorrelationStats', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'min': -0.5,
        'max': 0.95,
        'mean': 0.0,
        'stdDev': 0.15,
      };

      final stats = CorrelationStats.fromJson(json);

      expect(stats.min, equals(-0.5));
      expect(stats.max, equals(0.95));
      expect(stats.mean, equals(0.0));
      expect(stats.stdDev, equals(0.15));
    });

    test('fromJson handles missing fields with defaults', () {
      final stats = CorrelationStats.fromJson({});

      expect(stats.min, equals(0.0));
      expect(stats.max, equals(0.0));
      expect(stats.mean, equals(0.0));
      expect(stats.stdDev, equals(0.0));
    });
  });

  group('DetectionStatistics', () {
    test('fromJson parses complete JSON correctly', () {
      final json = {
        'imageWidth': 1920,
        'imageHeight': 1080,
        'primeSize': 1013,
        'threshold': 20.0,
        'totalSequencesTested': 10,
        'sequencesAboveThreshold': 8,
        'timing': {
          'imageLoad': 100.0,
          'extraction': 200.0,
          'correlation': 50.0,
          'total': 350.0,
        },
        'psnrStats': {
          'min': 15.0,
          'max': 35.0,
          'avg': 25.0,
        },
        'correlationStats': {
          'min': -0.1,
          'max': 0.9,
          'mean': 0.0,
          'stdDev': 0.1,
        },
        'sequences': [
          {
            'k': 0,
            'psnr': 25.0,
            'peakX': 100,
            'peakY': 100,
            'peakVal': 0.9,
            'rms': 0.05,
            'shift': 3,
          },
          {
            'k': 1,
            'psnr': 26.0,
            'peakX': 101,
            'peakY': 101,
            'peakVal': 0.91,
            'rms': 0.04,
            'shift': 5,
          },
        ],
      };

      final stats = DetectionStatistics.fromJson(json);

      expect(stats.imageWidth, equals(1920));
      expect(stats.imageHeight, equals(1080));
      expect(stats.primeSize, equals(1013));
      expect(stats.threshold, equals(20.0));
      expect(stats.totalSequencesTested, equals(10));
      expect(stats.sequencesAboveThreshold, equals(8));

      expect(stats.timing, isNotNull);
      expect(stats.timing!.imageLoad, equals(100.0));

      expect(stats.psnrStats, isNotNull);
      expect(stats.psnrStats!.min, equals(15.0));

      expect(stats.correlationStats, isNotNull);
      expect(stats.correlationStats!.max, equals(0.9));

      expect(stats.sequences, isNotNull);
      expect(stats.sequences!.length, equals(2));
      expect(stats.sequences![0].k, equals(0));
      expect(stats.sequences![1].shift, equals(5));
    });

    test('fromJson handles all null/missing fields', () {
      final stats = DetectionStatistics.fromJson({});

      expect(stats.imageWidth, isNull);
      expect(stats.imageHeight, isNull);
      expect(stats.primeSize, isNull);
      expect(stats.threshold, isNull);
      expect(stats.timing, isNull);
      expect(stats.totalSequencesTested, isNull);
      expect(stats.sequencesAboveThreshold, isNull);
      expect(stats.psnrStats, isNull);
      expect(stats.sequences, isNull);
      expect(stats.correlationStats, isNull);
    });

    test('fromJson handles empty sequences array', () {
      final json = {
        'imageWidth': 100,
        'sequences': <dynamic>[],
      };

      final stats = DetectionStatistics.fromJson(json);

      expect(stats.sequences, isNotNull);
      expect(stats.sequences!.isEmpty, isTrue);
    });

    test('fromJson handles int values for double fields', () {
      final json = {
        'threshold': 20, // int instead of double
        'timing': {
          'imageLoad': 100, // int instead of double
          'extraction': 200,
          'correlation': 50,
          'total': 350,
        },
      };

      final stats = DetectionStatistics.fromJson(json);

      expect(stats.threshold, equals(20.0));
      expect(stats.timing!.imageLoad, equals(100.0));
    });

    test('toJson produces correct output with all fields', () {
      const stats = DetectionStatistics(
        imageWidth: 1920,
        imageHeight: 1080,
        primeSize: 1013,
        threshold: 20.0,
        totalSequencesTested: 10,
        sequencesAboveThreshold: 8,
        timing: TimingStats(
          imageLoad: 100.0,
          extraction: 200.0,
          correlation: 50.0,
          total: 350.0,
        ),
        psnrStats: PsnrStats(min: 15.0, max: 35.0, avg: 25.0),
        correlationStats: CorrelationStats(
          min: -0.1,
          max: 0.9,
          mean: 0.0,
          stdDev: 0.1,
        ),
        sequences: [
          SequenceStats(
            k: 0,
            psnr: 25.0,
            peakX: 100,
            peakY: 100,
            peakVal: 0.9,
            rms: 0.05,
            shift: 3,
          ),
        ],
      );

      final json = stats.toJson();

      expect(json['imageWidth'], equals(1920));
      expect(json['timing'], isNotNull);
      expect(json['timing']['imageLoad'], equals(100.0));
      expect(json['sequences'], isNotNull);
      expect((json['sequences'] as List).length, equals(1));
    });

    test('toJson handles null nested objects', () {
      const stats = DetectionStatistics(
        imageWidth: 100,
      );

      final json = stats.toJson();

      expect(json['imageWidth'], equals(100));
      expect(json['timing'], isNull);
      expect(json['sequences'], isNull);
    });
  });
}
