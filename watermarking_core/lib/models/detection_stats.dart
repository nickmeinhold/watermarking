/// Statistics for a single detection sequence
class SequenceStats {
  const SequenceStats({
    required this.k,
    required this.psnr,
    required this.peakX,
    required this.peakY,
    required this.peakVal,
    required this.rms,
    required this.shift,
  });

  final int k; // Sequence number (family index)
  final double psnr; // Peak-to-RMS ratio
  final int peakX; // X coordinate of peak in correlation matrix
  final int peakY; // Y coordinate of peak in correlation matrix
  final double peakVal; // Raw peak correlation value
  final double rms; // RMS of all correlation values
  final int shift; // Detected shift value

  factory SequenceStats.fromJson(Map<String, dynamic> json) {
    return SequenceStats(
      k: (json['k'] as num?)?.toInt() ?? 0,
      psnr: (json['psnr'] as num?)?.toDouble() ?? 0.0,
      peakX: (json['peakX'] as num?)?.toInt() ?? 0,
      peakY: (json['peakY'] as num?)?.toInt() ?? 0,
      peakVal: (json['peakVal'] as num?)?.toDouble() ?? 0.0,
      rms: (json['rms'] as num?)?.toDouble() ?? 0.0,
      shift: (json['shift'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'k': k,
        'psnr': psnr,
        'peakX': peakX,
        'peakY': peakY,
        'peakVal': peakVal,
        'rms': rms,
        'shift': shift,
      };
}

/// Timing breakdown for detection phases
class TimingStats {
  const TimingStats({
    required this.imageLoad,
    required this.extraction,
    required this.correlation,
    required this.total,
  });

  final double imageLoad; // Time to load images (ms)
  final double extraction; // Time to extract watermark (ms)
  final double correlation; // Time for correlation analysis (ms)
  final double total; // Total processing time (ms)

  factory TimingStats.fromJson(Map<String, dynamic> json) {
    return TimingStats(
      imageLoad: (json['imageLoad'] as num?)?.toDouble() ?? 0.0,
      extraction: (json['extraction'] as num?)?.toDouble() ?? 0.0,
      correlation: (json['correlation'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'imageLoad': imageLoad,
        'extraction': extraction,
        'correlation': correlation,
        'total': total,
      };
}

/// PSNR summary statistics
class PsnrStats {
  const PsnrStats({
    required this.min,
    required this.max,
    required this.avg,
  });

  final double min; // Minimum PSNR (confidence)
  final double max; // Maximum PSNR
  final double avg; // Average PSNR

  factory PsnrStats.fromJson(Map<String, dynamic> json) {
    return PsnrStats(
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 0.0,
      avg: (json['avg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'min': min,
        'max': max,
        'avg': avg,
      };
}

/// Correlation matrix statistics
class CorrelationStats {
  const CorrelationStats({
    required this.min,
    required this.max,
    required this.mean,
    required this.stdDev,
  });

  final double min;
  final double max;
  final double mean;
  final double stdDev;

  factory CorrelationStats.fromJson(Map<String, dynamic> json) {
    return CorrelationStats(
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 0.0,
      mean: (json['mean'] as num?)?.toDouble() ?? 0.0,
      stdDev: (json['stdDev'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'min': min,
        'max': max,
        'mean': mean,
        'stdDev': stdDev,
      };
}

/// Complete detection statistics
class DetectionStatistics {
  const DetectionStatistics({
    this.imageWidth,
    this.imageHeight,
    this.primeSize,
    this.threshold,
    this.timing,
    this.totalSequencesTested,
    this.sequencesAboveThreshold,
    this.psnrStats,
    this.sequences,
    this.correlationStats,
  });

  final int? imageWidth;
  final int? imageHeight;
  final int? primeSize;
  final double? threshold;
  final TimingStats? timing;
  final int? totalSequencesTested;
  final int? sequencesAboveThreshold;
  final PsnrStats? psnrStats;
  final List<SequenceStats>? sequences;
  final CorrelationStats? correlationStats;

  factory DetectionStatistics.fromJson(Map<String, dynamic> json) {
    List<SequenceStats>? sequences;
    if (json['sequences'] != null) {
      sequences = (json['sequences'] as List)
          .map((s) => SequenceStats.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return DetectionStatistics(
      imageWidth: (json['imageWidth'] as num?)?.toInt(),
      imageHeight: (json['imageHeight'] as num?)?.toInt(),
      primeSize: (json['primeSize'] as num?)?.toInt(),
      threshold: (json['threshold'] as num?)?.toDouble(),
      timing: json['timing'] != null
          ? TimingStats.fromJson(json['timing'] as Map<String, dynamic>)
          : null,
      totalSequencesTested: (json['totalSequencesTested'] as num?)?.toInt(),
      sequencesAboveThreshold:
          (json['sequencesAboveThreshold'] as num?)?.toInt(),
      psnrStats: json['psnrStats'] != null
          ? PsnrStats.fromJson(json['psnrStats'] as Map<String, dynamic>)
          : null,
      sequences: sequences,
      correlationStats: json['correlationStats'] != null
          ? CorrelationStats.fromJson(
              json['correlationStats'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'primeSize': primeSize,
        'threshold': threshold,
        'timing': timing?.toJson(),
        'totalSequencesTested': totalSequencesTested,
        'sequencesAboveThreshold': sequencesAboveThreshold,
        'psnrStats': psnrStats?.toJson(),
        'sequences': sequences?.map((s) => s.toJson()).toList(),
        'correlationStats': correlationStats?.toJson(),
      };
}
