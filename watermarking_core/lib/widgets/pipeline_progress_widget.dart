import 'dart:async';

import 'package:flutter/material.dart';

/// The type of pipeline operation
enum PipelineType { marking, detection }

/// Stages in the pipeline
enum PipelineStage {
  queued,
  downloading,
  processing,
  embedding, // marking only
  analyzing, // detection only
  uploading,
  complete,
  error,
}

/// A compact horizontal widget showing data flow through the processing pipeline.
///
/// Displays stages as icons connected by lines, with the current stage highlighted
/// and a circular progress indicator showing progress within each stage.
class PipelineProgressWidget extends StatefulWidget {
  final PipelineType type;
  final String? progress;
  final bool isComplete;
  final bool hasError;
  final DateTime? startedAt;

  const PipelineProgressWidget({
    super.key,
    required this.type,
    this.progress,
    this.isComplete = false,
    this.hasError = false,
    this.startedAt,
  });

  @override
  State<PipelineProgressWidget> createState() => _PipelineProgressWidgetState();
}

class _PipelineProgressWidgetState extends State<PipelineProgressWidget> {
  late DateTime _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = widget.startedAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(_startTime);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !widget.isComplete) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Parse progress string to determine current stage
  PipelineStage get currentStage {
    if (widget.hasError) return PipelineStage.error;
    if (widget.isComplete) return PipelineStage.complete;
    if (widget.progress == null) return PipelineStage.queued;

    final p = widget.progress!.toLowerCase();

    // Detection-specific
    if (widget.type == PipelineType.detection) {
      if (p.contains('uploading')) return PipelineStage.uploading;
      if (p.contains('downloading')) return PipelineStage.downloading;
      if (p.contains('detecting') || p.contains('analyzing') || p.contains('sequence')) {
        return PipelineStage.analyzing;
      }
      if (p.contains('complete')) return PipelineStage.complete;
      if (p.contains('failed') || p.contains('unsuccessful')) return PipelineStage.error;
      if (p.contains('received') || p.contains('server')) return PipelineStage.processing;
    }

    // Marking-specific
    if (widget.type == PipelineType.marking) {
      if (p.contains('queued')) return PipelineStage.queued;
      if (p.contains('downloading')) return PipelineStage.downloading;
      if (p.contains('loading')) return PipelineStage.processing;
      if (p.contains('embedding') || p.contains('dft') || p.contains('idft')) {
        return PipelineStage.embedding;
      }
      if (p.contains('compressing') || p.contains('saving')) return PipelineStage.embedding;
      if (p.contains('uploading')) return PipelineStage.uploading;
      if (p.contains('generating') || p.contains('url')) return PipelineStage.uploading;
    }

    return PipelineStage.processing;
  }

  /// Parse progress string to extract a percentage (0.0 to 1.0)
  double get stageProgress {
    if (widget.progress == null) return 0.0;

    final p = widget.progress!;

    // Try to parse percentage like "50%" or ": 50%"
    final percentMatch = RegExp(r'(\d+)%').firstMatch(p);
    if (percentMatch != null) {
      final percent = int.tryParse(percentMatch.group(1)!) ?? 0;
      return percent / 100.0;
    }

    // Try to parse fraction like "(3/8)" or "3/8"
    final fractionMatch = RegExp(r'(\d+)/(\d+)').firstMatch(p);
    if (fractionMatch != null) {
      final current = int.tryParse(fractionMatch.group(1)!) ?? 0;
      final total = int.tryParse(fractionMatch.group(2)!) ?? 1;
      if (total > 0) {
        return current / total;
      }
    }

    // For stages without explicit progress, show indeterminate (return -1)
    return -1.0;
  }

  /// Get the stage index for progress calculation
  int _stageIndex(PipelineStage stage) {
    if (widget.type == PipelineType.marking) {
      return switch (stage) {
        PipelineStage.queued => 0,
        PipelineStage.downloading => 1,
        PipelineStage.processing => 2,
        PipelineStage.embedding => 3,
        PipelineStage.uploading => 4,
        PipelineStage.complete => 5,
        PipelineStage.error => -1,
        _ => 2,
      };
    } else {
      // Detection: Upload -> Download -> Process -> Analyze -> Complete
      return switch (stage) {
        PipelineStage.uploading => 0,
        PipelineStage.queued => 0,
        PipelineStage.downloading => 1,
        PipelineStage.processing => 2,
        PipelineStage.analyzing => 3,
        PipelineStage.complete => 4,
        PipelineStage.error => -1,
        _ => 2,
      };
    }
  }

  int get _totalStages => widget.type == PipelineType.marking ? 5 : 4;

  @override
  Widget build(BuildContext context) {
    final stage = currentStage;
    final stageIdx = _stageIndex(stage);
    final progressValue = stageProgress;

    final stages = widget.type == PipelineType.marking
        ? [
            _StageInfo('phone_iphone', 'Queued'),
            _StageInfo('cloud_download', 'Download'),
            _StageInfo('dns', 'Process'),
            _StageInfo('auto_fix_high', 'Embed'),
            _StageInfo('cloud_upload', 'Upload'),
            _StageInfo('check_circle', 'Done'),
          ]
        : [
            _StageInfo('cloud_upload', 'Upload'),
            _StageInfo('cloud_download', 'Download'),
            _StageInfo('dns', 'Process'),
            _StageInfo('analytics', 'Analyze'),
            _StageInfo('check_circle', 'Done'),
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < stages.length; i++) ...[
                  _StageIconWidget(
                    info: stages[i],
                    index: i,
                    currentIndex: stageIdx,
                    hasError: widget.hasError,
                    totalStages: _totalStages,
                    progressValue: progressValue,
                  ),
                  if (i < stages.length - 1)
                    SizedBox(
                      width: 24,
                      child: _buildConnector(context, i, stageIdx, widget.hasError, progressValue),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (widget.progress != null && !widget.isComplete) ...[
          const SizedBox(height: 4),
          Text(
            '${_formatProgress(widget.progress!)} · ${_formatDuration(_elapsed)}',
            style: TextStyle(
              fontSize: 11,
              color: widget.hasError
                  ? Colors.red.shade300
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildConnector(BuildContext context, int index, int currentIndex, bool hasError, double progressValue) {
    final isCompleted = index < currentIndex;
    final isActive = index == currentIndex;

    // Calculate connector fill based on stage progress
    double connectorProgress = 0.0;
    if (isCompleted) {
      connectorProgress = 1.0;
    } else if (isActive && progressValue >= 0) {
      // Fill connector proportionally as stage progresses
      connectorProgress = progressValue * 0.5; // Max 50% fill during active stage
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * connectorProgress;
          return Stack(
            children: [
              // Background track
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                width: fillWidth,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              // Animated shimmer for active connector with indeterminate progress
              if (isActive && progressValue < 0)
                _ShimmerConnector(color: Theme.of(context).colorScheme.primary),
            ],
          );
        },
      ),
    );
  }

  String _formatProgress(String progress) {
    // Shorten long progress messages
    if (progress.length > 45) {
      // Extract key info like "Embedding watermark (3/8)"
      final match = RegExp(r'\((\d+/\d+)\)').firstMatch(progress);
      if (match != null) {
        if (progress.toLowerCase().contains('embedding')) {
          return 'Embedding ${match.group(1)}';
        }
        if (progress.toLowerCase().contains('downloading')) {
          return 'Downloading ${match.group(1)}';
        }
        return '${progress.substring(0, 40)}...';
      }
      return '${progress.substring(0, 42)}...';
    }
    return progress;
  }
}

/// Animated shimmer effect for connectors with indeterminate progress
class _ShimmerConnector extends StatefulWidget {
  final Color color;

  const _ShimmerConnector({required this.color});

  @override
  State<_ShimmerConnector> createState() => _ShimmerConnectorState();
}

class _ShimmerConnectorState extends State<_ShimmerConnector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                widget.color.withValues(alpha: 0.6),
                Colors.transparent,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      },
    );
  }
}

