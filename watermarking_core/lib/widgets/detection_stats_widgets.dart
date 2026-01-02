import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:watermarking_core/models/detection_stats.dart';

/// Signal strength gauge showing PSNR relative to threshold.
class SignalStrengthCard extends StatelessWidget {
  const SignalStrengthCard({super.key, required this.stats});
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

/// Bar chart showing PSNR values per sequence with threshold line.
class PsnrChartCard extends StatelessWidget {
  const PsnrChartCard({super.key, required this.stats});
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

/// Pie chart showing timing breakdown of detection phases.
class TimingCard extends StatelessWidget {
  const TimingCard({super.key, required this.timing});
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

/// Card showing technical details like image size, prime size, correlation stats.
class TechnicalDetailsCard extends StatelessWidget {
  const TechnicalDetailsCard({super.key, required this.stats});
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

/// Scatter chart showing peak positions in frequency domain.
class PeakPositionsCard extends StatelessWidget {
  const PeakPositionsCard({super.key, required this.stats});
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
                  decoration: const BoxDecoration(
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
                  decoration: const BoxDecoration(
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

/// Histogram showing PSNR value distribution.
class PsnrHistogramCard extends StatelessWidget {
  const PsnrHistogramCard({super.key, required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final threshold = stats.threshold ?? 6.0;

    // Create histogram bins
    final psnrValues = sequences.map((s) => s.psnr).toList();
    final minPsnr = psnrValues.reduce(math.min);
    final maxPsnr = psnrValues.reduce(math.max);
    final range = maxPsnr - minPsnr;
    const numBins = 10;
    final binWidth = range > 0 ? range / numBins : 1.0;

    // Count values in each bin
    final bins = List<int>.filled(numBins, 0);
    for (final psnr in psnrValues) {
      int binIndex = range > 0 ? ((psnr - minPsnr) / binWidth).floor() : 0;
      binIndex = binIndex.clamp(0, numBins - 1);
      bins[binIndex]++;
    }

    final maxCount = bins.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.equalizer, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PSNR Distribution',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Frequency distribution of PSNR values across sequences',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount.toDouble() * 1.2,
                  barGroups: bins.asMap().entries.map((entry) {
                    final binStart = minPsnr + entry.key * binWidth;
                    final binEnd = binStart + binWidth;
                    final isThresholdBin =
                        threshold >= binStart && threshold < binEnd;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: isThresholdBin
                              ? Colors.orange
                              : Colors.blue.shade400,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget:
                          const Text('Count', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget:
                          const Text('PSNR', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx == 0 || idx == numBins - 1) {
                            final binValue = minPsnr + idx * binWidth;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                binValue.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 9),
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
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 12, height: 12, color: Colors.orange),
                const SizedBox(width: 4),
                const Text('Contains threshold', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Scatter chart showing peak value vs RMS for signal quality.
class PeakVsRmsCard extends StatelessWidget {
  const PeakVsRmsCard({super.key, required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final threshold = stats.threshold ?? 6.0;

    final rmsValues = sequences.map((s) => s.rms).toList();
    final peakValues = sequences.map((s) => s.peakVal).toList();

    final minRms = rmsValues.reduce(math.min);
    final maxRms = rmsValues.reduce(math.max);
    final minPeak = peakValues.reduce(math.min);
    final maxPeak = peakValues.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bubble_chart, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Peak Value vs RMS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Signal quality: higher peak with lower RMS = stronger detection',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ScatterChart(
                ScatterChartData(
                  minX: minRms * 0.9,
                  maxX: maxRms * 1.1,
                  minY: minPeak * 0.9,
                  maxY: maxPeak * 1.1,
                  scatterSpots: sequences.map((seq) {
                    final isAboveThreshold = seq.psnr > threshold;
                    return ScatterSpot(
                      seq.rms,
                      seq.peakVal,
                      dotPainter: FlDotCirclePainter(
                        radius: 6,
                        color: isAboveThreshold
                            ? Colors.green.withValues(alpha: 0.7)
                            : Colors.red.withValues(alpha: 0.7),
                        strokeWidth: 1,
                        strokeColor: isAboveThreshold ? Colors.green : Colors.red,
                      ),
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: const Text('Peak Value',
                          style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsExponential(1),
                            style: const TextStyle(fontSize: 8),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget:
                          const Text('RMS', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              value.toStringAsExponential(1),
                              style: const TextStyle(fontSize: 8),
                            ),
                          );
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
                  gridData: const FlGridData(show: true),
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
                  decoration: const BoxDecoration(
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
                  decoration: const BoxDecoration(
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

/// Line chart showing shift values across sequences.
class ShiftValuesCard extends StatelessWidget {
  const ShiftValuesCard({super.key, required this.stats});
  final DetectionStatistics stats;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final threshold = stats.threshold ?? 6.0;
    final primeSize = stats.primeSize ?? 509;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.linear_scale, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Shift Values',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Detected shifts encode the hidden message (shift = y × p + x)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (primeSize * primeSize).toDouble(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sequences.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.shift.toDouble(),
                        );
                      }).toList(),
                      isCurved: false,
                      color: Colors.purple,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isAbove = sequences[index].psnr > threshold;
                          return FlDotCirclePainter(
                            radius: 4,
                            color: isAbove ? Colors.green : Colors.red,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget:
                          const Text('Shift', style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('Sequence',
                          style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < sequences.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'k${sequences[idx].k}',
                                style: const TextStyle(fontSize: 9),
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
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card showing message decoding with confidence grid.
class MessageBitsCard extends StatelessWidget {
  const MessageBitsCard({super.key, required this.stats, this.message});
  final DetectionStatistics stats;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final sequences = stats.sequences!;
    final threshold = stats.threshold ?? 6.0;

    // Extract the actual message from result (remove "Watermark Detected: " prefix)
    String? decodedMessage;
    if (message != null && message!.contains(':')) {
      decodedMessage = message!.split(':').last.trim();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Message Decoding',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'How shift values map to the decoded message',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (decodedMessage != null && decodedMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Decoded Message',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            decodedMessage,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Bit visualization grid
            Text(
              'Sequence Confidence Grid',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: sequences.asMap().entries.map((entry) {
                final seq = entry.value;
                final isAbove = seq.psnr > threshold;
                final intensity = (seq.psnr / 20).clamp(0.0, 1.0);
                return Tooltip(
                  message: 'k=${seq.k}\nPSNR: ${seq.psnr.toStringAsFixed(2)}\n'
                      'Shift: ${seq.shift}',
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isAbove
                          ? Colors.green.withValues(alpha: 0.3 + intensity * 0.7)
                          : Colors.red.withValues(alpha: 0.3 + intensity * 0.7),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isAbove ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${seq.k}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isAbove
                              ? Colors.green.shade900
                              : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendItem(
                  color: Colors.green,
                  label: 'Strong signal',
                ),
                const SizedBox(width: 16),
                _LegendItem(
                  color: Colors.red,
                  label: 'Weak signal',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Shift value table for first few sequences
            Text(
              'Shift Details (first ${math.min(8, sequences.length)} sequences)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1.5),
              },
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('k', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('PSNR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Valid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                ...sequences.take(8).map((seq) {
                  final isAbove = seq.psnr > threshold;
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${seq.k}', style: const TextStyle(fontSize: 11)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${seq.shift}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(seq.psnr.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          isAbove ? Icons.check : Icons.close,
                          size: 16,
                          color: isAbove ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Result card with customizable image widget (platform-agnostic).
class DetectionResultCard extends StatelessWidget {
  const DetectionResultCard({
    super.key,
    required this.result,
    required this.confidence,
    required this.detected,
    required this.imageWidget,
  });

  final String? result;
  final double? confidence;
  final bool? detected;
  final Widget imageWidget;

  @override
  Widget build(BuildContext context) {
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
                child: imageWidget,
              ),
            ),
            const SizedBox(width: 16),
            // Result info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result ?? 'Processing...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (confidence != null)
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 20,
                          color: _confidenceColor(confidence!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Confidence: ${confidence!.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _confidenceColor(confidence!),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  if (detected != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Chip(
                        label: Text(
                          detected! ? 'Detected' : 'Not Detected',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            detected! ? Colors.green.shade100 : Colors.red.shade100,
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

/// Image comparison card with customizable image widgets (platform-agnostic).
class ImageComparisonCard extends StatelessWidget {
  const ImageComparisonCard({
    super.key,
    required this.originalImageWidget,
    required this.capturedImageWidget,
  });

  final Widget originalImageWidget;
  final Widget capturedImageWidget;

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
                const Icon(Icons.compare, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Image Comparison',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Original watermarked image vs captured/extracted image',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Original image
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Original',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: originalImageWidget,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 16),
                // Extracted image
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Captured',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: capturedImageWidget,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for placeholder images.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
