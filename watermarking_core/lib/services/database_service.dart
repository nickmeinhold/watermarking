import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/detection_stats.dart';
import 'package:watermarking_core/models/extracted_image_reference.dart';
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
          final aTimestamp = (aData['timestamp'] is Timestamp)
              ? aData['timestamp'] as Timestamp
              : null;
          final bTimestamp = (bData['timestamp'] is Timestamp)
              ? bData['timestamp'] as Timestamp
              : null;
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
            .where('userId', isEqualTo: userId)
            .get();

        final List<MarkedImageReference> markedImages =
            markedSnapshot.docs.map((markedDoc) {
          final markedData = markedDoc.data();
          return MarkedImageReference(
            id: markedDoc.id,
            message: markedData['message']?.toString(),
            name: markedData['name']?.toString(),
            strength: (markedData['strength'] is num)
                ? (markedData['strength'] as num).toInt()
                : (markedData['strength'] is String
                    ? int.tryParse(markedData['strength'] as String)
                    : null),
            path: markedData['path']?.toString(),
            servingUrl: markedData['servingUrl']?.toString(),
            progress: markedData['progress']?.toString(),
          );
        }).toList();

        imagesList.add(OriginalImageReference(
          id: doc.id,
          name: data['name']?.toString(),
          filePath: data['path']?.toString(),
          url: data['url']?.toString(),
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
        final originalImageId = data['originalImageId']?.toString();
        if (originalImageId == null) continue;

        markedByOriginal.putIfAbsent(originalImageId, () => []);
        markedByOriginal[originalImageId]!.add({
          'id': doc.id,
          'message': data['message']?.toString(),
          'name': data['name']?.toString(),
          'strength': data['strength'],
          'path': data['path']?.toString(),
          'servingUrl': data['servingUrl']?.toString(),
          'progress': data['progress']?.toString(),
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
        name: data?['name']?.toString() ?? '',
        email: data?['email']?.toString() ?? '',
      );
    });
  }

  Future<dynamic> cancelProfileSubscription() {
    return profileSubscription?.cancel() ?? Future<dynamic>.value(null);
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

    return docRef.id;
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
        id: data?['itemId']?.toString() ?? '',
        progress: data?['progress']?.toString() ?? '',
        result: resultsMap?['message']?.toString(),
        error: data?['error']?.toString(),
        pathMarked: data?['pathMarked']?.toString(),
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
      // Sort client-side to avoid requiring composite index
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTimestamp = aData['timestamp'];
          final bTimestamp = bData['timestamp'];
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
            return bTimestamp.compareTo(aTimestamp);
          }
          return 0;
        });
      final List<DetectionItem> list = sortedDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse extended statistics if available
        DetectionStatistics? statistics;
        if (data['timing'] != null ||
            data['sequences'] != null ||
            data['psnrStats'] != null) {
          statistics = DetectionStatistics.fromJson(data);
        }

        return DetectionItem(
          id: doc.id,
          progress: data['progress']?.toString() ?? '',
          result: data['result']?.toString(),
          confidence: (data['confidence'] is num)
              ? (data['confidence'] as num).toDouble()
              : null,
          detected: data['detected'] as bool?,
          statistics: statistics,
          isCaptured: data['isCaptured'] as bool?,
          originalRef: data['originalRef'] != null
              ? OriginalImageReference(
                  filePath: data['originalRef']['remotePath']?.toString(),
                  url: data['originalRef']['servingUrl']?.toString(),
                )
              : null,
          extractedRef: data['extractedRef'] != null
              ? ExtractedImageReference(
                  remotePath: data['extractedRef']['remotePath']?.toString(),
                  servingUrl: data['extractedRef']['servingUrl']?.toString(),
                )
              : (data['pathMarked'] != null || data['servingUrl'] != null
                  ? ExtractedImageReference(
                      remotePath: data['pathMarked']?.toString(),
                      servingUrl: data['servingUrl']?.toString(),
                    )
                  : null),
        );
      }).toList();

      return ActionSetDetectionItems(items: list);
    });
  }

  Future<dynamic> cancelDetectionItemsSubscription() {
    return detectionItemsSubscription?.cancel() ?? Future<dynamic>.value(null);
  }
}
