import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class OriginalImagesPage extends StatefulWidget {
  const OriginalImagesPage({super.key});

  @override
  State<OriginalImagesPage> createState() => _OriginalImagesPageState();
}

class _OriginalImagesPageState extends State<OriginalImagesPage> {
  final Set<String> _pendingDeletions = {};

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, OriginalImagesViewModel>(
      converter: (Store<AppState> store) => store.state.originals,
      onDidChange: (previous, current) {
        // Remove from pending deletions when item disappears from list
        final currentIds = current.images.map((i) => i.id).toSet();
        setState(() {
          _pendingDeletions.removeWhere((id) => !currentIds.contains(id));
        });
      },
      builder: (BuildContext context, OriginalImagesViewModel viewModel) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Original Images',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _uploadImage(context),
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Image'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: viewModel.images.isEmpty
                    ? const Center(
                        child: Text(
                          'No images yet. Upload your first image to get started.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1,
                        ),
                        itemCount: viewModel.images.length,
                        itemBuilder: (context, index) {
                          final image = viewModel.images[index];
                          final isSelected = image == viewModel.selectedImage;
                          final isDeleting = _pendingDeletions.contains(image.id);
                          return _ImageCard(
                            image: image,
                            isSelected: isSelected,
                            isDeleting: isDeleting,
                            onTap: isDeleting
                                ? null
                                : () {
                                    StoreProvider.of<AppState>(context).dispatch(
                                      ActionSetSelectedImage(
                                        image: image,
                                        width: 512,
                                        height: 512,
                                      ),
                                    );
                                  },
                            onDoubleTap: isDeleting
                                ? null
                                : () {
                                    StoreProvider.of<AppState>(context).dispatch(
                                      ActionSetSelectedImage(
                                        image: image,
                                        width: 512,
                                        height: 512,
                                      ),
                                    );
                                    context.go('/marked');
                                  },
                            onDelete: isDeleting
                                ? null
                                : () => _confirmDelete(context, image),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const int _maxDimension = 1024;
  static const int _minDimension = 512;

  Future<void> _uploadImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty && context.mounted) {
      final file = result.files.first;
      if (file.bytes != null) {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing ${file.name}...')),
        );

        try {
          // Decode image to get dimensions
          final Completer<ui.Image> completer = Completer<ui.Image>();
          ui.decodeImageFromList(file.bytes!, (ui.Image img) {
            completer.complete(img);
          });
          final ui.Image image = await completer.future;
          int width = image.width;
          int height = image.height;

          // Reject images that are too small for watermarking
          final largestDimension = width > height ? width : height;
          if (largestDimension < _minDimension) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Image too small (${width}x$height). Minimum ${_minDimension}px required for watermarking.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          Uint8List bytesToUpload = file.bytes!;

          // Resize if image exceeds max dimension
          if (width > _maxDimension || height > _maxDimension) {
            final resized = await _resizeImage(file.bytes!, width, height);
            bytesToUpload = resized.bytes;
            width = resized.width;
            height = resized.height;
          }

          if (context.mounted) {
            // Dispatch upload action
            StoreProvider.of<AppState>(context).dispatch(
              ActionUploadOriginalImage(
                fileName: file.name,
                bytes: bytesToUpload,
                width: width,
                height: height,
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Uploaded ${file.name} (${width}x$height)')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading: $e')),
            );
          }
        }
      }
    }
  }

  void _confirmDelete(BuildContext context, OriginalImageReference image) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text(
          'Delete "${image.name}"? This will also delete all ${image.markedCount} marked versions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _pendingDeletions.add(image.id!);
              });
              StoreProvider.of<AppState>(context).dispatch(
                ActionDeleteOriginalImage(originalImageId: image.id!),
              );
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Resize image using browser Canvas API (fast native resize)
  Future<({Uint8List bytes, int width, int height})> _resizeImage(
    Uint8List originalBytes,
    int originalWidth,
    int originalHeight,
  ) async {
    // Calculate new dimensions maintaining aspect ratio
    double scale = _maxDimension / (originalWidth > originalHeight ? originalWidth : originalHeight);
    int newWidth = (originalWidth * scale).round();
    int newHeight = (originalHeight * scale).round();

    // Create blob from bytes
    final blob = web.Blob([originalBytes.toJS].toJS);
    final imageUrl = web.URL.createObjectURL(blob);

    // Load image
    final imgElement = web.HTMLImageElement();
    final loadCompleter = Completer<void>();
    imgElement.onLoad.first.then((_) => loadCompleter.complete());
    imgElement.onError.first.then((_) => loadCompleter.completeError('Failed to load image'));
    imgElement.src = imageUrl;
    await loadCompleter.future;

    // Create canvas and draw resized image
    final canvas = web.HTMLCanvasElement();
    canvas.width = newWidth;
    canvas.height = newHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImageScaled(imgElement, 0, 0, newWidth.toDouble(), newHeight.toDouble());

    // Get resized image as PNG blob
    final blobCompleter = Completer<web.Blob>();
    canvas.toBlob((web.Blob? blob) {
      if (blob != null) {
        blobCompleter.complete(blob);
      } else {
        blobCompleter.completeError('Failed to create blob');
      }
    }.toJS, 'image/png');
    final resizedBlob = await blobCompleter.future;

    // Convert blob to Uint8List
    final arrayBuffer = await resizedBlob.arrayBuffer().toDart;
    final resizedBytes = arrayBuffer.toDart.asUint8List();

    // Cleanup
    web.URL.revokeObjectURL(imageUrl);

    return (bytes: resizedBytes, width: newWidth, height: newHeight);
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.image,
    required this.isSelected,
    required this.isDeleting,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDelete,
  });

  final OriginalImageReference image;
  final bool isSelected;
  final bool isDeleting;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: image.url != null
                      ? Image.network(
                          image.url!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.image, size: 48),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    image.name ?? 'Unnamed',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Badge showing marked count
            if (image.markedCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${image.markedCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Delete button
            if (!isDeleting)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: onDelete,
                ),
              ),
            // Deleting overlay
            if (isDeleting)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'Deleting...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
