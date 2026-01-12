import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/token.dart';
import '../providers/mint_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_button.dart';

class MintPage extends StatelessWidget {
  const MintPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mint Your Art'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: const [
          WalletButton(),
          SizedBox(width: 16),
        ],
      ),
      body: Consumer<MintProvider>(
        builder: (context, mint, _) {
          if (mint.state == MintState.success) {
            return _MintSuccess(result: mint.result!);
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
                      _ImageUploader(),
                      if (mint.hasImage) ...[
                        const SizedBox(height: 24),
                        _MintForm(),
                        const SizedBox(height: 24),
                        _LicenseSelector(),
                        const SizedBox(height: 32),
                        _MintButton(),
                      ],
                      if (mint.error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorMessage(message: mint.error!),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageUploader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mint = context.watch<MintProvider>();

    return Card(
      child: InkWell(
        onTap: mint.isMinting ? null : () => _pickImage(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: mint.hasImage ? 400 : 250,
          padding: const EdgeInsets.all(24),
          child: mint.hasImage
              ? Stack(
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          mint.imageBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: mint.isMinting ? null : () => mint.clearImage(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Click to upload your artwork',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PNG, JPG, GIF up to 50MB',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        context.read<MintProvider>().setImage(file.bytes!, file.name);
      }
    }
  }
}

class _MintForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mint = context.watch<MintProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Give your artwork a name',
              ),
              onChanged: mint.setName,
              enabled: !mint.isMinting,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Tell the story behind your art (optional)',
              ),
              maxLines: 3,
              onChanged: mint.setDescription,
              enabled: !mint.isMinting,
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mint = context.watch<MintProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'License Type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose what rights buyers will receive',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ...LicenseType.values.map((license) {
              final isSelected = mint.licenseType == license;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: mint.isMinting ? null : () => mint.setLicenseType(license),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Radio<LicenseType>(
                          value: license,
                          groupValue: mint.licenseType,
                          onChanged: mint.isMinting
                              ? null
                              : (value) => mint.setLicenseType(value!),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                license.displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                license.description,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${license.price.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MintButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mint = context.watch<MintProvider>();
    final wallet = context.watch<WalletProvider>();

    if (mint.isMinting) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              LinearProgressIndicator(value: mint.progress),
              const SizedBox(height: 16),
              Text(
                mint.statusMessage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: mint.canMint ? () => mint.mint() : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
          ),
          child: Text(
            'Mint for \$${mint.licenseType.price.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'By minting, you agree to our Terms of Service and confirm you have the right to this artwork.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
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
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MintSuccess extends StatelessWidget {
  final MintResult result;

  const _MintSuccess({required this.result});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Successfully Minted!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Token #${result.tokenId}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(label: 'Watermark ID', value: result.watermarkId ?? '-'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Transaction',
                    value: result.transactionHash != null
                        ? '${result.transactionHash!.substring(0, 10)}...'
                        : '-',
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.read<MintProvider>().reset();
                          },
                          child: const Text('Mint Another'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.go('/token/${result.tokenId}');
                          },
                          child: const Text('View Token'),
                        ),
                      ),
                    ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
