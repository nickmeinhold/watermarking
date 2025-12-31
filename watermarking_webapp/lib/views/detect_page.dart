import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class DetectPage extends StatefulWidget {
  const DetectPage({super.key});

  @override
  State<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  PlatformFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, DetectionItemsViewModel>(
      converter: (Store<AppState> store) => store.state.detections,
      builder: (BuildContext context, DetectionItemsViewModel viewModel) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detect Watermark',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload section
                    Expanded(
                      flex: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upload Image to Analyze',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _selectedFile != null
                                    ? Column(
                                        children: [
                                          Expanded(
                                            child: _selectedFile!.bytes != null
                                                ? Image.memory(
                                                    _selectedFile!.bytes!,
                                                    fit: BoxFit.contain,
                                                  )
                                                : const Center(
                                                    child: Icon(Icons.image,
                                                        size: 64),
                                                  ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(_selectedFile!.name),
                                        ],
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.upload_file,
                                              size: 64,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              onPressed: _pickFile,
                                              icon: const Icon(Icons.upload),
                                              label: const Text('Select Image'),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: [
                                  if (_selectedFile != null)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedFile = null;
                                        });
                                      },
                                      child: const Text('Clear'),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: _selectedFile != null
                                        ? () => _startDetection(context)
                                        : null,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Detect Watermark'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Detection history
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detection History',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: viewModel.items.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No detection history yet.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: viewModel.items.length,
                                        itemBuilder: (context, index) {
                                          final item = viewModel.items[index];
                                          return _DetectionHistoryItem(
                                              item: item);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  void _startDetection(BuildContext context) {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;

    // TODO: Implement web detection flow
    // This will need to:
    // 1. Upload the image to Firebase Storage
    // 2. Create a detection task in the database queue
    // 3. Wait for backend to process and return results

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting detection for: ${_selectedFile!.name}'),
      ),
    );
  }
}

class _DetectionHistoryItem extends StatelessWidget {
  const _DetectionHistoryItem({required this.item});

  final DetectionItem item;

  @override
  Widget build(BuildContext context) {
    // If we have a remote path, we might need to resolve it locally if it's a storage path
    // We can guess it's a storage path if it doesn't start with http
    final remotePath = item.extractedRef?.remotePath;
    final isStoragePath = remotePath != null && !remotePath.startsWith('http');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: remotePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: isStoragePath
                    ? FutureBuilder<String>(
                        future: StorageService().getDownloadUrl(remotePath!),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
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
        title: Text(item.result ?? 'Processing...'),
        subtitle: Text(_getStatusText(item)),
        trailing: _getStatusIcon(item),
      ),
    );
  }

  String _getStatusText(DetectionItem item) {
    final progress = item.progress;
    if (progress != null && progress != '100') {
      return 'Progress: $progress%';
    }
    if (item.result != null) return 'Complete';
    return 'Pending';
  }

  Widget _getStatusIcon(DetectionItem item) {
    if (item.result != null) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    final progress = item.progress;
    if (progress == null ||
        (progress != '100' && progress != 'Detection complete.')) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return const Icon(Icons.check_circle, color: Colors.green);
  }
}
