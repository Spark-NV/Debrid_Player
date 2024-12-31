import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';
import '../services/tmdb_service.dart';
import '../services/sync_service.dart';
import 'dart:io';
import '../config/paths_config.dart';

class SimklScreen extends StatefulWidget {
  const SimklScreen({super.key});

  @override
  State<SimklScreen> createState() => _SimklScreenState();
}

class _SimklScreenState extends State<SimklScreen> {
  bool _isAuthenticated = false;
  bool _isSyncing = false;
  Timer? _pollTimer;
  static const String _tokenKey = 'simkl_access_token';
  static const String _moviesKey = 'simkl_plantowatch_movies';
  static const String _lastSyncTimeKey = 'last_sync_time';
  final TMDBService tmdbService = TMDBService();

  static const bool _showAuthorizeButtonInDebug = false;

  final FocusNode _authorizeButtonFocusNode = FocusNode();
  final FocusNode _downloadButtonFocusNode = FocusNode();

  DateTime? _lastSyncTime;
  static const int _syncTimeoutMinutes = 1;

  String? _clientId;

  @override
  void initState() {
    super.initState();
    _loadSimklKeys();
    _checkAuthStatus();
    _loadLastSyncTime();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _authorizeButtonFocusNode.dispose();
    _downloadButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    setState(() {
      _isAuthenticated = token != null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isAuthenticated || _showAuthorizeButtonInDebug) {
        _authorizeButtonFocusNode.requestFocus();
      } else {
        _downloadButtonFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTimeMillis = prefs.getInt(_lastSyncTimeKey);
    if (lastSyncTimeMillis != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimeMillis);
    }
  }

  Future<void> _loadSimklKeys() async {
    try {
      final file = File(PathsConfig.simklKeysPath);
      
      print('Attempting to read file at: ${PathsConfig.simklKeysPath}');
      
      if (!await file.exists()) {
        print('File does not exist');
        await Directory(PathsConfig.apiKeysDir).create(recursive: true);
        throw Exception('API keys file not found. Please fill in your API keys');
      }

      final String fileContent = await file.readAsString();
      print('File content: $fileContent');
      
      if (fileContent.isEmpty) {
        throw Exception(
          'API keys file is empty. The file should contain:\n'
          'simkl_client_Id = your_client_id_here'
        );
      }
      
      if (fileContent.contains('simkl_client_Id = ')) {
        _clientId = fileContent
            .replaceAll('\r', '')
            .split('simkl_client_Id = ')[1]
            .split('\n')[0]
            .trim();
        print('Parsed client ID: $_clientId');
      }

      if (_clientId == null) {
        throw Exception(
          'Missing required SIMKL keys in configuration file.\n'
          'Please ensure simkl_client_Id is present.'
        );
      }

    } catch (e) {
      print('Error loading SIMKL keys: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading SIMKL keys: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<void> _startAuth(BuildContext context) async {
    if (_clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SIMKL client ID not loaded')),
      );
      return;
    }
    
    try {
      print('Starting auth process...');
      final response = await http.get(
        Uri.parse('https://api.simkl.com/oauth/pin?client_id=$_clientId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Initial response status: ${response.statusCode}');
      print('Initial response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userCode = data['user_code'];
        final expiresIn = data['expires_in'];
        final verificationUrl = data['verification_url'];
        final interval = data['interval'] ?? 5;

        print('Received user code: $userCode');

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Authentication Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Please visit: $verificationUrl'),
                const SizedBox(height: 10),
                Text('Enter this code: $userCode'),
                const SizedBox(height: 10),
                Text('Code expires in: ${expiresIn}s'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _pollTimer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        _startPolling(userCode, _clientId!, interval);
      }
    } catch (e) {
      print('Error in _startAuth: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting authentication: $e')),
      );
    }
  }

  void _startPolling(String userCode, String clientId, int interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: interval),
      (timer) => _pollForToken(userCode, clientId, timer),
    );
  }

