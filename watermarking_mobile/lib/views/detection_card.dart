import 'dart:io';

import 'package:flutter/material.dart';
import 'package:watermarking_core/watermarking_core.dart';

import 'detection_detail_page.dart';

class DetectionCard extends StatelessWidget {
  const DetectionCard({
    super.key,
    required this.item,
    this.onDismissed,
  });

  final DetectionItem item;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final localPath = item.extractedRef?.localPath;
    final servingUrl = item.extractedRef?.servingUrl;
    final started = item.extractedRef?.upload?.started;
    final isComplete = item.result != null;

    return Dismissible(
      key: Key(item.id ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed?.call(),
      child: Center(
        child: Card(
          color: isComplete ? Colors.white : Colors.blueGrey,
          child: InkWell(
            onTap: isComplete
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DetectionDetailPage(item: item),
                      ),
                    )
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Extracted image thumbnail
                  _ImageThumbnail(
                    localPath: localPath,
                    servingUrl: servingUrl,
                  ),
                  const SizedBox(width: 12),
                  // Detection info
                  Expanded(
                    child: _DetectionInfo(
                      item: item,
                      started: started,
                    ),
                  ),
                  // Chevron indicator
                  if (isComplete)
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    this.localPath,
    this.servingUrl,
  });

  final String? localPath;
  final String? servingUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 80,
        height: 80,
        child: localPath != null
            ? Image.file(
                File(localPath!),
                fit: BoxFit.cover,
              )
            : servingUrl != null
                ? Image.network(
                    servingUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(
        Icons.image,
        size: 40,
        color: Colors.grey,
      ),
    );
  }
}

class _DetectionInfo extends StatelessWidget {
  const _DetectionInfo({
    required this.item,
    this.started,
  });

  final DetectionItem item;
  final DateTime? started;

  @override
  Widget build(BuildContext context) {
    final isComplete = item.result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.result ?? 'Processing...',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isComplete ? Colors.black87 : Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        if (item.confidence != null) _ConfidenceRow(confidence: item.confidence!),
        if (started != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _formatDate(started!),
              style: TextStyle(
                fontSize: 11,
                color: isComplete ? Colors.grey : Colors.white54,
              ),
            ),
          ),
        // Show indicator for tapping
        if (isComplete)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 14,
                  color: item.statistics != null ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.verified,
          size: 16,
          color: _confidenceColor(confidence),
        ),
        const SizedBox(width: 4),
        Text(
          'Confidence: ${confidence.toStringAsFixed(1)}',
          style: TextStyle(
            color: _confidenceColor(confidence),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 10) return Colors.green;
    if (confidence >= 7) return Colors.orange;
    return Colors.red;
  }
}
