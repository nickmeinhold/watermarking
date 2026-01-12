import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/token.dart';
import '../services/api_service.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_button.dart';

class TokenDetailPage extends StatefulWidget {
  final int tokenId;

  const TokenDetailPage({super.key, required this.tokenId});

  @override
  State<TokenDetailPage> createState() => _TokenDetailPageState();
}

class _TokenDetailPageState extends State<TokenDetailPage> {
  Token? _token;
  bool _loading = true;
  String? _error;

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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Token #${widget.tokenId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Error loading token', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadToken,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final token = _token!;
    final wallet = context.watch<WalletProvider>();
    final isOwner = wallet.isConnected &&
        wallet.address?.toLowerCase() == token.currentOwner.toLowerCase();

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Expanded(
                  flex: 3,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: token.previewUrl != null
                          ? Image.network(
                              token.previewUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Details
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (token.description.isNotEmpty) ...[
                        Text(
                          token.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildChip(token.licenseType.displayName, Icons.gavel),
                      const SizedBox(height: 24),
                      _buildInfoCard(token, isOwner),
                      const SizedBox(height: 16),
                      _buildActionButtons(token, isOwner),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.image,
        size: 64,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  Widget _buildInfoCard(Token token, bool isOwner) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow('Creator', _shortAddress(token.creator)),
            const Divider(),
            _buildInfoRow(
              'Owner',
              _shortAddress(token.currentOwner),
              trailing: isOwner
                  ? const Chip(
                      label: Text('You', style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.green,
                      labelStyle: TextStyle(color: Colors.white),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )
                  : null,
            ),
            const Divider(),
            _buildInfoRow('License', token.licenseType.displayName),
            const Divider(),
            _buildInfoRow('Minted', _formatDate(token.mintedAt)),
            if (token.watermarkId != null) ...[
              const Divider(),
              _buildInfoRow('Watermark ID', token.watermarkId!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Token token, bool isOwner) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.go('/verify/${widget.tokenId}'),
          icon: const Icon(Icons.verified),
          label: const Text('Verify Authenticity'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _copyLink(),
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
        if (token.transactionHash != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openExplorer(token.transactionHash!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('View on Polygonscan'),
          ),
        ],
      ],
    );
  }

  String _shortAddress(String address) {
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _copyLink() {
    final url = 'https://tindart.com/token/${widget.tokenId}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _openExplorer(String txHash) async {
    final url = Uri.parse('https://polygonscan.com/tx/$txHash');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