  Future<void> _pollForToken(String userCode, String clientId, Timer timer) async {
    try {
      print('\n--- Polling attempt ---');
      print('Using user code: $userCode');
      
      final pollUrl = 'https://api.simkl.com/oauth/pin/$userCode?client_id=$clientId';
      print('Polling URL: $pollUrl');

      final response = await http.get(
        Uri.parse(pollUrl),
        headers: {'Content-Type': 'application/json'},
      );

      print('Poll response status: ${response.statusCode}');
      print('Poll response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed response data: $data');
        
        if (data['result'] == 'KO') {
          print('Still waiting for user authentication...');
          return;
        }
        
        if (data['result'] == 'OK' && data['access_token'] != null) {
          print('Authentication successful!');
          final accessToken = data['access_token'];
          print('Access token received: ${accessToken != null}');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, accessToken);
          
          timer.cancel();
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() {
            _isAuthenticated = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully authenticated!')),
          );
        }
      } else if (response.statusCode == 400) {
        print('Waiting for user to authenticate...');
      } else {
        print('Unexpected status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Polling error: $e');
      timer.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during authentication: $e')),
      );
    }
  }

  Future<void> _syncPlanToWatch() async {
    if (!_isAuthenticated) return;

    final now = DateTime.now();
    if (_lastSyncTime != null) {
      final difference = now.difference(_lastSyncTime!).inSeconds;
      final totalTimeoutSeconds = _syncTimeoutMinutes * 60;
      if (difference < totalTimeoutSeconds) {
        final secondsRemaining = totalTimeoutSeconds - difference;
        final minutesRemaining = secondsRemaining ~/ 60;
        final seconds = secondsRemaining % 60;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please wait $minutesRemaining minutes and $seconds seconds before syncing again.')),
        );
        return;
      }
    }

    setState(() {
      _isSyncing = true;
      _lastSyncTime = now;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncTimeKey, now.millisecondsSinceEpoch);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: const Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Syncing, please wait...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final movieResponse = await http.get(
        Uri.parse('https://api.simkl.com/sync/all-items/movies/plantowatch'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'simkl-api-key': _clientId!,
        },
      );

      if (movieResponse.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(movieResponse.body);
        final List<dynamic> movieData = responseData['movies'] ?? [];
        print('Raw movie data from SIMKL: $movieData');
        final movies = movieData.map((item) => Movie.fromJson(item)).toList();
        
        int newMovies = 0;
        for (var movie in movies) {
          if (!await DatabaseHelper.instance.movieExists(movie.simklId)) {
            await DatabaseHelper.instance.insertMovie(movie);
            newMovies++;
          }
        }
        print('Added $newMovies new movies from SIMKL');
      }

      final tvResponse = await http.get(
        Uri.parse('https://api.simkl.com/sync/all-items/shows/plantowatch'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'simkl-api-key': _clientId!,
        },
      );

      if (tvResponse.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(tvResponse.body);
        final List<dynamic> tvData = responseData['shows'] ?? [];
        final tvShows = tvData.map((item) => TvShow.fromJson(item)).toList();
        
        int newShows = 0;
        for (var show in tvShows) {
          if (!await DatabaseHelper.instance.tvShowExists(show.simklId)) {
            await DatabaseHelper.instance.insertTvShow(show);
            newShows++;
          }
        }
        print('Added $newShows new TV shows from SIMKL');
      }

      await SyncService().syncMetadata();

      await DatabaseHelper.instance.refreshSortOrder();

      if (!mounted) return;
      Navigator.of(context).pop();

    } catch (e) {
      print('Error during sync: $e');
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during sync: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SIMKL Settings')),
      primary: false,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isAuthenticated || _showAuthorizeButtonInDebug) ...[
              Focus(
                child: Builder(
                  builder: (context) {
                    final isFocused = Focus.of(context).hasFocus;
                    return Transform.scale(
                      scale: isFocused ? 1.5 : 1.0,
                      child: ElevatedButton(
                        focusNode: _authorizeButtonFocusNode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFocused ? Colors.blue : Colors.blueGrey[800],
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 10,
                        ),
                        onPressed: () => _startAuth(context),
                        child: const Text('Authorize'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            Focus(
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return Transform.scale(
                    scale: isFocused ? 1.5 : 1.0,
                    child: ElevatedButton(
                      focusNode: _downloadButtonFocusNode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFocused ? Colors.blue : Colors.blueGrey[800],
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 10,
                      ),
                      onPressed: (_isAuthenticated && !_isSyncing) ? _syncPlanToWatch : null,
                      child: const Text('Start Download Of New Movies'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 