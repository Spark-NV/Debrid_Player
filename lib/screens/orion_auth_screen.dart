import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../config/paths_config.dart';

class OrionAuthScreen {
  static final OrionAuthScreen instance = OrionAuthScreen._internal();
  OrionAuthScreen._internal();

  static const bool _hideButtonWhenAuthenticated = true;
  bool _isAuthenticating = false;
  String? _authLink;
  String? _authCode;
  String? _qrCode;
  Timer? _authCheckTimer;
  int _authCheckInterval = 5;
  DateTime? _authExpiration;
  String? _apiKey;
  final String _baseUrl = 'https://api.orionoid.com';
  static const int _authTimeoutSeconds = 40;
  Timer? _timeoutTimer;
  bool _isAuthSuccessful = false;

  Future<String?> getApiKey() async {
    if (_apiKey != null) return _apiKey;
    
    final file = File(PathsConfig.orionKeyPath);
    if (await file.exists()) {
      String fileContent = await file.readAsString();
      if (fileContent.startsWith('orion_api_key = ')) {
        _apiKey = fileContent.substring('orion_api_key = '.length).trim();
        return _apiKey;
      }
    }
    return null;
  }

  Future<void> saveApiKey(String key) async {
    final dir = Directory(PathsConfig.apiKeysDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    final file = File(PathsConfig.orionKeyPath);
    await file.writeAsString('orion_api_key = $key');
    _apiKey = key;
  }

  Future<void> startAuthentication(BuildContext context) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your Orion API key first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isAuthenticating) {
      debugPrint('Authentication already in progress');
      return;
    }

    _isAuthenticating = true;
    _isAuthSuccessful = false;

    try {
      debugPrint('Starting Orion authentication...');
      
      final Map<String, String> formData = {
        'keyapp': _apiKey ?? '',
        'mode': 'user',
        'action': 'authenticate',
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      debugPrint('Request URL: $_baseUrl');
      debugPrint('Request headers: ${response.request?.headers}');
      debugPrint('Request body: $formData');
      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = json.decode(response.body);
      
      if (data['result']['status'] == 'success') {
        debugPrint('Initial authentication successful');
        
        final authData = data['data'];
        _authCode = authData['code'];
        _authLink = authData['direct'];
        _qrCode = authData['qr'];
        _authCheckInterval = authData['interval'];
        _authExpiration = DateTime.fromMillisecondsSinceEpoch(
          authData['expiration'] * 1000,
        );

        debugPrint('Auth code: $_authCode');
        debugPrint('Auth link: $_authLink');
        debugPrint('QR code: $_qrCode');
        debugPrint('Check interval: $_authCheckInterval');
        debugPrint('Expiration: $_authExpiration');

        _startAuthenticationCheck(context);
        
        _timeoutTimer = Timer(Duration(seconds: _authTimeoutSeconds), () {
          debugPrint('Authentication timed out after $_authTimeoutSeconds seconds');
          Navigator.of(context).pop();
          _cancelAuthentication(context, 'Authentication timed out');
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Orion Authentication'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    const Text(
                      'Please visit the following link and enter the code:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(_authLink ?? ''),
                    const SizedBox(height: 16),
                    const Text(
                      'Code:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(
                      _authCode ?? '',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 16),
                    if (_qrCode != null) Image.network(_qrCode!),
                    const SizedBox(height: 16),
                    Text(
                      'This dialog will close in $_authTimeoutSeconds seconds',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (!_isAuthSuccessful) {
                      _cancelAuthentication(context, 'Authentication cancelled');
                    }
                  },
                ),
              ],
            );
          },
        );
      } else {
        throw Exception(data['result']['message'] ?? 'Authentication failed');
      }
    } catch (e, stackTrace) {
      debugPrint('Error during authentication:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      _isAuthenticating = false;
    }
  }

  void _startAuthenticationCheck(BuildContext context) {
    debugPrint('\n=== Starting authentication check polling ===');
    _authCheckTimer?.cancel();
    
    debugPrint('Making initial check...');
    _checkAuthStatus(context);
    
    _authCheckTimer = Timer.periodic(
      Duration(seconds: _authCheckInterval),
      (timer) {
        debugPrint('\n=== Polling attempt ${timer.tick} ===');
        debugPrint('Time: ${DateTime.now()}');
        _checkAuthStatus(context);
      },
    );

    debugPrint('Timer created: ${_authCheckTimer != null}');
  }

  Future<void> _checkAuthStatus(BuildContext context) async {
    debugPrint('\nStarting auth status check');
    
    if (_authExpiration != null && DateTime.now().isAfter(_authExpiration!)) {
      debugPrint('Authentication expired at: $_authExpiration');
      _cancelAuthentication(context, 'Authentication expired');
      return;
    }

    try {
      final Map<String, String> formData = {
        'keyapp': _apiKey ?? '',
        'mode': 'user',
        'action': 'authenticate',
        'code': _authCode ?? '',
      };

      debugPrint('\nSending auth check request:');
      debugPrint('URL: $_baseUrl');
      debugPrint('Form data: $formData');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      debugPrint('\nReceived auth check response:');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final status = data['result']['type'];
        debugPrint('Current auth status: $status');
        
        switch (status) {
          case 'userauthpending':
            debugPrint('Still waiting for user approval...');
            break;
          case 'userauthapprove':
            debugPrint('User approved! Getting token...');
            if (data['data']?['token'] != null) {
              final token = data['data']['token'];
              debugPrint('Successfully received token');
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('orion_token', token);
              _isAuthSuccessful = true;
              
              Navigator.of(context).pop();
              _cancelAuthentication(context, 'Authentication successful', isError: false);
            } else {
              throw Exception('No token received in approval response');
            }
            break;
          case 'userauthinreject':
            debugPrint('User rejected the authentication');
            _cancelAuthentication(context, 'Authentication rejected by user');
            break;
          case 'userauthexpired':
            debugPrint('Authentication code expired');
            _cancelAuthentication(context, 'Authentication expired');
            break;
          default:
            debugPrint('Received unknown status: $status');
            _cancelAuthentication(context, 'Unknown authentication status');
        }
      } else {
        throw Exception('Auth check failed with status ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('\nError during auth check:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _cancelAuthentication(context, 'Error checking auth status');
    }
  }

  void _cancelAuthentication(BuildContext context, String message, {bool isError = true}) {
    debugPrint('\n=== Cancelling authentication ===');
    debugPrint('Reason: $message');
    debugPrint('Is error: $isError');
    
    if (_authCheckTimer != null) {
      debugPrint('Cancelling polling timer');
      _authCheckTimer?.cancel();
      _authCheckTimer = null;
    }
    
    if (_timeoutTimer != null) {
      debugPrint('Cancelling timeout timer');
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
    }

    _isAuthenticating = false;
    _authLink = null;
    _authCode = null;
    _qrCode = null;
    _authExpiration = null;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> clearToken() async {
    debugPrint('Clearing Orion auth token...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('orion_token');
    debugPrint('Orion auth token cleared');
  }

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('orion_token');
    return token != null;
  }

  Future<bool> shouldShowAuthButton() async {
    if (!_hideButtonWhenAuthenticated) {
      return true;
    }
    return !(await isAuthenticated());
  }
} 