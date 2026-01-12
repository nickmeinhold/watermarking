import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Wallet connection states
enum WalletState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Manages wallet connection and signing
class WalletProvider extends ChangeNotifier {
  WalletState _state = WalletState.disconnected;
  String? _address;
  String? _error;
  String? _authToken;
  int _chainId = 137; // Polygon mainnet

  WalletState get state => _state;
  String? get address => _address;
  String? get error => _error;
  String? get authToken => _authToken;
  int get chainId => _chainId;

  bool get isConnected => _state == WalletState.connected && _address != null;
  bool get isConnecting => _state == WalletState.connecting;

  String get shortAddress {
    if (_address == null) return '';
    return '${_address!.substring(0, 6)}...${_address!.substring(_address!.length - 4)}';
  }

  WalletProvider() {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('wallet_address');
      final savedToken = prefs.getString('auth_token');

      if (savedAddress != null && savedToken != null) {
        _address = savedAddress;
        _authToken = savedToken;
        _state = WalletState.connected;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load saved session: $e');
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_address != null && _authToken != null) {
        await prefs.setString('wallet_address', _address!);
        await prefs.setString('auth_token', _authToken!);
      }
    } catch (e) {
      debugPrint('Failed to save session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      await prefs.remove('auth_token');
    } catch (e) {
      debugPrint('Failed to clear session: $e');
    }
  }

  /// Connect wallet (simplified for web - uses mock for demo)
  /// In production, use WalletConnect or injected provider
  Future<void> connect() async {
    _state = WalletState.connecting;
    _error = null;
    notifyListeners();

    try {
      // For web, check if MetaMask is available
      if (kIsWeb) {
        await _connectWeb();
      } else {
        // For mobile, use WalletConnect
        await _connectMobile();
      }

      await _saveSession();
      _state = WalletState.connected;
    } catch (e) {
      _state = WalletState.error;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> _connectWeb() async {
    // In a real implementation, you would:
    // 1. Check for window.ethereum
    // 2. Request accounts
    // 3. Get SIWE message signed
    // 4. Create auth token

    // For demo, simulate connection
    await Future.delayed(const Duration(seconds: 1));

    // Simulated address (in production, get from MetaMask)
    _address = '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD7e';

    // Create SIWE auth token
    _authToken = await _createAuthToken(_address!);
  }

  Future<void> _connectMobile() async {
    // WalletConnect implementation would go here
    await Future.delayed(const Duration(seconds: 1));
    _address = '0x742d35Cc6634C0532925a3b844Bc9e7595f2bD7e';
    _authToken = await _createAuthToken(_address!);
  }

  Future<String> _createAuthToken(String address) async {
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 7));

    // SIWE message format
    final message = '''
tindart.com wants you to sign in with your Ethereum account:
$address

Sign in to Tindart

URI: https://api.tindart.com
Version: 1
Chain ID: $_chainId
Nonce: ${_generateNonce()}
Issued At: ${now.toIso8601String()}
Expiration Time: ${expiry.toIso8601String()}''';

    // In production, this signature would come from the wallet
    final signature = _mockSign(message, address);

    // Create token
    final tokenData = {
      'message': message,
      'signature': signature,
    };

    return base64Encode(utf8.encode(jsonEncode(tokenData)));
  }

  String _generateNonce() {
    final bytes = List<int>.generate(16, (i) => DateTime.now().microsecond % 256);
    return base64Url.encode(bytes).substring(0, 16);
  }

  String _mockSign(String message, String address) {
    // Mock signature for demo
    // In production, wallet.signMessage(message) would be called
    final hash = sha256.convert(utf8.encode(message + address));
    return '0x${hash.toString()}';
  }

  /// Sign a message with the connected wallet
  Future<String> signMessage(String message) async {
    if (!isConnected) {
      throw Exception('Wallet not connected');
    }

    // In production, call wallet.signMessage(message)
    // For demo, return mock signature
    final hash = sha256.convert(utf8.encode(message + _address!));
    return '0x${hash.toString()}';
  }

  /// Disconnect wallet
  Future<void> disconnect() async {
    _state = WalletState.disconnected;
    _address = null;
    _authToken = null;
    _error = null;
    await _clearSession();
    notifyListeners();
  }
}
