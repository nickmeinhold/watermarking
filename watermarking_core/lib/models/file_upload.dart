import 'package:watermarking_core/utilities/hash_utilities.dart';

enum UploadingEvent {
  started,
  paused,
  resumed,
  progress,
  failure,
  success,
}

class FileUpload {
  const FileUpload({
    this.started,
    this.bytesSent,
    this.latestEvent,
    this.percent,
  });

  final DateTime? started;
  final int? bytesSent;
  final UploadingEvent? latestEvent;
  final double? percent;

  FileUpload copyWith({
    DateTime? started,
    int? bytesSent,
    UploadingEvent? latestEvent,
    double? percent,
  }) {
    return FileUpload(
        started: started ?? this.started,
        bytesSent: bytesSent ?? this.bytesSent,
        latestEvent: latestEvent ?? this.latestEvent,
        percent: percent ?? this.percent);
  }

  @override
  int get hashCode => hash4(started, bytesSent, latestEvent, percent);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileUpload &&
          runtimeType == other.runtimeType &&
          started == other.started &&
          bytesSent == other.bytesSent &&
          latestEvent == other.latestEvent &&
          percent == other.percent;

  @override
  String toString() {
    return 'FileUpload{startded: $started, bytesSent: $bytesSent, latestEvent: $latestEvent, percent: $percent}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'started': started?.toIso8601String(),
        'bytesSent': bytesSent,
        'latestEvent': latestEvent?.index,
        'percent': percent,
      };
}
