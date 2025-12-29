import 'package:watermarking_core/utilities/hash_utilities.dart';

class MarkedImageReference {
  const MarkedImageReference({
    this.id,
    this.message,
    this.name,
    this.strength,
    this.path,
    this.servingUrl,
    this.progress,
  });

  final String? id;
  final String? message;
  final String? name;
  final int? strength;
  final String? path;
  final String? servingUrl;
  final String? progress;

  /// Whether the marked image is still processing (no servingUrl yet)
  bool get isProcessing => servingUrl == null || servingUrl!.isEmpty;

  MarkedImageReference copyWith({
    String? id,
    String? message,
    String? name,
    int? strength,
    String? path,
    String? servingUrl,
    String? progress,
  }) {
    return MarkedImageReference(
      id: id ?? this.id,
      message: message ?? this.message,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      path: path ?? this.path,
      servingUrl: servingUrl ?? this.servingUrl,
      progress: progress ?? this.progress,
    );
  }

  @override
  int get hashCode => hash4(id, message, strength, servingUrl);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkedImageReference &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          message == other.message &&
          name == other.name &&
          strength == other.strength &&
          path == other.path &&
          servingUrl == other.servingUrl &&
          progress == other.progress;

  @override
  String toString() {
    return 'MarkedImageReference{id: $id, message: $message, strength: $strength, isProcessing: $isProcessing, progress: $progress}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'message': message,
        'name': name,
        'strength': strength,
        'path': path,
        'servingUrl': servingUrl,
        'progress': progress,
      };
}
