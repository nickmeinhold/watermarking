import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/wallet_provider.dart';
import 'providers/mint_provider.dart';
import 'router.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TindartApp());
}

class TindartApp extends StatelessWidget {
  const TindartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProxyProvider<WalletProvider, MintProvider>(
          create: (_) => MintProvider(),
          update: (_, wallet, mint) => mint!..updateWallet(wallet),
        ),
      ],
      child: MaterialApp.router(
        title: 'Tindart',
        theme: TindartTheme.light,
        darkTheme: TindartTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
