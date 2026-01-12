import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../models/token.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  ApiException(this.message, {this.code, this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );

  final String? authToken;

  ApiService({this.authToken});

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw ApiException(
      body['error'] as String? ?? 'Unknown error',
      code: body['code'] as String?,
      statusCode: response.statusCode,
    );
  }

  // ============ Minting ============

  /// Get minting prices
  Future<Map<String, dynamic>> getMintPrices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mint/price'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  /// Get license text for signing
  Future<String> getLicenseText(LicenseType licenseType) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mint/license/${licenseType.name}'),
      headers: _headers,
    );
    final data = await _handleResponse(response);
    return data['text'] as String;
  }

  /// Mint a new NFT
  Future<MintResult> mint({
    required Uint8List imageBytes,
    required String fileName,
    required String name,
    required String description,
    required LicenseType licenseType,
    required String licenseSignature,
  }) async {
    final uri = Uri.parse('$baseUrl/api/mint');
    final request = http.MultipartRequest('POST', uri);

    // Add auth header
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    // Add file
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: fileName,
    ));

    // Add fields
    request.fields['name'] = name;
    request.fields['description'] = description;
    request.fields['licenseType'] = licenseType.name;
    request.fields['licenseSignature'] = licenseSignature;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    try {
      final data = await _handleResponse(response);
      return MintResult.fromJson(data);
    } catch (e) {
      return MintResult.error(e.toString());
    }
  }

  // ============ Verification ============

  /// Get token verification info (public)
  Future<Token> getTokenInfo(int tokenId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/verify/$tokenId'),
    );
    final data = await _handleResponse(response);
    return Token.fromJson(data);
  }

  /// Check if image hash is registered (public)
  Future<bool> isImageRegistered(String imageHash) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/verify/check/$imageHash'),
    );
    final data = await _handleResponse(response);
    return data['registered'] as bool;
  }

  /// Get platform stats (public)
  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/verify/stats'),
    );
    return _handleResponse(response);
  }

  // ============ Detection ============

  /// Run watermark detection
  Future<Map<String, dynamic>> detect({
    required int tokenId,
    required Uint8List capturedImageBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/detect');
    final request = http.MultipartRequest('POST', uri);

    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'capturedImage',
      capturedImageBytes,
      filename: fileName,
    ));

    request.fields['tokenId'] = tokenId.toString();

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // ============ Public Verification ============

  /// Verify an image against a token's watermark (public)
  Future<Map<String, dynamic>> verifyImage(int tokenId, Uint8List imageBytes) async {
    final uri = Uri.parse('$baseUrl/api/verify/$tokenId/check');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'verify.png',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }
}
