import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DetectionHistoryListView();
  }
}

class DetectionHistoryListView extends StatelessWidget {
  const DetectionHistoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<DetectionItem>>(
        converter: (Store<AppState> store) => store.state.detections.items,
        builder: (BuildContext context, List<DetectionItem> items) {
          return Column(
            children: <Widget>[
              if (items.isNotEmpty && items.first.result == null)
                DetectionSteps(items.first),
              Expanded(
                child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final item = items[index];
                      final localPath = item.extractedRef?.localPath;
                      final servingUrl = item.extractedRef?.servingUrl;
                      final started = item.extractedRef?.upload?.started;
                      return Dismissible(
                        key: Key(item.id ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          if (item.id != null) {
                            StoreProvider.of<AppState>(context).dispatch(
                              ActionDeleteDetectionItem(
                                  detectionItemId: item.id!),
                            );
                          }
                        },
                        child: Center(
                          child: Card(
                            color: (item.result == null)
                                ? Colors.blueGrey
                                : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Extracted image thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: localPath != null
                                          ? Image.file(
                                              File(localPath),
                                              fit: BoxFit.cover,
                                            )
                                          : servingUrl != null
                                              ? Image.network(
                                                  servingUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stack) =>
                                                          _imagePlaceholder(),
                                                )
                                              : _imagePlaceholder(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Detection info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.result ?? 'Processing...',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: item.result == null
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (item.confidence != null)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.verified,
                                                size: 16,
                                                color: _confidenceColor(
                                                    item.confidence!),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Confidence: ${item.confidence!.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  color: _confidenceColor(
                                                      item.confidence!),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (started != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              _formatDate(started),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: item.result == null
                                                    ? Colors.white54
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
              )
            ],
          );
        });
  }
}

Widget _imagePlaceholder() {
  return Container(
    color: Colors.grey.shade300,
    child: const Icon(
      Icons.image,
      size: 40,
      color: Colors.grey,
    ),
  );
}

Color _confidenceColor(double confidence) {
  if (confidence >= 10) return Colors.green;
  if (confidence >= 7) return Colors.orange;
  return Colors.red;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class DetectionSteps extends StatelessWidget {
  const DetectionSteps(
    this.firstItem, {
    super.key,
  });

  final DetectionItem firstItem;

  @override
  Widget build(BuildContext context) {
    int currentStep = 2;
    final uploadPercent = firstItem.extractedRef?.upload?.percent ?? 0;
    if (uploadPercent < 1) {
      currentStep = 0;
    } else if (firstItem.progress == null) {
      currentStep = 1;
    }
    return Column(
      children: <Widget>[
        Container(
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 5),
          height: 200,
          child: Theme(
            data: ThemeData(
              primaryColor: Colors.red,
            ),
            child: Stepper(
              currentStep: currentStep,
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return const SizedBox.shrink();
              },
              type: StepperType.horizontal,
              steps: [
                Step(
                  title: const Text('Upload'),
                  content: LinearProgressIndicator(value: uploadPercent),
                  isActive: currentStep == 0,
                  state: (currentStep > 0)
                      ? StepState.complete
                      : StepState.indexed,
                ),
                Step(
                  title: const Text('Setup'),
                  content: const Center(child: CircularProgressIndicator()),
                  isActive: currentStep == 1,
                  state: (currentStep > 1)
                      ? StepState.complete
                      : StepState.indexed,
                ),
                Step(
                  title: const Text('Detect'),
                  content: Text(firstItem.progress ?? ''),
                  isActive: currentStep == 2,
                  state: firstItem.error != null
                      ? StepState.error
                      : (currentStep > 2)
                          ? StepState.complete
                          : StepState.indexed,
                ),
              ],
              onStepTapped: (int step) {},
            ),
          ),
        ),
        if (firstItem.error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    firstItem.error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
