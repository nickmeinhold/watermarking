import 'package:flutter/material.dart';
import 'package:watermarking_core/watermarking_core.dart';

/// Dialog showing detailed detection statistics for web.
class DetectionDetailDialog extends StatelessWidget {
  const DetectionDetailDialog({super.key, required this.item});

  final DetectionItem item;

  static Future<void> show(BuildContext context, DetectionItem item) {
    return showDialog(
      context: context,
      builder: (context) => DetectionDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = item.statistics;
    final hasStats = stats != null;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: screenSize.height * 0.9,
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Detection Details'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Result card
                _buildResultCard(context),
                const SizedBox(height: 16),

                if (hasStats) ...[
                  // Two-column layout for charts on web
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 600) {
                        return _buildTwoColumnLayout(stats);
                      }
                      return _buildSingleColumnLayout(stats);
                    },
                  ),
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
        ),
      ),
    );
  }

  Widget _buildTwoColumnLayout(DetectionStatistics stats) {
    return Column(
      children: [
        // Row 1: Signal Strength + PSNR Chart
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SignalStrengthCard(stats: stats)),
              const SizedBox(width: 16),
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                Expanded(child: PsnrChartCard(stats: stats))
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Row 2: Timing + Technical Details
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stats.timing != null)
                Expanded(child: TimingCard(timing: stats.timing!))
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 16),
              Expanded(child: TechnicalDetailsCard(stats: stats)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Row 3: Peak Positions + PSNR Histogram
        if (stats.sequences != null && stats.sequences!.isNotEmpty) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: PeakPositionsCard(stats: stats)),
                const SizedBox(width: 16),
                Expanded(child: PsnrHistogramCard(stats: stats)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Row 4: Peak vs RMS + Shift Values
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: PeakVsRmsCard(stats: stats)),
                const SizedBox(width: 16),
                Expanded(child: ShiftValuesCard(stats: stats)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Full width: Message Bits + Image Comparison
          MessageBitsCard(stats: stats, message: item.result),
          const SizedBox(height: 16),
          _buildImageComparisonCard(),
        ],
      ],
    );
  }

  Widget _buildSingleColumnLayout(DetectionStatistics stats) {
    return Column(
      children: [
        SignalStrengthCard(stats: stats),
        const SizedBox(height: 16),

        if (stats.sequences != null && stats.sequences!.isNotEmpty)
          PsnrChartCard(stats: stats),
        const SizedBox(height: 16),

        if (stats.timing != null) TimingCard(timing: stats.timing!),
        const SizedBox(height: 16),

        TechnicalDetailsCard(stats: stats),
        const SizedBox(height: 16),

        if (stats.sequences != null && stats.sequences!.isNotEmpty) ...[
          PeakPositionsCard(stats: stats),
          const SizedBox(height: 16),
          PsnrHistogramCard(stats: stats),
          const SizedBox(height: 16),
          PeakVsRmsCard(stats: stats),
          const SizedBox(height: 16),
          ShiftValuesCard(stats: stats),
          const SizedBox(height: 16),
          MessageBitsCard(stats: stats, message: item.result),
          const SizedBox(height: 16),
          _buildImageComparisonCard(),
        ],
      ],
    );
  }

  Widget _buildResultCard(BuildContext context) {
    final servingUrl = item.extractedRef?.servingUrl;
    final remotePath = item.extractedRef?.remotePath;

    Widget imageWidget;
    if (servingUrl != null && servingUrl.isNotEmpty) {
      imageWidget = Image.network(
        servingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No image'),
      );
    } else if (remotePath != null && remotePath.startsWith('http')) {
      imageWidget = Image.network(
        remotePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No image'),
      );
    } else if (remotePath != null) {
      // Storage path - need to resolve
      imageWidget = FutureBuilder<String>(
        future: StorageService().getDownloadUrl(remotePath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No image'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
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
    final servingUrl = item.extractedRef?.servingUrl;
    final remotePath = item.extractedRef?.remotePath;
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
    if (servingUrl != null && servingUrl.isNotEmpty) {
      capturedWidget = Image.network(
        servingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ImagePlaceholder(text: 'No capture'),
      );
    } else if (remotePath != null && remotePath.startsWith('http')) {
      capturedWidget = Image.network(
        remotePath,
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
