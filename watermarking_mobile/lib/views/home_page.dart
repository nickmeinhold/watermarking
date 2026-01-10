import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

import 'detection_card.dart';

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
          // Check if there's an active detection (first item has no result)
          final hasActiveDetection = items.isNotEmpty && items.first.result == null;

          // Filter to only show completed items in the list when pipeline is showing
          final completedItems = hasActiveDetection
              ? items.where((item) => item.result != null).toList()
              : items;

          return Column(
            children: <Widget>[
              if (hasActiveDetection)
                DetectionSteps(items.first),
              Expanded(
                child: completedItems.isEmpty
                    ? Center(
                        child: Text(
                          hasActiveDetection
                              ? 'Detection in progress...'
                              : 'No detection history yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: completedItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          final item = completedItems[index];
                          return DetectionCard(
                            item: item,
                            onDismissed: () {
                              if (item.id != null) {
                                StoreProvider.of<AppState>(context).dispatch(
                                  ActionDeleteDetectionItem(
                                      detectionItemId: item.id!),
                                );
                              }
                            },
                          );
                        }),
              )
            ],
          );
        });
  }
}

class DetectionSteps extends StatelessWidget {
  const DetectionSteps(
    this.firstItem, {
    super.key,
  });

  final DetectionItem firstItem;

  /// Map the detection item state to a progress string for the pipeline widget
  String? get _progressString {
    final uploadPercent = firstItem.extractedRef?.upload?.percent ?? 0;

    // If uploading, show upload progress
    if (uploadPercent < 1) {
      final percent = (uploadPercent * 100).toInt();
      return 'Uploading captured image: $percent%';
    }

    // If no progress yet from server, we're waiting for server to pick up task
    if (firstItem.progress == null) {
      return 'Server processing...';
    }

    // Use the server's progress string
    return firstItem.progress;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: PipelineProgressWidget(
            type: PipelineType.detection,
            progress: _progressString,
            hasError: firstItem.error != null,
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
