import 'package:watermarking_core/utilities/hash_utilities.dart';
import 'package:watermarking_core/utilities/string_utilities.dart';

/// [waiting] indicates we are waiting for auth state retrieval
class UserModel {
  const UserModel({this.id, this.waiting = false, this.photoUrl});

  final String? id;
  final bool waiting;
  final String? photoUrl;

  UserModel copyWith({
    String? id,
    bool? waiting,
    String? photoUrl,
  }) {
    return UserModel(
        id: id ?? this.id,
        waiting: waiting ?? this.waiting,
        photoUrl: photoUrl ?? this.photoUrl);
  }

  @override
  int get hashCode => hash3(id, waiting, photoUrl);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          waiting == other.waiting &&
          photoUrl == other.photoUrl;

  @override
  String toString() {
    final String? trimmedPhotoUrl = trimToLast(15, photoUrl);
    return 'UserModel{uid: $id, waiting: $waiting, photoUrl: $trimmedPhotoUrl}';
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'waiting': waiting, 'photoUrl': photoUrl};
}
