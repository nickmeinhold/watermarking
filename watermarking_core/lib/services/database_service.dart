import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/marked_image_reference.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/redux/actions.dart';

/// Note: Errors in streams are intentionally passed on and handled in middleware
class DatabaseService {
  DatabaseService();

  String? userId;
  StreamSubscription<dynamic>? originalsSubscription;
  StreamSubscription<dynamic>? markedImagesSubscription;
  StreamSubscription<dynamic>? profileSubscription;
  StreamSubscription<dynamic>? detectingSubscription;
  StreamSubscription<dynamic>? detectionItemsSubscription;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String getDetectionItemId() => _db.collection('detectionItems').doc().id;

  Stream<dynamic> connectToOriginals() {
    // Listen to original images for this user
    // Note: Sorting client-side to avoid requiring a composite index
    return _db
        .collection('originalImages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap<dynamic>((QuerySnapshot snapshot) async {
      final List<OriginalImageReference> imagesList = [];

      // Sort docs by timestamp descending (newest first)
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['timestamp'] as Timestamp?;
          final bTimestamp = bData['timestamp'] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp);
        });

      for (final doc in sortedDocs) {
        final data = doc.data() as Map<String, dynamic>;

        // Fetch marked images for this original
        final markedSnapshot = await _db
            .collection('markedImages')
            .where('originalImageId', isEqualTo: doc.id)
            .get();

        final List<MarkedImageReference> markedImages =
            markedSnapshot.docs.map((markedDoc) {
          final markedData = markedDoc.data();
          return MarkedImageReference(
            id: markedDoc.id,
            message: markedData['message'] as String?,
            name: markedData['name'] as String?,
            strength: markedData['strength'] as int?,
            path: markedData['path'] as String?,
            servingUrl: markedData['servingUrl'] as String?,
            progress: markedData['progress'] as String?,
          );
        }).toList();

        imagesList.add(OriginalImageReference(
          id: doc.id,
          name: data['name'] as String?,
          filePath: data['path'] as String?,
          url: data['servingUrl'] as String?,
          markedImages: markedImages,
        ));
      }

      return ActionSetOriginalImages(images: imagesList);
    });
  }

  Future<dynamic> cancelOriginalsSubscription() {
    return originalsSubscription?.cancel() ?? Future<dynamic>.value(null);
  }

  /// Listen to marked images for this user and group by originalImageId
  Stream<dynamic> connectToMarkedImages() {
    return _db
        .collection('markedImages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<dynamic>((QuerySnapshot snapshot) {
      final Map<String, List<Map<String, dynamic>>> markedByOriginal = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final originalImageId = data['originalImageId'] as String?;
        if (originalImageId == null) continue;

        markedByOriginal.putIfAbsent(originalImageId, () => []);
        markedByOriginal[originalImageId]!.add({
          'id': doc.id,
          'message': data['message'],
          'name': data['name'],
          'strength': data['strength'],
          'path': data['path'],
          'servingUrl': data['servingUrl'],
          'progress': data['progress'],
        });
      }

      return ActionUpdateMarkedImages(markedImagesByOriginal: markedByOriginal);
    });
  }

  Future<dynamic> cancelMarkedImagesSubscription() {
    return markedImagesSubscription?.cancel() ?? Future<dynamic>.value(null);
  }

  Stream<dynamic> connectToProfile() {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map<dynamic>((DocumentSnapshot snapshot) {
      if (!snapshot.exists) {
        return ActionSetProfile(name: '', email: '');
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      return ActionSetProfile(
        name: data?['name'] as String? ?? '',
        email: data?['email'] as String? ?? '',
      );
    });
  }

  Future<dynamic> cancelProfileSubscription() {
    return profileSubscription?.cancel() ?? Future<dynamic>.value(null);
  }

  Future<void> requestOriginalDelete(String entryId) {
    return _db
        .collection('originalImages')
        .doc(entryId)
        .update({'delete': true});
  }

  /// Add an original image entry to the database
  Future<String> addOriginalImageEntry({
    required String name,
    required String path,
    required String url,
    required int width,
    required int height,
  }) async {
    final docRef = await _db.collection('originalImages').add({
      'userId': userId,
      'name': name,
      'path': path,
      'url': url,
      'servingUrl': url,
      'width': width,
      'height': height,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _wakeUpBackend();

    // Create a task to get serving URL
    await _db.collection('tasks').add({
      'type': 'get_serving_url',
      'status': 'pending',
      'userId': userId,
      'imageId': docRef.id,
      'path': path,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Create a marking task to apply a watermark to an image
  Future<String> addMarkingTask({
    required String imageId,
    required String imageName,
    required String imagePath,
    required String message,
    required int strength,
  }) async {
    // 1. Create marked image placeholder entry
    final markedRef = await _db.collection('markedImages').add({
      'originalImageId': imageId,
      'userId': userId,
      'message': message,
      'name': imageName,
      'strength': strength,
      'progress': 'Queued',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Create queue task to trigger backend processing
    await _db.collection('tasks').add({
      'type': 'mark',
      'status': 'pending',
      'userId': userId,
      'markedImageId': markedRef.id,
      'originalImageId': imageId,
      'name': imageName,
      'path': imagePath,
      'message': message,
      'strength': strength,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _wakeUpBackend();
    return markedRef.id;
  }

  Future<void> requestMarkedImageDelete(String markedImageId) async {
    await _db.collection('tasks').add({
      'type': 'delete_marked_image',
      'status': 'pending',
      'userId': userId,
      'markedImageId': markedImageId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addDetectingEntry({
    required String itemId,
    required String originalPath,
    required String markedPath,
  }) async {
    // Set detecting status
    await _db.collection('detecting').doc(userId).set({
      'itemId': itemId,
      'progress': 'Adding a detection task to the queue...',
      'isDetecting': true,
      'pathOriginal': originalPath,
      'pathMarked': markedPath,
      'attempts': 0,
    });

    // Create detection task
    await _db.collection('tasks').add({
      'type': 'detect',
      'status': 'pending',
      'userId': userId,
      'pathOriginal': originalPath,
      'pathMarked': markedPath,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _wakeUpBackend();
  }

  Stream<dynamic> connectToDetecting() {
    return _db
        .collection('detecting')
        .doc(userId)
        .snapshots()
        .map<dynamic>((DocumentSnapshot snapshot) {
      if (!snapshot.exists) {
        return ActionSetDetectingProgress(
          id: '',
          progress: '',
          result: null,
        );
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      Map<String, dynamic>? resultsMap;
      if (data?['results'] != null) {
        resultsMap = Map<String, dynamic>.from(data!['results'] as Map);
      }

      return ActionSetDetectingProgress(
        id: data?['itemId'] as String? ?? '',
        progress: data?['progress'] as String? ?? '',
        result: resultsMap?['message'] as String?,
        error: data?['error'] as String?,
      );
    });
  }

  Future<dynamic> cancelDetectingSubscription() {
    return detectingSubscription?.cancel() ?? Future<dynamic>.value(null);
  }

  Stream<dynamic> connectToDetectionItems() {
    return _db
        .collection('detectionItems')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map<dynamic>((QuerySnapshot snapshot) {
      final List<DetectionItem> list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DetectionItem(
          id: doc.id,
          progress: data['progress'] as String? ?? '',
          result: data['result'] as String?,
        );
      }).toList();

      return ActionSetDetectionItems(items: list);
    });
  }

  Future<dynamic> cancelDetectionItemsSubscription() {
    return detectionItemsSubscription?.cancel() ?? Future<dynamic>.value(null);
  }

  /// Pings the Cloud Run instance to ensure it scales up from zero
  Future<void> _wakeUpBackend() async {
    try {
      // Access the health check endpoint
      // We don't await the result because we don't want to block the UI
      // or fail the operation if the backend is slow to respond.
      // We just want to trigger the scaling.
      http
          .get(Uri.parse(
              'https://watermarking-backend-2mug77svva-uc.a.run.app/'))
          .then((_) {
        // success
      }).catchError((e) {
        // ignore errors
        print('Error waking up backend: $e');
      });
    } catch (e) {
      // ignore sync errors
      print('Error triggering backend wake-up: $e');
    }
  }
}
