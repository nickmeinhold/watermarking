import 'dart:convert';
import 'dart:html' as html;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:http/http.dart' as http;
import 'package:redux/redux.dart';
import 'package:watermarking_core/watermarking_core.dart';

// TODO: Update this to your deployed auth function URL
const String _authFunctionUrl = String.fromEnvironment(
  'AUTH_FUNCTION_URL',
  defaultValue: 'http://localhost:8000',
);

// Discord OAuth config - must match auth function
const String _discordClientId = String.fromEnvironment(
  'DISCORD_CLIENT_ID',
  defaultValue: '',
);

class OpeningPage extends StatefulWidget {
  const OpeningPage({super.key});

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _OpeningPageState extends State<OpeningPage> {
  bool _isSigningIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkForDiscordCallback();
  }

  /// Check if we're returning from Discord OAuth with a code
  Future<void> _checkForDiscordCallback() async {
    final uri = Uri.parse(html.window.location.href);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code != null) {
      // Clear the URL parameters
      html.window.history.replaceState(null, '', uri.path);

      // Exchange code for Firebase custom token
      await _exchangeDiscordCode(code);
    }
  }

  /// Exchange Discord OAuth code for Firebase custom token
  Future<void> _exchangeDiscordCode(String code) async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_authFunctionUrl/auth/discord'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode != 200) {
        throw Exception('Auth failed: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final customToken = data['customToken'] as String;

      // Sign in with the custom token
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      if (mounted) {
        StoreProvider.of<AppState>(context).dispatch(const ActionSignin());
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSigningIn = false;
      });
    }
  }

  /// Start Discord OAuth flow
  void _signInWithDiscord() {
    if (_discordClientId.isEmpty) {
      setState(() {
        _errorMessage = 'Discord client ID not configured';
      });
      return;
    }

    const redirectUri = 'https://watermarking-4a428.web.app/opening';

    final discordUrl = Uri.https('discord.com', '/api/oauth2/authorize', {
      'client_id': _discordClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'identify',
    });

    html.window.location.href = discordUrl.toString();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      // Use Firebase Auth's signInWithPopup directly for web
      // This doesn't require a client ID meta tag
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);

      if (mounted) {
        StoreProvider.of<AppState>(context).dispatch(const ActionSignin());
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSigningIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: StoreConnector<AppState, UserModel>(
          converter: (Store<AppState> store) => store.state.user,
          builder: (BuildContext context, UserModel user) {
            if (user.waiting || _isSigningIn) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Watermarking',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Digital watermark your images',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _signInWithDiscord,
                  icon: const Icon(Icons.discord),
                  label: const Text('Sign in with Discord'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2), // Discord blurple
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
