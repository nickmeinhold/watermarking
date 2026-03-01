import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Platform-agnostic REST API client for the watermarking service.
///
/// Uses `package:http` for SSE streaming (works on both iOS and web).
/// Web apps may use their own browser-specific implementation instead.
class WatermarkingApiService {
  WatermarkingApiService({required this.baseUrl});

  final String baseUrl;

  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Failed to get Firebase ID token');
    }
    return token;
  }

  /// Watermark an image via GCS path (server downloads from GCS).
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
    await _authenticatedDelete('$baseUrl/original/$originalImageId');
  }

  /// Delete a marked image (and related detection items).
  Future<void> deleteMarked(String markedImageId) async {
    await _authenticatedDelete('$baseUrl/marked/$markedImageId');
  }

  /// Delete a detection item.
  Future<void> deleteDetection(String detectionItemId) async {
    await _authenticatedDelete('$baseUrl/detection/$detectionItemId');
  }

  /// POST JSON body and consume the SSE response stream.
  Stream<Map<String, dynamic>> _postJsonSse(
      String url, Map<String, dynamic> body) async* {
    final token = await _getIdToken();

    final request = http.Request('POST', Uri.parse(url))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        try {
          final json = jsonDecode(responseBody) as Map<String, dynamic>;
          throw Exception(json['error'] ?? 'API error: ${response.statusCode}');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('API error ${response.statusCode}: $responseBody');
        }
      }

      // Parse SSE events from the streamed response
      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (buffer.contains('\n\n')) {
          final end = buffer.indexOf('\n\n');
          final eventText = buffer.substring(0, end);
          buffer = buffer.substring(end + 2);

          for (final line in eventText.split('\n')) {
            if (line.startsWith('data: ')) {
              try {
                final event =
                    jsonDecode(line.substring(6)) as Map<String, dynamic>;
                yield event;
              } catch (_) {
                // Skip malformed JSON
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Send an authenticated DELETE request.
  Future<void> _authenticatedDelete(String url) async {
    final token = await _getIdToken();

    final response = await http.delete(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(
            json['error'] ?? 'Delete failed: ${response.statusCode}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Delete failed ${response.statusCode}: ${response.body}');
      }
    }
  }
}
