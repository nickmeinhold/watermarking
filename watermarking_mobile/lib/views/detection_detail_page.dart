import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
            // Result card
            _ResultCard(item: item),
            const SizedBox(height: 16),

            if (hasStats) ...[
              // Signal strength gauge
              _SignalStrengthCard(stats: stats),
              const SizedBox(height: 16),

              // PSNR bar chart
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                _PsnrChartCard(stats: stats),
              const SizedBox(height: 16),

              // Timing breakdown
              if (stats.timing != null) _TimingCard(timing: stats.timing!),
              const SizedBox(height: 16),

              // Technical details
              _TechnicalDetailsCard(stats: stats),
              const SizedBox(height: 16),

              // Peak positions scatter
              if (stats.sequences != null && stats.sequences!.isNotEmpty)
                _PeakPositionsCard(stats: stats),
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
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item});
  final DetectionItem item;

  @override
  Widget build(BuildContext context) {
    final localPath = item.extractedRef?.localPath;
    final servingUrl = item.extractedRef?.servingUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 100,
                child: localPath != null
                    ? Image.file(File(localPath), fit: BoxFit.cover)
                    : servingUrl != null
                        ? Image.network(servingUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, size: 40),
                          ),
              ),
            ),
            const SizedBox(width: 16),
            // Result info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.result ?? 'Processing...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (item.confidence != null)
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 20,
                          color: _confidenceColor(item.confidence!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Confidence: ${item.confidence!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _confidenceColor(item.confidence!),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (item.detected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(
                          item.detected! ? 'Detected' : 'Not Detected',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            item.detected! ? Colors.green.shade100 : Colors.red.shade100,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 10) return Colors.green;
    if (confidence >= 7) return Colors.orange;
    return Colors.red;
  }
}

class _SignalStrengthCard extends StatelessWidget {
  const _SignalStrengthCard({required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final threshold = stats.threshold ?? 6.0;
    final minPsnr = stats.psnrStats?.min ?? 0;
    final maxPsnr = stats.psnrStats?.max ?? 0;
    final avgPsnr = stats.psnrStats?.avg ?? 0;

    // Calculate signal strength as percentage above threshold
    final signalStrength = minPsnr > 0 ? (minPsnr / threshold) : 0.0;
    final strengthPercent = (signalStrength * 100).clamp(0, 200);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.signal_cellular_alt, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Signal Strength',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Gauge
            SizedBox(
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: (strengthPercent / 200).clamp(0.0, 1.0),
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getGaugeColor(signalStrength),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${strengthPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getGaugeColor(signalStrength),
                            ),
                      ),
                      Text(
                        'of threshold',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // PSNR stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Min', value: minPsnr.toStringAsFixed(2)),
                _StatItem(label: 'Avg', value: avgPsnr.toStringAsFixed(2)),
                _StatItem(label: 'Max', value: maxPsnr.toStringAsFixed(2)),
                _StatItem(label: 'Threshold', value: threshold.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getGaugeColor(double ratio) {
    if (ratio >= 1.5) return Colors.green;
    if (ratio >= 1.0) return Colors.orange;
    return Colors.red;
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PsnrChartCard extends StatelessWidget {
  const _PsnrChartCard({required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final threshold = stats.threshold ?? 6.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PSNR by Sequence',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${stats.sequencesAboveThreshold ?? 0} of ${stats.totalSequencesTested ?? 0} sequences above threshold',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sequences.map((s) => s.psnr).reduce(math.max) * 1.2,
                  barGroups: sequences.asMap().entries.map((entry) {
                    final seq = entry.value;
                    final isAboveThreshold = seq.psnr > threshold;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: seq.psnr,
                          color: isAboveThreshold ? Colors.green : Colors.red,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < sequences.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'k=${sequences[idx].k}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: threshold,
                    getDrawingHorizontalLine: (value) {
                      if (value == threshold) {
                        return FlLine(
                          color: Colors.orange,
                          strokeWidth: 2,
                          dashArray: [5, 5],
                        );
                      }
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 2,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  'Threshold (${threshold.toStringAsFixed(1)})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingCard extends StatelessWidget {
  const _TimingCard({required this.timing});
  final TimingStats timing;

  @override
  Widget build(BuildContext context) {
    final total = timing.total;
    final sections = [
      _TimingSection('Image Load', timing.imageLoad, Colors.blue),
      _TimingSection('Extraction', timing.extraction, Colors.green),
      _TimingSection('Correlation', timing.correlation, Colors.orange),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Processing Time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${total.toStringAsFixed(0)} ms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: sections.map((s) {
                    final percent = total > 0 ? (s.value / total * 100) : 0;
                    return PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      title: '${percent.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      radius: 50,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sections.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.label}: ${s.value.toStringAsFixed(0)} ms',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingSection {
  _TimingSection(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Technical Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow('Image Size', '${stats.imageWidth ?? '?'} x ${stats.imageHeight ?? '?'}'),
            _DetailRow('Prime Size (p)', '${stats.primeSize ?? '?'}'),
            _DetailRow('Detection Threshold', '${stats.threshold ?? 6.0}'),
            _DetailRow('Sequences Tested', '${stats.totalSequencesTested ?? '?'}'),
            _DetailRow('Sequences Passed', '${stats.sequencesAboveThreshold ?? '?'}'),
            if (stats.correlationStats != null) ...[
              const Divider(),
              Text(
                'Correlation Matrix',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _DetailRow('Min', stats.correlationStats!.min.toStringAsExponential(2)),
              _DetailRow('Max', stats.correlationStats!.max.toStringAsExponential(2)),
              _DetailRow('Mean', stats.correlationStats!.mean.toStringAsExponential(2)),
              _DetailRow('Std Dev', stats.correlationStats!.stdDev.toStringAsExponential(2)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeakPositionsCard extends StatelessWidget {
  const _PeakPositionsCard({required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final primeSize = stats.primeSize ?? 509;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.scatter_plot, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Peak Positions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Location of correlation peaks in frequency domain',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ScatterChart(
                ScatterChartData(
                  minX: 0,
                  maxX: primeSize.toDouble(),
                  minY: 0,
                  maxY: primeSize.toDouble(),
                  scatterSpots: sequences.asMap().entries.map((entry) {
                    final seq = entry.value;
                    final isAboveThreshold = seq.psnr > (stats.threshold ?? 6.0);
                    return ScatterSpot(
                      seq.peakX.toDouble(),
                      seq.peakY.toDouble(),
                      dotPainter: FlDotCirclePainter(
                        radius: 8,
                        color: isAboveThreshold
                            ? Colors.green.withValues(alpha: 0.7)
                            : Colors.red.withValues(alpha: 0.7),
                        strokeWidth: 2,
                        strokeColor: isAboveThreshold ? Colors.green : Colors.red,
                      ),
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Y', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == primeSize) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('X', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value == primeSize) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    horizontalInterval: primeSize / 4,
                    verticalInterval: primeSize / 4,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Above threshold', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Below threshold', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