/// Stage icon widget with circular progress indicator
class _StageIconWidget extends StatefulWidget {
  final _StageInfo info;
  final int index;
  final int currentIndex;
  final bool hasError;
  final int totalStages;
  final double progressValue;

  const _StageIconWidget({
    required this.info,
    required this.index,
    required this.currentIndex,
    required this.hasError,
    required this.totalStages,
    required this.progressValue,
  });

  @override
  State<_StageIconWidget> createState() => _StageIconWidgetState();
}

class _StageIconWidgetState extends State<_StageIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _indeterminateController;

  @override
  void initState() {
    super.initState();
    _indeterminateController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_StageIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    final isActive = widget.index == widget.currentIndex;
    final isIndeterminate = widget.progressValue < 0;

    if (isActive && isIndeterminate && !widget.hasError) {
      _indeterminateController.repeat();
    } else {
      _indeterminateController.stop();
    }
  }

  @override
  void dispose() {
    _indeterminateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.index == widget.currentIndex;
    final isCompleted = widget.index < widget.currentIndex;
    final isPending = widget.index > widget.currentIndex;

    Color color;
    if (widget.hasError && isActive) {
      color = Colors.red;
    } else if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = Theme.of(context).colorScheme.primary;
    } else {
      color = Colors.grey.shade600;
    }

    final icon = _getIcon(widget.info.iconName, widget.hasError && isActive);
    final size = isActive ? 36.0 : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: isPending ? Colors.grey.shade700 : color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              // Progress ring
              if (isActive && !widget.hasError && widget.index < widget.totalStages)
                SizedBox(
                  width: size,
                  height: size,
                  child: widget.progressValue >= 0
                      ? CircularProgressIndicator(
                          value: widget.progressValue,
                          strokeWidth: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(color),
                        )
                      : AnimatedBuilder(
                          animation: _indeterminateController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _IndeterminateProgressPainter(
                                progress: _indeterminateController.value,
                                color: color,
                                strokeWidth: 3,
                              ),
                            );
                          },
                        ),
                ),
              // Completed checkmark ring
              if (isCompleted)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              // Icon
              Icon(
                isCompleted ? Icons.check : icon,
                size: isActive ? 18 : 14,
                color: color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.info.label,
          style: TextStyle(
            fontSize: 9,
            color: isPending ? Colors.grey.shade600 : color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  IconData _getIcon(String name, bool isError) {
    if (isError) return Icons.error;

    return switch (name) {
      'phone_iphone' => Icons.phone_iphone,
      'cloud_download' => Icons.cloud_download,
      'cloud_upload' => Icons.cloud_upload,
      'dns' => Icons.dns,
      'auto_fix_high' => Icons.auto_fix_high,
      'analytics' => Icons.analytics,
      'check_circle' => Icons.check_circle,
      _ => Icons.circle,
    };
  }
}

/// Custom painter for indeterminate circular progress
class _IndeterminateProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _IndeterminateProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc that rotates and varies in length
    final startAngle = progress * 2 * 3.14159 * 2 - 3.14159 / 2;
    final sweepAngle = 3.14159 * 0.8 + (0.5 - (progress - 0.5).abs()) * 3.14159 * 0.4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_IndeterminateProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StageInfo {
  final String iconName;
  final String label;

  _StageInfo(this.iconName, this.label);
}
