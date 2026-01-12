import 'package:flutter_test/flutter_test.dart';
import 'package:watermarking_core/models/app_state.dart';
import 'package:watermarking_core/models/bottom_nav_view_model.dart';
import 'package:watermarking_core/models/detection_item.dart';
import 'package:watermarking_core/models/detection_items_view_model.dart';
import 'package:watermarking_core/models/extracted_image_reference.dart';
import 'package:watermarking_core/models/file_upload.dart';
import 'package:watermarking_core/models/original_image_reference.dart';
import 'package:watermarking_core/models/original_images_view_model.dart';
import 'package:watermarking_core/models/problem.dart';
import 'package:watermarking_core/models/user_model.dart';
import 'package:watermarking_core/redux/actions.dart';
import 'package:watermarking_core/redux/reducers.dart';

void main() {
  late AppState initialState;

  setUp(() {
    initialState = AppState.initialState();
  });

  group('appReducer', () {
    test('returns initial state for unknown action', () {
      final result = appReducer(initialState, const Action(<String, Object>{}));
      // Unknown actions should not modify state
      expect(result.user, equals(initialState.user));
    });
  });

  group('_setAuthState', () {
    test('sets user id and photo url', () {
      final action = ActionSetAuthState(
        userId: 'user-123',
        photoUrl: 'https://example.com/photo.jpg',
      );

      final result = appReducer(initialState, action);

      expect(result.user.id, equals('user-123'));
      expect(result.user.photoUrl, equals('https://example.com/photo.jpg'));
      expect(result.user.waiting, isFalse);
    });

    test('handles null userId', () {
      final action = ActionSetAuthState(userId: null);

      final result = appReducer(initialState, action);

      expect(result.user.id, isNull);
      expect(result.user.waiting, isFalse);
    });
  });

  group('_setProfilePicUrl', () {
    test('updates photo url', () {
      final stateWithUser = initialState.copyWith(
        user: const UserModel(id: 'user-1', photoUrl: 'old-url'),
      );
      final action = ActionSetProfilePicUrl(url: 'new-url');

      final result = appReducer(stateWithUser, action);

      expect(result.user.photoUrl, equals('new-url'));
      expect(result.user.id, equals('user-1'));
    });
  });

  group('_setOriginalImages', () {
    test('sets images list', () {
      const images = [
        OriginalImageReference(id: 'img-1', name: 'test1.png'),
        OriginalImageReference(id: 'img-2', name: 'test2.png'),
      ];
      final action = ActionSetOriginalImages(images: images);

      final result = appReducer(initialState, action);

      expect(result.originals.images.length, equals(2));
      expect(result.originals.images[0].id, equals('img-1'));
      expect(result.originals.images[1].name, equals('test2.png'));
    });

    test('replaces existing images', () {
      final stateWithImages = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [OriginalImageReference(id: 'old')],
        ),
      );
      final action = ActionSetOriginalImages(
        images: [const OriginalImageReference(id: 'new')],
      );

      final result = appReducer(stateWithImages, action);

      expect(result.originals.images.length, equals(1));
      expect(result.originals.images[0].id, equals('new'));
    });
  });

  group('_updateMarkedImages', () {
    test('updates marked images for existing originals', () {
      final stateWithImages = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [
            OriginalImageReference(id: 'orig-1', name: 'test.png'),
          ],
        ),
      );

      final action = ActionUpdateMarkedImages(
        markedImagesByOriginal: {
          'orig-1': [
            {
              'id': 'marked-1',
              'message': 'TEST',
              'strength': 100,
              'servingUrl': 'https://example.com/marked.png',
            },
          ],
        },
      );

      final result = appReducer(stateWithImages, action);

      expect(result.originals.images[0].markedImages.length, equals(1));
      expect(result.originals.images[0].markedImages[0].id, equals('marked-1'));
      expect(result.originals.images[0].markedImages[0].message, equals('TEST'));
      expect(result.originals.images[0].markedImages[0].strength, equals(100));
    });

    test('handles strength as num', () {
      final stateWithImages = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [OriginalImageReference(id: 'orig-1')],
        ),
      );

      final action = ActionUpdateMarkedImages(
        markedImagesByOriginal: {
          'orig-1': [
            {'id': 'marked-1', 'strength': 50.5}, // double
          ],
        },
      );

      final result = appReducer(stateWithImages, action);

      expect(result.originals.images[0].markedImages[0].strength, equals(50));
    });

    test('handles strength as String', () {
      final stateWithImages = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [OriginalImageReference(id: 'orig-1')],
        ),
      );

      final action = ActionUpdateMarkedImages(
        markedImagesByOriginal: {
          'orig-1': [
            {'id': 'marked-1', 'strength': '75'},
          ],
        },
      );

      final result = appReducer(stateWithImages, action);

      expect(result.originals.images[0].markedImages[0].strength, equals(75));
    });

    test('updates selectedImage if present', () {
      const selectedImage = OriginalImageReference(id: 'orig-1');
      final stateWithSelected = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [selectedImage],
          selectedImage: selectedImage,
        ),
      );

      final action = ActionUpdateMarkedImages(
        markedImagesByOriginal: {
          'orig-1': [
            {'id': 'marked-1', 'message': 'MSG'},
          ],
        },
      );

      final result = appReducer(stateWithSelected, action);

      expect(result.originals.selectedImage!.markedImages.length, equals(1));
      expect(result.originals.selectedImage!.markedImages[0].message, equals('MSG'));
    });

    test('handles original with no marked images', () {
      final stateWithImages = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          images: [OriginalImageReference(id: 'orig-1')],
        ),
      );

      final action = ActionUpdateMarkedImages(
        markedImagesByOriginal: {}, // no marked images
      );

      final result = appReducer(stateWithImages, action);

      expect(result.originals.images[0].markedImages, isEmpty);
    });
  });

  group('_setDetectionItems', () {
    test('sets detection items from Firestore', () {
      final items = [
        const DetectionItem(id: 'det-1', result: 'ABC'),
        const DetectionItem(id: 'det-2', result: 'DEF'),
      ];
      final action = ActionSetDetectionItems(items: items);

      final result = appReducer(initialState, action);

      expect(result.detections.items.length, equals(2));
      expect(result.detections.items[0].result, equals('ABC'));
    });

    test('merges with in-progress local items', () {
      // State has local item with no result (in-progress)
      final stateWithLocal = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [DetectionItem(id: 'local-1', result: null)],
        ),
      );

      // Firestore returns different item
      final action = ActionSetDetectionItems(
        items: [const DetectionItem(id: 'firestore-1', result: 'ABC')],
      );

      final result = appReducer(stateWithLocal, action);

      // Should have both: local in-progress + firestore
      expect(result.detections.items.length, equals(2));
      expect(
        result.detections.items.any((i) => i.id == 'local-1'),
        isTrue,
      );
      expect(
        result.detections.items.any((i) => i.id == 'firestore-1'),
        isTrue,
      );
    });

    test('does not duplicate items that exist in both', () {
      // State has item that also exists in Firestore
      final stateWithLocal = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [DetectionItem(id: 'item-1', result: null)],
        ),
      );

      // Firestore returns same item with result
      final action = ActionSetDetectionItems(
        items: [const DetectionItem(id: 'item-1', result: 'ABC')],
      );

      final result = appReducer(stateWithLocal, action);

      // Should only have one item (from Firestore since it has result)
      expect(result.detections.items.length, equals(1));
      expect(result.detections.items[0].result, equals('ABC'));
    });
  });

  group('_deleteDetectionItem', () {
    test('removes item by id', () {
      final stateWithItems = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [
            DetectionItem(id: 'keep'),
            DetectionItem(id: 'delete'),
          ],
        ),
      );

      final action = ActionDeleteDetectionItem(detectionItemId: 'delete');

      final result = appReducer(stateWithItems, action);

      expect(result.detections.items.length, equals(1));
      expect(result.detections.items[0].id, equals('keep'));
    });

    test('does nothing if item not found', () {
      final stateWithItems = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [DetectionItem(id: 'existing')],
        ),
      );

      final action = ActionDeleteDetectionItem(detectionItemId: 'nonexistent');

      final result = appReducer(stateWithItems, action);

      expect(result.detections.items.length, equals(1));
    });
  });

  group('_addDetectionItem', () {
    test('adds new detection item with extracted reference', () {
      final stateWithSelected = initialState.copyWith(
        originals: const OriginalImagesViewModel(
          selectedImage: OriginalImageReference(id: 'orig-1'),
        ),
      );

      final action = ActionAddDetectionItem(
        id: 'det-1',
        extractedPath: '/path/to/extracted.png',
        bytes: 1024,
      );

      final result = appReducer(stateWithSelected, action);

      expect(result.detections.items.length, equals(1));
      expect(result.detections.items[0].id, equals('det-1'));
      expect(result.detections.items[0].extractedRef?.localPath,
          equals('/path/to/extracted.png'));
      expect(result.detections.items[0].extractedRef?.bytes, equals(1024));
      expect(result.detections.items[0].originalRef?.id, equals('orig-1'));
      expect(result.detections.items[0].started, isNotNull);
    });

    test('prepends to existing items', () {
      final stateWithItems = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [DetectionItem(id: 'existing')],
        ),
      );

      final action = ActionAddDetectionItem(
        id: 'new',
        extractedPath: '/path',
        bytes: 100,
      );

      final result = appReducer(stateWithItems, action);

      expect(result.detections.items.length, equals(2));
      expect(result.detections.items[0].id, equals('new')); // prepended
      expect(result.detections.items[1].id, equals('existing'));
    });
  });

  group('_setUploadProgress', () {
    test('updates upload progress for matching item', () {
      final stateWithItem = initialState.copyWith(
        detections: DetectionItemsViewModel(
          items: [
            DetectionItem(
              id: 'det-1',
              extractedRef: const ExtractedImageReference(
                bytes: 1000,
                upload: FileUpload(bytesSent: 0, percent: 0),
              ),
            ),
          ],
        ),
      );

      final action = ActionSetUploadProgress(id: 'det-1', bytes: 500);

      final result = appReducer(stateWithItem, action);

      expect(result.detections.items[0].extractedRef?.upload?.bytesSent,
          equals(500));
      expect(result.detections.items[0].extractedRef?.upload?.percent,
          equals(0.5));
      expect(result.detections.items[0].extractedRef?.upload?.latestEvent,
          equals(UploadingEvent.progress));
    });

    test('handles null bytes with default of 1 to avoid division by zero', () {
      final stateWithItem = initialState.copyWith(
        detections: DetectionItemsViewModel(
          items: [
            DetectionItem(
              id: 'det-1',
              extractedRef: const ExtractedImageReference(
                bytes: null, // null bytes
                upload: FileUpload(bytesSent: 0, percent: 0),
              ),
            ),
          ],
        ),
      );

      final action = ActionSetUploadProgress(id: 'det-1', bytes: 100);

      final result = appReducer(stateWithItem, action);

      // Should use 1 as default divisor
      expect(result.detections.items[0].extractedRef?.upload?.percent,
          equals(100.0));
    });

    test('does not modify other items', () {
      final stateWithItems = initialState.copyWith(
        detections: DetectionItemsViewModel(
          items: [
            DetectionItem(
              id: 'det-1',
              extractedRef: const ExtractedImageReference(
                bytes: 1000,
                upload: FileUpload(bytesSent: 0),
              ),
            ),
            DetectionItem(
              id: 'det-2',
              extractedRef: const ExtractedImageReference(
                bytes: 2000,
                upload: FileUpload(bytesSent: 0),
              ),
            ),
          ],
        ),
      );

      final action = ActionSetUploadProgress(id: 'det-1', bytes: 500);

      final result = appReducer(stateWithItems, action);

      expect(result.detections.items[0].extractedRef?.upload?.bytesSent,
          equals(500));
      expect(result.detections.items[1].extractedRef?.upload?.bytesSent,
          equals(0)); // unchanged
    });
  });

  group('_setDetectingProgress', () {
    test('updates existing item with progress', () {
      final stateWithItem = initialState.copyWith(
        detections: const DetectionItemsViewModel(
          items: [DetectionItem(id: 'det-1')],
        ),
      );

      final action = ActionSetDetectingProgress(
        id: 'det-1',
        progress: 'Processing...',
        result: 'ABC',
      );

      final result = appReducer(stateWithItem, action);

      expect(result.detections.items[0].progress, equals('Processing...'));
      expect(result.detections.items[0].result, equals('ABC'));
    });

    test('adds new item if not found', () {
      final action = ActionSetDetectingProgress(
        id: 'new-det',
        progress: 'Starting...',
        pathMarked: '/path/to/marked.png',
      );

      final result = appReducer(initialState, action);

      expect(result.detections.items.length, equals(1));
      expect(result.detections.items[0].id, equals('new-det'));
      expect(result.detections.items[0].progress, equals('Starting...'));
      expect(result.detections.items[0].extractedRef?.remotePath,
          equals('/path/to/marked.png'));
    });

    test('does not add item with empty id', () {
      final action = ActionSetDetectingProgress(
        id: '',
        progress: 'test',
      );

      final result = appReducer(initialState, action);

      expect(result.detections.items, isEmpty);
    });

    test('preserves existing extractedRef fields when updating', () {
      final stateWithItem = initialState.copyWith(
        detections: DetectionItemsViewModel(
          items: [
            DetectionItem(
              id: 'det-1',
              extractedRef: const ExtractedImageReference(
                localPath: '/local/path',
                bytes: 1024,
                upload: FileUpload(bytesSent: 500),
              ),
            ),
          ],
        ),
      );

      final action = ActionSetDetectingProgress(
        id: 'det-1',
        progress: 'Done',
        pathMarked: '/remote/path',
      );

      final result = appReducer(stateWithItem, action);

      // Should preserve existing fields
      expect(result.detections.items[0].extractedRef?.localPath,
          equals('/local/path'));
      expect(result.detections.items[0].extractedRef?.bytes, equals(1024));
      // Should update remotePath
      expect(result.detections.items[0].extractedRef?.remotePath,
          equals('/remote/path'));
    });
  });

  group('_setBottomNav', () {
    test('updates bottom nav index', () {
      final action = ActionSetBottomNav(index: 2);

      final result = appReducer(initialState, action);

      expect(result.bottomNav.index, equals(2));
    });
  });

  group('_setBottomSheet', () {
    test('shows bottom sheet', () {
      final action = ActionShowBottomSheet(show: true);

      final result = appReducer(initialState, action);

      expect(result.bottomNav.shouldShowBottomSheet, isTrue);
    });

    test('hides bottom sheet', () {
      final stateWithSheet = initialState.copyWith(
        bottomNav: const BottomNavViewModel(shouldShowBottomSheet: true),
      );
      final action = ActionShowBottomSheet(show: false);

      final result = appReducer(stateWithSheet, action);

      expect(result.bottomNav.shouldShowBottomSheet, isFalse);
    });
  });

  group('_setSelectedImage', () {
    test('sets selected image with dimensions', () {
      const image = OriginalImageReference(id: 'img-1', name: 'test.png');
      final action = ActionSetSelectedImage(
        image: image,
        width: 1920,
        height: 1080,
      );

      final result = appReducer(initialState, action);

      expect(result.originals.selectedImage?.id, equals('img-1'));
      expect(result.originals.selectedWidth, equals(1920));
      expect(result.originals.selectedHeight, equals(1080));
    });

    test('hides bottom sheet when selecting image', () {
      final stateWithSheet = initialState.copyWith(
        bottomNav: const BottomNavViewModel(shouldShowBottomSheet: true),
      );
      final action = ActionSetSelectedImage(
        image: const OriginalImageReference(id: 'img-1'),
        width: 100,
        height: 100,
      );

      final result = appReducer(stateWithSheet, action);

      expect(result.bottomNav.shouldShowBottomSheet, isFalse);
    });
  });

  group('_addProblem', () {
    test('adds problem to list', () {
      const problem = Problem(
        type: ProblemType.images,
        message: 'Test error',
      );
      final action = ActionAddProblem(problem: problem);

      final result = appReducer(initialState, action);

      expect(result.problems.length, equals(1));
      expect(result.problems[0].message, equals('Test error'));
    });

    test('updates upload status on imageUpload problem', () {
      final stateWithItem = initialState.copyWith(
        detections: DetectionItemsViewModel(
          items: [
            DetectionItem(
              id: 'det-1',
              extractedRef: const ExtractedImageReference(
                upload: FileUpload(latestEvent: UploadingEvent.progress),
              ),
            ),
          ],
        ),
      );

      final problem = Problem(
        type: ProblemType.imageUpload,
        message: 'Upload failed',
        info: {'id': 'det-1'},
      );
      final action = ActionAddProblem(problem: problem);

      final result = appReducer(stateWithItem, action);

      expect(result.detections.items[0].extractedRef?.upload?.latestEvent,
          equals(UploadingEvent.failure));
      expect(result.problems.length, equals(1));
    });
  });

  group('_removeProblem', () {
    test('removes problem from list', () {
      const problem = Problem(type: ProblemType.images, message: 'Error');
      final stateWithProblem = initialState.copyWith(
        problems: [problem],
      );

      final action = ActionRemoveProblem(problem: problem);

      final result = appReducer(stateWithProblem, action);

      expect(result.problems, isEmpty);
    });
  });

  group('state immutability', () {
    test('original state is not modified', () {
      final originalItems = initialState.detections.items;

      final action = ActionAddDetectionItem(
        id: 'new',
        extractedPath: '/path',
        bytes: 100,
      );
      appReducer(initialState, action);

      expect(initialState.detections.items, equals(originalItems));
      expect(initialState.detections.items, isEmpty);
    });
  });
}
