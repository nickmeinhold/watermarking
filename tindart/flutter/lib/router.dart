import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/wallet_provider.dart';
import 'pages/home_page.dart';
import 'pages/mint_page.dart';
import 'pages/gallery_page.dart';
import 'pages/token_detail_page.dart';
import 'pages/verify_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/mint',
      builder: (context, state) => const MintPage(),
      redirect: (context, state) {
        final wallet = context.read<WalletProvider>();
        if (!wallet.isConnected) {
          return '/?connect=true';
        }
        return null;
      },
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => const GalleryPage(),
    ),
    GoRoute(
      path: '/token/:tokenId',
      builder: (context, state) {
        final tokenId = int.tryParse(state.pathParameters['tokenId'] ?? '');
        if (tokenId == null) {
          return const Scaffold(body: Center(child: Text('Invalid token ID')));
        }
        return TokenDetailPage(tokenId: tokenId);
      },
    ),
    GoRoute(
      path: '/verify/:tokenId',
      builder: (context, state) {
        final tokenId = int.tryParse(state.pathParameters['tokenId'] ?? '');
        if (tokenId == null) {
          return const Scaffold(body: Center(child: Text('Invalid token ID')));
        }
        return VerifyPage(tokenId: tokenId);
      },
    ),
  ],
);
