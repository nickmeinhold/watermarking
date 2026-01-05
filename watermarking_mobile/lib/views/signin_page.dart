import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:watermarking_core/watermarking_core.dart';
import 'package:watermarking_mobile/views/signin_button.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});
  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  bool _isSigningIn = false;
  String? _statusMessage;
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    final signIn = GoogleSignIn.instance;

    // Initialize without parameters - iOS uses GIDClientID from Info.plist
    await signIn.initialize();

    // Listen to authentication events
    _authSubscription = signIn.authenticationEvents.listen(
      _handleAuthenticationEvent,
      onError: _handleAuthenticationError,
    );

    // Attempt lightweight (silent) authentication
    signIn.attemptLightweightAuthentication();
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        await _signInToFirebase(user);
      case GoogleSignInAuthenticationEventSignOut():
        setState(() {
          _statusMessage = null;
          _isSigningIn = false;
        });
    }
  }

  void _handleAuthenticationError(Object error) {
    setState(() {
      _errorMessage = error.toString();
      _isSigningIn = false;
    });
  }

  Future<void> _signInToFirebase(GoogleSignInAccount user) async {
    setState(() {
      _statusMessage = 'Got Google user, signing into Firebase...';
    });

    try {
      // Get client authorization with access token
      final clientAuth = await user.authorizationClient.authorizeScopes([]);

      // Create Firebase credential with access token
      // Firebase Auth can work with just accessToken for Google Sign-In
      final credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        StoreProvider.of<AppState>(context).dispatch(const ActionSignin());
        setState(() {
          _statusMessage = 'Signed in: ${userCredential.user?.displayName}';
          _isSigningIn = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSigningIn = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _statusMessage = 'Starting Google Sign-In...';
    });

    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google Sign-In not supported on this platform');
      }
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        setState(() {
          _statusMessage = 'Sign in cancelled';
          _isSigningIn = false;
        });
      } else {
        setState(() {
          _errorMessage = e.toString();
          _isSigningIn = false;
        });
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
    return MaterialApp(
      home: Scaffold(
        body: _isSigningIn ? _buildWaitingWidget() : _buildSigninButtons(),
      ),
    );
  }

  Widget _buildSigninButtons() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            onPressed: _signInWithGoogle,
            child: signinButton('Google', 'assets/google.png'),
          ),
          if (_statusMessage != null) ...[
            const Padding(padding: EdgeInsets.all(10.0)),
            Text(_statusMessage!, style: const TextStyle(color: Colors.grey)),
          ],
          if (_errorMessage != null) ...[
            const Padding(padding: EdgeInsets.all(10.0)),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(_statusMessage!),
          ],
        ],
      ),
    );
  }
}
