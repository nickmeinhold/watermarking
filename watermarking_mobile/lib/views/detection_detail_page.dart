import 'dart:io';

import 'package:flutter/material.dart';
import 'package:watermarking_core/watermarking_core.dart';

class DetectionDetailPage extends StatelessWidget {
  const DetectionDetailPage({super.key, required this.item});

  final DetectionItem item;

  @override
  Widget build(BuildContext context) {
    final stats = item.statistics;
    final hasStats = stats != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result card (uses platform-specific image)
            _buildResultCard(),
            const SizedBox(height: 16),

            if (hasStats) ...[
              // Signal strength gauge
              SignalStrengthCard(stats: stats),
              const SizedBox(height: 16),

              // PSNR bar chart
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                PsnrChartCard(stats: stats),
              const SizedBox(height: 16),

              // Timing breakdown
              if (stats.timing != null) TimingCard(timing: stats.timing!),
              const SizedBox(height: 16),

              // Technical details
              TechnicalDetailsCard(stats: stats),
              const SizedBox(height: 16),

              // Peak positions scatter
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                PeakPositionsCard(stats: stats),
              const SizedBox(height: 16),

              // PSNR Distribution Histogram
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                PsnrHistogramCard(stats: stats),
              const SizedBox(height: 16),

              // Peak Value vs RMS Scatter
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                PeakVsRmsCard(stats: stats),
              const SizedBox(height: 16),

              // Shift Values Chart
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                ShiftValuesCard(stats: stats),
              const SizedBox(height: 16),

              // Message Bit Visualization
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                MessageBitsCard(stats: stats, message: item.result),
              const SizedBox(height: 16),

              // Side-by-side Image Comparison
              _buildImageComparisonCard(),
            ] else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Extended statistics not available for this detection.\n\n'
                    'Run a new detection to see detailed analytics.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final localPath = item.extractedRef?.localPath;
    final servingUrl = item.extractedRef?.servingUrl;

    Widget imageWidget;
    if (localPath != null) {
      imageWidget = Image.file(File(localPath), fit: BoxFit.cover);
    } else if (servingUrl != null) {
      imageWidget = Image.network(servingUrl, fit: BoxFit.cover);
    } else {
      imageWidget = const ImagePlaceholder(text: 'No image');
    }

    return DetectionResultCard(
      result: item.result,
      confidence: item.confidence,
      detected: item.detected,
      imageWidget: imageWidget,
    );
  }

  Widget _buildImageComparisonCard() {
    final localPath = item.extractedRef?.localPath;
    final servingUrl = item.extractedRef?.servingUrl;
    final originalUrl = item.originalRef?.url;

    // Original image widget
    Widget originalWidget;
    if (originalUrl != null) {
      originalWidget = Image.network(
        originalUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No original'),
      );
    } else {
      originalWidget = const ImagePlaceholder(text: 'No original');
    }

    // Captured image widget
    Widget capturedWidget;
    if (localPath != null) {
      capturedWidget = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => servingUrl != null
            ? Image.network(
                servingUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No capture'),
              )
            : const ImagePlaceholder(text: 'No capture'),
      );
    } else if (servingUrl != null) {
      capturedWidget = Image.network(
        servingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No capture'),
      );
    } else {
      capturedWidget = const ImagePlaceholder(text: 'No capture');
    }

    return ImageComparisonCard(
      originalImageWidget: originalWidget,
      capturedImageWidget: capturedWidget,
    );
  }
}
