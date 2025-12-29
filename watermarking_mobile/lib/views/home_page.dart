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
                      final originalUrl = item.originalRef?.url;
                      final localPath = item.extractedRef?.localPath;
                      final started = item.extractedRef?.upload?.started;
                      return Center(
                        child: Card(
                          color: (item.result == null)
                              ? Colors.blueGrey
                              : Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ListTile(
                                leading: originalUrl != null
                                    ? Image.network(originalUrl)
                                    : const Icon(Icons.image),
                                title: Text(item.result ?? ''),
                                subtitle: Text(
                                  started?.toIso8601String() ?? '',
                                ),
                                trailing: localPath != null
                                    ? Image.file(File(localPath))
                                    : null,
                              ),
                            ],
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
