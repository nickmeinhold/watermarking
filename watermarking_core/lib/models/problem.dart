enum ProblemType {
  signout,
  profile,
  images,
  deleteImage,
  imageUpload,
  marking,
}

// Note: copyWith and state based equality are intentionally not implemented
// as problems should never change and should have identity based equality
class Problem {
  const Problem({
    required this.type,
    required this.message,
    this.info,
    this.trace,
  });

  final ProblemType type;
  final String message;
  final Map<String, dynamic>? info;
  final StackTrace? trace;

  @override
  String toString() {
    return 'Problem{type: $type, message: $message, info: $info, trace: $trace}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.index,
        'message': message,
        'info': info,
        'trace': trace,
      };
}
