import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:go_router/go_router.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class OriginalImagesPage extends StatelessWidget {
  const OriginalImagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, OriginalImagesViewModel>(
      converter: (Store<AppState> store) => store.state.originals,
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
                          return _ImageCard(
                            image: image,
                            isSelected: isSelected,
                            onTap: () {
                              StoreProvider.of<AppState>(context).dispatch(
                                ActionSetSelectedImage(
                                  image: image,
                                  width: 512,
                                  height: 512,
                                ),
                              );
                            },
                            onDoubleTap: () {
                              StoreProvider.of<AppState>(context).dispatch(
                                ActionSetSelectedImage(
                                  image: image,
                                  width: 512,
                                  height: 512,
                                ),
                              );
                              context.go('/marked');
                            },
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
          SnackBar(content: Text('Uploading ${file.name}...')),
        );

        try {
          // Decode image to get dimensions
          final Completer<ui.Image> completer = Completer<ui.Image>();
          ui.decodeImageFromList(file.bytes!, (ui.Image img) {
            completer.complete(img);
          });
          final ui.Image image = await completer.future;
          final int width = image.width;
          final int height = image.height;

          if (context.mounted) {
            // Dispatch upload action
            StoreProvider.of<AppState>(context).dispatch(
              ActionUploadOriginalImage(
                fileName: file.name,
                bytes: file.bytes!,
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
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.image,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  final OriginalImageReference image;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

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
          ],
        ),
      ),
    );
  }
}
