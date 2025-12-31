import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:watermarking_core/models/problem.dart';
import 'package:watermarking_core/redux/actions.dart';

class StorageService {
  StorageService();

  String? userId;
  final Map<String, UploadTask> uploadTasks = <String, UploadTask>{};

  /// Upload original image from bytes (web compatible)
  /// Returns the download URL on success
  Future<String> uploadOriginalImageBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('original-images')
        .child('$userId')
        .child(fileName);

    final UploadTask uploadTask = ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/png',
        customMetadata: <String, String>{'uid': userId ?? ''},
      ),
    );

    final TaskSnapshot snapshot = await uploadTask;
    final String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Start an upload and return a stream that emits actions of type:
  /// - ActionSetUploadSuccess
  /// - ActionAddProblem (for failures)
  /// - ActionSetUploadProgress
  Stream<dynamic> startUpload({
    required String filePath,
    required String entryId,
  }) {
    final File file = File(filePath);

    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('detecting-images')
        .child('$userId')
        .child(entryId);

    final UploadTask uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/png',
        customMetadata: <String, String>{'docId': entryId, 'uid': userId ?? ''},
      ),
    );

    uploadTasks[entryId] = uploadTask;

    // Convert the upload task events to actions
    final progressStream =
        uploadTask.snapshotEvents.map<dynamic>((TaskSnapshot snapshot) {
      switch (snapshot.state) {
        case TaskState.running:
          return ActionSetUploadProgress(
            bytes: snapshot.bytesTransferred,
            id: entryId,
          );
        case TaskState.paused:
          return ActionSetUploadPaused(id: entryId);
        case TaskState.success:
          return ActionSetUploadSuccess(id: entryId);
        case TaskState.canceled:
          return ActionAddProblem(
            problem: Problem(
              type: ProblemType.imageUpload,
              message: 'Upload canceled',
              info: <String, dynamic>{'itemId': entryId},
            ),
          );
        case TaskState.error:
          return ActionAddProblem(
            problem: Problem(
              type: ProblemType.imageUpload,
              message: 'Upload failed',
              info: <String, dynamic>{'itemId': entryId},
            ),
          );
      }
    });

    // Handle errors from the upload task
    final errorStream = uploadTask
        .asStream()
        .handleError((Object error) {
          return ActionAddProblem(
            problem: Problem(
              type: ProblemType.imageUpload,
              message: error.toString(),
              info: <String, dynamic>{'itemId': entryId},
            ),
          );
        })
        .where((_) => false)
        .cast<dynamic>(); // Filter out successful completions

    return Rx.merge([progressStream, errorStream]);
  }

  void cancelUpload(String entryId) {
    uploadTasks[entryId]?.cancel();
  }

  void pauseUpload(String entryId) {
    uploadTasks[entryId]?.pause();
  }

  void resumeUpload(String entryId) {
    uploadTasks[entryId]?.resume();
  }

  Future<String> getDownloadUrl(String path) async {
    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      return '';
    }
  }
}
