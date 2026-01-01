import 'package:watermarking_core/models/detection_stats.dart';
import 'package:watermarking_core/models/extracted_image_reference.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/utilities/hash_utilities.dart';

enum ProcessExtractedImageEvent {
  started,
  processed,
}

class DetectionItem {
  const DetectionItem({
    this.id,
    this.started,
    this.originalRef,
    this.extractedRef,
    this.progress,
    this.result,
    this.confidence,
    this.error,
    this.detected,
    this.statistics,
  });

  final String? id;
  final DateTime? started;
  final OriginalImageReference? originalRef;
  final ExtractedImageReference? extractedRef;
  final String? progress;
  final String? result;
  final double? confidence;
  final String? error;
  final bool? detected;
  final DetectionStatistics? statistics;

  DetectionItem copyWith({
    String? id,
    DateTime? started,
    OriginalImageReference? originalRef,
    ExtractedImageReference? extractedRef,
    String? progress,
    String? result,
    double? confidence,
    String? error,
    bool? detected,
    DetectionStatistics? statistics,
  }) {
    return DetectionItem(
      id: id ?? this.id,
      started: started ?? this.started,
      originalRef: originalRef ?? this.originalRef,
      extractedRef: extractedRef ?? this.extractedRef,
      progress: progress ?? this.progress,
      result: result ?? this.result,
      confidence: confidence ?? this.confidence,
      error: error ?? this.error,
      detected: detected ?? this.detected,
      statistics: statistics ?? this.statistics,
    );
  }

  @override
  int get hashCode => hashObjects([
        id,
        started,
        originalRef,
        extractedRef,
        progress,
        result,
        confidence,
        error,
        detected,
        statistics,
      ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectionItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          started == other.started &&
          originalRef == other.originalRef &&
          extractedRef == other.extractedRef &&
          progress == other.progress &&
          result == other.result &&
          confidence == other.confidence &&
          error == other.error &&
          detected == other.detected &&
          statistics == other.statistics;

  @override
  String toString() {
    return 'DetectionItem{id: $id, started: $started, result: $result, confidence: $confidence, detected: $detected}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'started': started?.toIso8601String(),
        'originalRef': originalRef,
        'extractedRef': extractedRef,
        'progress': progress,
        'result': result,
        'confidence': confidence,
        'error': error,
        'detected': detected,
        'statistics': statistics?.toJson(),
      };
}
