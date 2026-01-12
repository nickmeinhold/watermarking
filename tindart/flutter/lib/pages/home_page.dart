import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../widgets/wallet_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tindart'),
        actions: const [
          WalletButton(),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  _buildHero(context),
                  const SizedBox(height: 64),
                  _buildFeatures(context),
                  const SizedBox(height: 64),
                  _buildHowItWorks(context),
                  const SizedBox(height: 64),
                  _buildCTA(context),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        Text(
          'AI Art with Verified Provenance',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Watermark, mint, and sell your AI-generated artwork with clear copyright licensing.',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Consumer<WalletProvider>(
          builder: (context, wallet, _) {
            if (wallet.isConnected) {
              return ElevatedButton.icon(
                onPressed: () => context.go('/mint'),
                icon: const Icon(Icons.add),
                label: const Text('Mint Your Art'),
              );
            }
            return ElevatedButton.icon(
              onPressed: wallet.isConnecting ? null : () => wallet.connect(),
              icon: wallet.isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet),
              label: Text(wallet.isConnecting ? 'Connecting...' : 'Connect Wallet to Start'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatures(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        _FeatureCard(
          icon: Icons.fingerprint,
          title: 'Invisible Watermark',
          description: 'Survives print, scan, and screenshot. Your proof of origin.',
        ),
        _FeatureCard(
          icon: Icons.gavel,
          title: 'Clear Licensing',
          description: 'Choose display, commercial, or full transfer rights.',
        ),
        _FeatureCard(
          icon: Icons.verified,
          title: 'NFT Provenance',
          description: 'On-chain record of ownership and transfer history.',
        ),
        _FeatureCard(
          icon: Icons.attach_money,
          title: 'Low Cost',
          description: 'Starting at \$1. No gas fees on Polygon.',
        ),
      ],
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    return Column(
      children: [
        Text(
          'How It Works',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 48,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _StepCard(number: '1', title: 'Upload', description: 'Select your AI artwork'),
            _StepCard(number: '2', title: 'Choose License', description: 'Display, commercial, or transfer'),
            _StepCard(number: '3', title: 'Sign & Mint', description: 'Watermark applied, NFT created'),
            _StepCard(number: '4', title: 'Sell or Verify', description: 'Trade or prove authenticity'),
          ],
        ),
      ],
    );
  }

  Widget _buildCTA(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              'Ready to protect your art?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/gallery'),
                  child: const Text('Browse Gallery'),
                ),
                const SizedBox(width: 16),
                Consumer<WalletProvider>(
                  builder: (context, wallet, _) {
                    return ElevatedButton(
                      onPressed: () {
                        if (wallet.isConnected) {
                          context.go('/mint');
                        } else {
                          wallet.connect();
                        }
                      },
                      child: Text(wallet.isConnected ? 'Start Minting' : 'Connect Wallet'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
