import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

import 'detection_detail_dialog.dart';

class MarkedImagesPage extends StatelessWidget {
  const MarkedImagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _CombinedViewModel>(
      converter: (Store<AppState> store) => _CombinedViewModel(
        originals: store.state.originals,
        detections: store.state.detections,
      ),
      builder: (BuildContext context, _CombinedViewModel viewModel) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Watermarking',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (viewModel.originals.selectedImage != null)
                    ElevatedButton.icon(
                      onPressed: () => _showMarkDialog(context, viewModel.originals),
                      icon: const Icon(Icons.water_drop),
                      label: const Text('Apply Watermark'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (viewModel.originals.selectedImage == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Select an original image first from the Original Images page.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Selected original image
                      Expanded(
                        flex: 1,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Original',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: viewModel.originals.selectedImage!.url != null
                                      ? Image.network(
                                          viewModel.originals.selectedImage!.url!,
                                          fit: BoxFit.contain,
                                        )
                                      : const Center(
                                          child: Icon(Icons.image, size: 64),
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  viewModel.originals.selectedImage!.name ?? 'Unnamed',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Column 2: Marked images
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Marked (${viewModel.originals.selectedImage!.markedCount})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: viewModel
                                          .originals.selectedImage!.markedImages.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'Click "Apply Watermark" to create a watermarked version.',
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        )
                                      : GridView.builder(
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 200,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 0.85,
                                          ),
                                          itemCount: viewModel.originals.selectedImage!
                                              .markedImages.length,
                                          itemBuilder: (context, index) {
                                            final marked = viewModel
                                                .originals.selectedImage!
                                                .markedImages[index];
                                            return _MarkedImageCard(
                                              marked: marked,
                                              originalPath: viewModel
                                                  .originals.selectedImage!.filePath!,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Column 3: Detection results (filtered to selected original)
                      Expanded(
                        flex: 2,
                        child: Builder(
                          builder: (context) {
                            // Get paths for the selected original and its marked images
                            final selectedOriginal = viewModel.originals.selectedImage!;
                            final originalPath = selectedOriginal.filePath;
                            final markedPaths = selectedOriginal.markedImages
                                .map((m) => m.path)
                                .whereType<String>()
                                .toSet();

                            // Filter detections to only those matching this original
                            final filteredDetections = viewModel.detections.items.where((item) {
                              // Match by original path (originalRef.filePath holds the remotePath from Firestore)
                              if (item.originalRef?.filePath == originalPath) return true;
                              // Match by marked/extracted path
                              final extractedPath = item.extractedRef?.remotePath;
                              if (extractedPath != null && markedPaths.contains(extractedPath)) return true;
                              return false;
                            }).toList();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Detection Results (${filteredDetections.length})',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: filteredDetections.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Click the detection icon on a marked image to verify the watermark.',
                                                style: TextStyle(color: Colors.grey),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: filteredDetections.length,
                                              itemBuilder: (context, index) {
                                                final item = filteredDetections[index];
                                                return _DetectionHistoryItem(item: item);
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMarkDialog(
      BuildContext context, OriginalImagesViewModel viewModel) async {
    final messageController = TextEditingController();
    double strength = 0.5;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void submitWatermark() {
              if (messageController.text.isNotEmpty) {
                final selectedImage = viewModel.selectedImage!;
                StoreProvider.of<AppState>(context).dispatch(
                  ActionMarkImage(
                    imageId: selectedImage.id!,
                    imageName: selectedImage.name!,
                    imagePath: selectedImage.filePath!,
                    message: messageController.text,
                    strength: strength * 10, // Convert 0-1 to 1-10 scale
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Watermarking "${selectedImage.name}" with message: ${messageController.text}'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Apply Watermark'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: messageController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Hidden Message',
                      hintText: 'Enter the message to embed',
                    ),
                    onSubmitted: (_) => submitWatermark(),
                  ),
                  const SizedBox(height: 24),
                  Text('Strength: ${(strength * 100).toInt()}%'),
                  Slider(
                    value: strength,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    onChanged: (value) {
                      setState(() {
                        strength = value;
                      });
                    },
                  ),
                  const Text(
                    'Higher strength = more visible but more robust',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitWatermark,
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MarkedImageCard extends StatelessWidget {
  const _MarkedImageCard({
    required this.marked,
    required this.originalPath,
  });

  final MarkedImageReference marked;
  final String originalPath;

  @override
  Widget build(BuildContext context) {
    final isProcessing = marked.isProcessing;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                isProcessing
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Center(
                          child: PipelineProgressWidget(
                            type: PipelineType.marking,
                            progress: marked.progress,
                          ),
                        ),
                      )
                    : Image.network(
                        marked.servingUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error,
                                    color: Colors.red, size: 32),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(
                                    'Error loading image',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.red[900]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () {
                        // Confirm delete
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Marked Image?'),
                              content: const Text(
                                  'This will delete the marked image file and remove it from the list.'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: const Text('Delete'),
                                  onPressed: () {
                                    StoreProvider.of<AppState>(context)
                                        .dispatch(
                                      ActionDeleteMarkedImage(
                                        markedImageId: marked.id!,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if (!isProcessing)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white70,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.analytics, color: Colors.purple),
                        tooltip: 'Run Detection',
                        onPressed: () {
                          StoreProvider.of<AppState>(context).dispatch(
                            ActionDetectMarkedImage(
                              markedImageId: marked.id!,
                              originalPath: originalPath,
                              markedPath: marked.path!,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Detection started...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (true) // Wrap directly to avoid potential syntax issues with previous conditional
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white70,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.open_in_new, color: Colors.blue),
                        tooltip: 'Open in New Window',
                        onPressed: () {
                          if (marked.servingUrl != null) {
                            launchUrl(Uri.parse(marked.servingUrl!));
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message: ${marked.message ?? "N/A"}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Strength: ${marked.strength ?? "N/A"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Combined view model for originals and detections
class _CombinedViewModel {
  const _CombinedViewModel({
    required this.originals,
    required this.detections,
  });

  final OriginalImagesViewModel originals;
  final DetectionItemsViewModel detections;
}

/// Detection history item widget
class _DetectionHistoryItem extends StatelessWidget {
  const _DetectionHistoryItem({required this.item});

  final DetectionItem item;

  bool get _isProcessing {
    final progress = item.progress;
    if (progress == null) return false;
    if (progress == '100') return false;
    if (progress.toLowerCase().contains('complete')) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final remotePath = item.extractedRef?.remotePath;
    final isStoragePath = remotePath != null && !remotePath.startsWith('http');

    // Processing items show pipeline progress
    if (_isProcessing) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => DetectionDetailDialog.show(context, item),
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: PipelineProgressWidget(
                type: PipelineType.detection,
                progress: item.progress,
                hasError: item.error != null,
              ),
            ),
          ),
        ),
      );
    }

    // Completed items show compact list tile
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => DetectionDetailDialog.show(context, item),
        leading: remotePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: isStoragePath
                    ? FutureBuilder<String>(
                        future: StorageService().getDownloadUrl(remotePath),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            return Image.network(
                              snapshot.data!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            );
                          }
                          return const SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                      )
                    : Image.network(
                        remotePath,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 48),
                      ),
              )
            : const Icon(Icons.image_outlined, size: 48),
        title: Text(
          item.result ?? 'Processing...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_getStatusText(item)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _getStatusIcon(item),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  String _getStatusText(DetectionItem item) {
    if (item.confidence != null) {
      return 'Confidence: ${item.confidence!.toStringAsFixed(1)}';
    }
    final progress = item.progress;
    if (progress != null && progress != '100') {
      return progress;
    }
    if (item.result != null) return 'Complete';
    return 'Pending';
  }

  Widget _getStatusIcon(DetectionItem item) {
    if (item.error != null) {
      return const Icon(Icons.error, color: Colors.red, size: 20);
    }
    if (item.result != null) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
