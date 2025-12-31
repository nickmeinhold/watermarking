import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/models/problem.dart';

class Action {
  const Action(this.propsMap);
  Action.fromJson(Map<String, dynamic> json) : propsMap = json;
  final Map<String, dynamic> propsMap;
  Map<String, dynamic> toJson() => propsMap;
}

class ActionSignin extends Action {
  const ActionSignin() : super(const <String, Object>{});
}

class ActionSignout extends Action {
  const ActionSignout() : super(const <String, Object>{});
}

class ActionAddProblem extends Action {
  ActionAddProblem({required this.problem})
      : super(<String, Object>{'problem': problem});
  final Problem problem;
}

class ActionRemoveProblem extends Action {
  ActionRemoveProblem({required this.problem})
      : super(<String, Object>{'problem': problem});
  final Problem problem;
}

class ActionObserveAuthState extends Action {
  const ActionObserveAuthState() : super(const <String, Object>{});
}

class ActionSetAuthState extends Action {
  ActionSetAuthState({this.userId, this.photoUrl})
      : super(<String, Object?>{
          'userId': userId,
          'photoUrl': photoUrl,
        });
  final String? userId;
  final String? photoUrl;
}

class ActionSetProfilePicUrl extends Action {
  ActionSetProfilePicUrl({required this.url})
      : super(<String, Object>{'url': url});
  final String url;
}

class ActionSetProfile extends Action {
  ActionSetProfile({required this.name, required this.email})
      : super(<String, Object>{
          'name': name,
          'email': email,
        });
  final String name;
  final String email;
}

class ActionSetOriginalImages extends Action {
  ActionSetOriginalImages({required this.images})
      : super(<String, Object>{'images': images});
  final List<OriginalImageReference> images;
}

class ActionSetDetectionItems extends Action {
  ActionSetDetectionItems({required this.items})
      : super(<String, Object>{'items': items});
  final List<DetectionItem> items;
}

class ActionSetBottomNav extends Action {
  ActionSetBottomNav({required this.index})
      : super(<String, Object>{'index': index});
  final int index;
}

class ActionShowBottomSheet extends Action {
  ActionShowBottomSheet({required this.show})
      : super(<String, Object>{'show': show});
  final bool show;
}

class ActionSetSelectedImage extends Action {
  ActionSetSelectedImage({
    required this.image,
    required this.height,
    required this.width,
  }) : super(<String, Object>{
          'image': image,
          'height': height,
          'width': width,
        });
  final OriginalImageReference image;
  final int height;
  final int width;
}

class ActionPerformExtraction extends Action {
  ActionPerformExtraction({required this.width, required this.height})
      : super(<String, Object>{'height': height, 'width': width});
  final int width;
  final int height;
}

class ActionProcessExtraction extends Action {
  ActionProcessExtraction({required this.filePath})
      : super(<String, Object>{'filePath': filePath});
  final String filePath;
}

class ActionAddDetectionItem extends Action {
  ActionAddDetectionItem({
    required this.id,
    required this.extractedPath,
    required this.bytes,
  }) : super(<String, Object>{
          'id': id,
          'extractedPath': extractedPath,
          'bytes': bytes,
        });
  final String id;
  final String extractedPath;
  final int bytes;
}

class ActionStartUpload extends Action {
  ActionStartUpload({required this.id, required this.filePath})
      : super(<String, Object>{'id': id, 'filePath': filePath});
  final String id;
  final String filePath;
}

class ActionSetUploadPaused extends Action {
  ActionSetUploadPaused({required this.id}) : super(<String, Object>{'id': id});
  final String id;
}

class ActionSetUploadResumed extends Action {
  ActionSetUploadResumed({required this.id})
      : super(<String, Object>{'id': id});
  final String id;
}

class ActionSetUploadSuccess extends Action {
  ActionSetUploadSuccess({required this.id})
      : super(<String, Object>{'id': id});
  final String id;
}

class ActionSetUploadProgress extends Action {
  ActionSetUploadProgress({required this.id, required this.bytes})
      : super(<String, Object>{'id': id, 'bytes': bytes});
  final String id;
  final int bytes;
}

class ActionCancelUpload extends Action {
  ActionCancelUpload({required this.id}) : super(<String, Object>{'id': id});
  final String id;
}

class ActionSetDetectingProgress extends Action {
  ActionSetDetectingProgress({
    required this.id,
    required this.progress,
    this.result,
    this.error,
    this.pathMarked,
  }) : super(<String, Object?>{
          'id': id,
          'progress': progress,
          'result': result,
          'error': error,
          'pathMarked': pathMarked,
        });
  final String id;
  final String progress;
  final String? result;
  final String? error;
  final String? pathMarked;
}

/// Action to upload an original image (works with bytes for web compatibility)
class ActionUploadOriginalImage extends Action {
  ActionUploadOriginalImage({
    required this.fileName,
    required this.bytes,
    required this.width,
    required this.height,
  }) : super(<String, Object>{
          'fileName': fileName,
          'bytes': bytes,
          'width': width,
          'height': height,
        });
  final String fileName;
  final List<int> bytes;
  final int width;
  final int height;
}

/// Action when original image upload completes
class ActionOriginalImageUploaded extends Action {
  ActionOriginalImageUploaded({
    required this.id,
    required this.name,
    required this.path,
    required this.url,
  }) : super(<String, Object>{
          'id': id,
          'name': name,
          'path': path,
          'url': url,
        });
  final String id;
  final String name;
  final String path;
  final String url;
}

/// Action to apply a watermark to an original image
class ActionMarkImage extends Action {
  ActionMarkImage({
    required this.imageId,
    required this.imageName,
    required this.imagePath,
    required this.message,
    required this.strength,
  }) : super(<String, Object>{
          'imageId': imageId,
          'imageName': imageName,
          'imagePath': imagePath,
          'message': message,
          'strength': strength,
        });
  final String imageId;
  final String imageName;
  final String imagePath;
  final String message;
  final double strength;
}

/// Action to update marked images for originals
class ActionUpdateMarkedImages extends Action {
  ActionUpdateMarkedImages({required this.markedImagesByOriginal})
      : super(
            <String, Object>{'markedImagesByOriginal': markedImagesByOriginal});

  /// Map of originalImageId -> list of marked images
  final Map<String, List<Map<String, dynamic>>> markedImagesByOriginal;
}

class ActionDeleteMarkedImage extends Action {
  ActionDeleteMarkedImage({required this.markedImageId})
      : super(<String, Object>{'markedImageId': markedImageId});
  final String markedImageId;
}

class ActionDeleteDetectionItem extends Action {
  ActionDeleteDetectionItem({required this.detectionItemId})
      : super(<String, Object>{'detectionItemId': detectionItemId});
  final String detectionItemId;
}

class ActionDetectMarkedImage extends Action {
  ActionDetectMarkedImage({
    required this.markedImageId,
    required this.originalPath,
    required this.markedPath,
  }) : super(<String, Object>{
          'markedImageId': markedImageId,
          'originalPath': originalPath,
          'markedPath': markedPath,
        });
  final String markedImageId;
  final String originalPath;
  final String markedPath;
}
