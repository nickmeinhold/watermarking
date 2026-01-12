import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../models/token.dart';
import '../services/api_service.dart';
import '../widgets/wallet_button.dart';

class VerifyPage extends StatefulWidget {
  final int tokenId;

  const VerifyPage({super.key, required this.tokenId});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  Token? _token;
  bool _loadingToken = true;
  String? _tokenError;

  Uint8List? _imageBytes;
  String? _imageName;

  VerificationResult? _result;
  bool _verifying = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final api = ApiService();
      final token = await api.getTokenInfo(widget.tokenId);
      setState(() {
        _token = token;
        _loadingToken = false;
      });
    } catch (e) {
      setState(() {
        _tokenError = e.toString();
        _loadingToken = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _imageBytes = file.bytes;
          _imageName = file.name;
          _result = null;
          _verifyError = null;
        });
      }
    }
  }

  Future<void> _verify() async {
    if (_imageBytes == null) return;

    setState(() {
      _verifying = true;
      _verifyError = null;
      _result = null;
    });

    try {
      final api = ApiService();
      final data = await api.verifyImage(widget.tokenId, _imageBytes!);
      setState(() {
        _result = VerificationResult.fromJson(data);
        _verifying = false;
      });
    } catch (e) {
      setState(() {
        _verifyError = e.toString();
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Token #${widget.tokenId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/token/${widget.tokenId}'),
        ),
        actions: const [
          WalletButton(),
          SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingToken) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tokenError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Error loading token', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_tokenError!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadToken,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTokenInfo(),
                const SizedBox(height: 24),
                _buildInstructions(),
                const SizedBox(height: 24),
                _buildImageUploader(),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 24),
                  _buildVerifyButton(),
                ],
                if (_verifyError != null) ...[
                  const SizedBox(height: 16),
                  _buildError(),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _buildResult(),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenInfo() {
    final token = _token!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: token.previewUrl != null
                    ? Image.network(token.previewUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image, color: Colors.grey.shade400),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Token #${token.tokenId}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.gavel, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        token.licenseType.displayName,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'How Verification Works',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Upload an image you want to verify. Our system will check if it contains '
              'the watermark associated with this token. This works even if the image '
              'has been printed, scanned, screenshotted, or slightly edited.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return Card(
      child: InkWell(
        onTap: _verifying ? null : _pickImage,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: _imageBytes != null ? 300 : 200,
          padding: const EdgeInsets.all(24),
          child: _imageBytes != null
              ? Stack(
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: _verifying
                            ? null
                            : () {
                                setState(() {
                                  _imageBytes = null;
                                  _imageName = null;
                                  _result = null;
                                });
                              },
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _imageName ?? 'Image',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload image to verify',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports photos, screenshots, and scans',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    if (_verifying) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analyzing watermark...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _verify,
      icon: const Icon(Icons.verified),
      label: const Text('Verify Image'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _verifyError!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    final isMatch = result.isMatch;

    return Card(
      color: isMatch ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isMatch ? Icons.verified : Icons.warning,
              size: 64,
              color: isMatch ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              isMatch ? 'Watermark Verified!' : 'No Match Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isMatch ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isMatch
                  ? 'This image contains the watermark for Token #${widget.tokenId}'
                  : 'This image does not appear to contain the expected watermark',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isMatch ? Colors.green.shade600 : Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildConfidenceBar(result.confidence),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip('Confidence', '${(result.confidence * 100).toStringAsFixed(1)}%'),
                const SizedBox(width: 16),
                _buildStatChip('Watermark ID', result.watermarkId ?? '-'),
              ],
            ),
            if (!isMatch) ...[
              const SizedBox(height: 24),
              Text(
                'Possible reasons:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '- Image may be from a different source\n'
                '- Image may have been heavily edited\n'
                '- Low quality scan or screenshot',
                style: TextStyle(color: Colors.orange.shade600, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Detection Confidence'),
            Text('${(confidence * 100).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              confidence > 0.7
                  ? Colors.green
                  : confidence > 0.4
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class VerificationResult {
  final bool isMatch;
  final double confidence;
  final String? watermarkId;
  final String? message;

  VerificationResult({
    required this.isMatch,
    required this.confidence,
    this.watermarkId,
    this.message,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      isMatch: json['isMatch'] ?? false,
      confidence: (json['confidence'] ?? 0).toDouble(),
      watermarkId: json['watermarkId'],
      message: json['message'],
    );
  }
}
