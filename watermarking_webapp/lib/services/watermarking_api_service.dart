import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// REST API client for the watermarking service with SSE-over-POST streaming.
///
/// Uses the browser Fetch API via `package:web` to consume SSE chunks from
/// POST responses (browser EventSource only supports GET).
class WebWatermarkingApiService {
  WebWatermarkingApiService({required this.baseUrl});

  final String baseUrl;

  /// Firebase Auth ID token, set before making GCS requests.
  String? idToken;

  /// Watermark an image via GCS path (server downloads from GCS).
  ///
  /// Returns a stream of SSE events. Final event includes:
  /// - `complete` (bool) + `markedImageId` (String): success
  /// - `error` (String): failure
  Stream<Map<String, dynamic>> watermarkImageGcs({
    required String originalImageId,
    required String imagePath,
    required String imageName,
    required String message,
    required int strength,
  }) async* {
    yield* _postJsonSse('$baseUrl/watermark/gcs', {
      'originalImageId': originalImageId,
      'imagePath': imagePath,
      'imageName': imageName,
      'message': message,
      'strength': strength,
    });
  }

  /// Detect watermark via GCS paths (server downloads both images).
  ///
  /// Returns a stream of SSE events. Final event includes:
  /// - `complete`, `detected`, `message`, `confidence`, `detectionItemId`
  Stream<Map<String, dynamic>> detectWatermarkGcs({
    required String originalPath,
    required String markedPath,
    String? originalImageId,
    String? markedImageId,
  }) async* {
    yield* _postJsonSse('$baseUrl/detect/gcs', {
      'originalPath': originalPath,
      'markedPath': markedPath,
      if (originalImageId != null) 'originalImageId': originalImageId,
      if (markedImageId != null) 'markedImageId': markedImageId,
    });
  }

  /// Delete an original image (and all marked versions + detection items).
  Future<void> deleteOriginal(String originalImageId) async {
    await _delete('$baseUrl/original/$originalImageId');
  }

  /// Delete a marked image (and related detection items).
  Future<void> deleteMarked(String markedImageId) async {
    await _delete('$baseUrl/marked/$markedImageId');
  }

  /// Delete a detection item.
  Future<void> deleteDetection(String detectionItemId) async {
    await _delete('$baseUrl/detection/$detectionItemId');
  }

  /// POST JSON body and consume the SSE response stream.
  Stream<Map<String, dynamic>> _postJsonSse(
      String url, Map<String, dynamic> body) async* {
    final token = idToken;
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated — no Firebase ID token');
    }

    final headers = web.Headers();
    headers.append('Authorization', 'Bearer $token');
    headers.append('Content-Type', 'application/json');

    final init = web.RequestInit(
      method: 'POST',
      headers: headers,
      body: jsonEncode(body).toJS,
    );

    final response = await web.window.fetch(url.toJS, init).toDart;

    if (!response.ok) {
      final text = (await response.text().toDart).toDart;
      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'API error: ${response.status}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('API error ${response.status}: $text');
      }
    }

    final body2 = response.body;
    if (body2 == null) {
      throw Exception('Response body is null');
    }

    final reader =
        body2.getReader() as web.ReadableStreamDefaultReader;
    final decoder = web.TextDecoder();
    var buffer = '';

    try {
      while (true) {
        final result = await reader.read().toDart;
        if (result.done) break;

        final chunk = result.value;
        if (chunk == null) continue;

        buffer += decoder.decode(
          chunk as JSObject,
          web.TextDecodeOptions(stream: true),
        );

        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventText = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          for (final line in eventText.split('\n')) {
            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6);
              try {
                final event = jsonDecode(jsonStr) as Map<String, dynamic>;
                yield event;
              } catch (_) {
                // Skip malformed JSON
              }
            }
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }

  /// Send an authenticated DELETE request.
  Future<void> _delete(String url) async {
    final token = idToken;
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated — no Firebase ID token');
    }

    final headers = web.Headers();
    headers.append('Authorization', 'Bearer $token');

    final init = web.RequestInit(
      method: 'DELETE',
      headers: headers,
    );

    final response = await web.window.fetch(url.toJS, init).toDart;

    if (!response.ok) {
      final text = (await response.text().toDart).toDart;
      try {
        final json = jsonDecode(text) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Delete failed: ${response.status}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Delete failed ${response.status}: $text');
      }
    }
  }
}
