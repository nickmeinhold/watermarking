import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

class ConsoleDialog extends StatelessWidget {
  const ConsoleDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ConsoleDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ({String? userId, List<Problem> problems})>(
      converter: (store) =>
          (userId: store.state.user.id, problems: store.state.problems),
      builder: (context, vm) {
        final userId = vm.userId;
        if (userId == null) {
          return const Dialog.fullscreen(
            child: Center(child: Text('Not signed in')),
          );
        }
        return _ConsoleContent(userId: userId, problems: vm.problems);
      },
    );
  }
}

class _ConsoleContent extends StatelessWidget {
  const _ConsoleContent({required this.userId, required this.problems});

  final String userId;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Console'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                _collectionTab(db, 'originalImages', 'Originals'),
                _collectionTab(db, 'markedImages', 'Marked'),
                _collectionTab(db, 'detectionItems', 'Detections'),
                _taskTab(db),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Problems'),
                      if (problems.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _badge(problems.length, Colors.red),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _CollectionTab(
                stream: db
                    .collection('originalImages')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                imageUrlKeys: const ['servingUrl', 'url'],
                summaryBuilder: (data) => data['name'] ?? data['path'] ?? '—',
              ),
              _CollectionTab(
                stream: db
                    .collection('markedImages')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                imageUrlKeys: const ['servingUrl'],
                summaryBuilder: (data) {
                  final msg = data['message'] ?? '';
                  final progress = data['progress'];
                  return progress != null ? '$msg  [$progress]' : msg;
                },
              ),
              _CollectionTab(
                stream: db
                    .collection('detectionItems')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                imageUrlKeys: const [],
                summaryBuilder: (data) {
                  final result = data['result'] ?? '—';
                  final conf = data['confidence'];
                  return conf != null ? '$result (${conf.toStringAsFixed(1)})' : result;
                },
              ),
              _CollectionTab(
                stream: db
                    .collection('tasks')
                    .where('userId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                imageUrlKeys: const [],
                summaryBuilder: (data) {
                  final type = data['type'] ?? '?';
                  final status = data['status'] ?? '?';
                  return '$type — $status';
                },
                statusColorBuilder: (data) {
                  switch (data['status']) {
                    case 'pending':
                      return Colors.amber;
                    case 'processing':
                      return Colors.blue;
                    case 'error':
                      return Colors.red;
                    default:
                      return null;
                  }
                },
              ),
              _ProblemsTab(problems: problems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionTab(FirebaseFirestore db, String collection, String label) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                _badge(count, Colors.grey),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _taskTab(FirebaseFirestore db) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tasks'),
              if (count > 0) ...[
                const SizedBox(width: 6),
                _badge(count, Colors.grey),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _badge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _CollectionTab extends StatelessWidget {
  const _CollectionTab({
    required this.stream,
    required this.imageUrlKeys,
    required this.summaryBuilder,
    this.statusColorBuilder,
  });

  final Stream<QuerySnapshot> stream;
  final List<String> imageUrlKeys;
  final String Function(Map<String, dynamic> data) summaryBuilder;
  final Color? Function(Map<String, dynamic> data)? statusColorBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No documents'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final statusColor = statusColorBuilder?.call(data);
            return ExpansionTile(
              leading: _buildLeading(data, statusColor),
              title: Text(
                doc.id,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              subtitle: Text(summaryBuilder(data)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(_sanitize(data)),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLeading(Map<String, dynamic> data, Color? statusColor) {
    // Try to show a thumbnail from image URL fields
    for (final key in imageUrlKeys) {
      final url = data[key];
      if (url is String && url.isNotEmpty) {
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.network(
            url,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.red,
              size: 24,
            ),
          ),
        );
      }
    }
    if (statusColor != null) {
      return Icon(Icons.circle, color: statusColor, size: 16);
    }
    return const SizedBox(width: 40);
  }

  /// Convert Timestamps to strings so JsonEncoder doesn't choke.
  static Object? _sanitize(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _sanitize(v)));
    }
    if (value is List) return value.map(_sanitize).toList();
    return value;
  }
}

class _ProblemsTab extends StatelessWidget {
  const _ProblemsTab({required this.problems});

  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) {
      return const Center(child: Text('No problems'));
    }
    return ListView.builder(
      itemCount: problems.length,
      itemBuilder: (context, index) {
        final p = problems[index];
        return ExpansionTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: Text(p.type.name),
          subtitle: Text(p.message, maxLines: 1, overflow: TextOverflow.ellipsis),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                [
                  'Type: ${p.type.name}',
                  'Message: ${p.message}',
                  if (p.info != null)
                    'Info: ${const JsonEncoder.withIndent('  ').convert(p.info)}',
                  if (p.trace != null) 'Trace:\n${p.trace}',
                ].join('\n\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        );
      },
    );
  }
}
