import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/database_helper.dart';
import 'dart:async';
import 'orion_auth_screen.dart';
import '../config/paths_config.dart';

enum SortMethod {
  alphabeticalAsc,
  alphabeticalDesc,
  releaseDateDesc,
  releaseDateAsc,
  dateAddedDesc,
  dateAddedAsc,
}

enum OrionSortValue {
  best,
  filesize,
  videoquality,
}

enum MovieMinSize {
  mb600(600, '600 MB'),
  gb1(1000, '1 GB'),
  gb1_5(1500, '1.5 GB'),
  gb2(2000, '2 GB'),
  gb3(3000, '3 GB'),
  gb4(4000, '4 GB'),
  gb5(5000, '5 GB'),
  gb6(6000, '6 GB'),
  gb8(8000, '8 GB'),
  gb10(10000, '10 GB');

  final int size;
  final String label;
  const MovieMinSize(this.size, this.label);
}

enum MovieMaxSize {
  gb3(3000, '3 GB'),
  gb4(4000, '4 GB'),
  gb5(5000, '5 GB'),
  gb6(6000, '6 GB'),
  gb7(7000, '7 GB'),
  gb8(8000, '8 GB'),
  gb9(9000, '9 GB'),
  gb10(10000, '10 GB'),
  gb12(12000, '12 GB'),
  gb15(15000, '15 GB'),
  gb20(20000, '20 GB'),
  gb25(25000, '25 GB'),
  gb35(35000, '35 GB'),
  gb50(50000, '50 GB'),
  gb75(75000, '75 GB');

  final int size;
  final String label;
  const MovieMaxSize(this.size, this.label);
}

enum TVMinSize {
  mb300(300, '300 MB'),
  mb500(500, '500 MB'),
  gb1(1000, '1 GB'),
  gb1_5(1500, '1.5 GB'),
  gb2(2000, '2 GB'),
  gb3(3000, '3 GB');

  final int size;
  final String label;
  const TVMinSize(this.size, this.label);
}

enum TVMaxSize {
  gb1_5(1500, '1.5 GB'),
  gb2(2000, '2 GB'),
  gb3(3000, '3 GB'),
  gb4(4000, '4 GB'),
  gb5(5000, '5 GB'),
  gb6(6000, '6 GB'),
  gb7(7000, '7 GB'),
  gb8(8000, '8 GB'),
  gb9(9000, '9 GB'),
  gb10(10000, '10 GB'),
  gb12(12000, '12 GB');

  final int size;
  final String label;
  const TVMaxSize(this.size, this.label);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SortMethod _movieSortMethod = SortMethod.alphabeticalAsc;
  SortMethod _tvShowSortMethod = SortMethod.alphabeticalAsc;
  bool _isAuthenticating = false;
  String? _authLink;
  String? _authCode;
  String? _qrCode;
  Timer? _authCheckTimer;
  int _authCheckInterval = 5;
  DateTime? _authExpiration;
  final _apiKeyController = TextEditingController();
  final _focusNode = FocusNode();
  OrionSortValue _movieOrionSortValue = OrionSortValue.videoquality;
  bool _movieOrionSubtitleLanguages = true;
  bool _movieOrionAudioLanguages = true;
  MovieMinSize _movieOrionMinFileSize = MovieMinSize.gb1;
  MovieMaxSize _movieOrionMaxFileSize = MovieMaxSize.gb10;
  
  OrionSortValue _tvOrionSortValue = OrionSortValue.videoquality;
  bool _tvOrionSubtitleLanguages = true;
  bool _tvOrionAudioLanguages = true;
  TVMinSize _tvOrionMinFileSize = TVMinSize.mb500;
  TVMaxSize _tvOrionMaxFileSize = TVMaxSize.gb4;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _focusNode.dispose();
    _authCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _movieSortMethod = SortMethod.values[prefs.getInt('movie_sort_method') ?? 0];
      _tvShowSortMethod = SortMethod.values[prefs.getInt('tvshow_sort_method') ?? 0];
      _movieOrionSortValue = OrionSortValue.values[
        prefs.getInt('movie_orion_sort_value') ?? OrionSortValue.videoquality.index
      ];
      _movieOrionSubtitleLanguages = prefs.getBool('movie_orion_subtitle_languages') ?? true;
      _movieOrionAudioLanguages = prefs.getBool('movie_orion_audio_languages') ?? true;
      _movieOrionMinFileSize = MovieMinSize.values.firstWhere(
        (e) => e.size == (prefs.getInt('movie_orion_min_filesize') ?? 1000),
        orElse: () => MovieMinSize.gb1,
      );
      _movieOrionMaxFileSize = MovieMaxSize.values.firstWhere(
        (e) => e.size == (prefs.getInt('movie_orion_max_filesize') ?? 10000),
        orElse: () => MovieMaxSize.gb10,
      );
      
      _tvOrionSortValue = OrionSortValue.values[
        prefs.getInt('tv_orion_sort_value') ?? OrionSortValue.videoquality.index
      ];
      _tvOrionSubtitleLanguages = prefs.getBool('tv_orion_subtitle_languages') ?? true;
      _tvOrionAudioLanguages = prefs.getBool('tv_orion_audio_languages') ?? true;
      _tvOrionMinFileSize = TVMinSize.values.firstWhere(
        (e) => e.size == (prefs.getInt('tv_orion_min_filesize') ?? 500),
        orElse: () => TVMinSize.mb500,
      );
      _tvOrionMaxFileSize = TVMaxSize.values.firstWhere(
        (e) => e.size == (prefs.getInt('tv_orion_max_filesize') ?? 4000),
        orElse: () => TVMaxSize.gb4,
      );
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('movie_sort_method', _movieSortMethod.index);
    await prefs.setInt('tvshow_sort_method', _tvShowSortMethod.index);
    
    await DatabaseHelper.instance.refreshSortOrder();
    
    await prefs.reload();
    
    await prefs.setInt('movie_orion_sort_value', _movieOrionSortValue.index);
    await prefs.setBool('movie_orion_subtitle_languages', _movieOrionSubtitleLanguages);
    await prefs.setBool('movie_orion_audio_languages', _movieOrionAudioLanguages);
    await prefs.setInt('movie_orion_min_filesize', _movieOrionMinFileSize.size);
    await prefs.setInt('movie_orion_max_filesize', _movieOrionMaxFileSize.size);
    
    await prefs.setInt('tv_orion_sort_value', _tvOrionSortValue.index);
    await prefs.setBool('tv_orion_subtitle_languages', _tvOrionSubtitleLanguages);
    await prefs.setBool('tv_orion_audio_languages', _tvOrionAudioLanguages);
    await prefs.setInt('tv_orion_min_filesize', _tvOrionMinFileSize.size);
    await prefs.setInt('tv_orion_max_filesize', _tvOrionMaxFileSize.size);
  }

  Future<void> _showApiKeyDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Orion API Key'),
          content: TextField(
            controller: _apiKeyController,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onEditingComplete: () async {
              if (_apiKeyController.text.length <= 25) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API key is too short, please enter a valid key'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await OrionAuthScreen.instance.saveApiKey(_apiKeyController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API key saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save API key: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            decoration: const InputDecoration(
              hintText: 'Enter your API key here',
              border: OutlineInputBorder(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrionSettings(String title, {
    required OrionSortValue sortValue,
    required Function(OrionSortValue?) onSortChanged,
    required dynamic minFileSize,
    required dynamic maxFileSize,
    required Function(dynamic) onMinSizeChanged,
    required Function(dynamic) onMaxSizeChanged,
    required bool subtitleLanguages,
    required Function(bool?) onSubtitleChanged,
    required bool audioLanguages,
    required Function(bool?) onAudioChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        const Text('Sort Results By:', style: TextStyle(fontSize: 16)),
        DropdownButton<OrionSortValue>(
          value: sortValue,
          onChanged: onSortChanged,
          items: OrionSortValue.values.map((value) {
            return DropdownMenuItem(
              value: value,
              child: Text(value.name),
            );
          }).toList(),
        ),
        
        const Text('File Size Range:', style: TextStyle(fontSize: 16)),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Minimum Size:'),
                  DropdownButton<dynamic>(
                    value: minFileSize,
                    onChanged: (value) {
                      if (value != null && value.size < maxFileSize.size) {
                        onMinSizeChanged(value);
                      }
                    },
                    items: (title.contains('Movie') 
                        ? MovieMinSize.values.map((MovieMinSize size) => DropdownMenuItem(
                              value: size,
                              child: Text(size.label),
                            ))
                        : TVMinSize.values.map((TVMinSize size) => DropdownMenuItem(
                              value: size,
                              child: Text(size.label),
                            ))
                    ).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Maximum Size:'),
                  DropdownButton<dynamic>(
                    value: maxFileSize,
                    onChanged: (value) {
                      if (value != null && value.size > minFileSize.size) {
                        onMaxSizeChanged(value);
                      }
                    },
                    items: (title.contains('Movie')
                        ? MovieMaxSize.values.map((MovieMaxSize size) => DropdownMenuItem(
                              value: size,
                              child: Text(size.label),
                            ))
                        : TVMaxSize.values.map((TVMaxSize size) => DropdownMenuItem(
                              value: size,
                              child: Text(size.label),
                            ))
                    ).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        CheckboxListTile(
          title: const Text('Force English Subtitles'),
          value: subtitleLanguages,
          onChanged: onSubtitleChanged,
        ),
        
        CheckboxListTile(
          title: const Text('Force English Audio'),
          value: audioLanguages,
          onChanged: onAudioChanged,
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Movies Sort Method:',
                style: TextStyle(fontSize: 16),
              ),
              DropdownButton<SortMethod>(
                value: _movieSortMethod,
                onChanged: (SortMethod? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _movieSortMethod = newValue;
                    });
                    _saveSettings();
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: SortMethod.alphabeticalAsc,
                    child: Text('Alphabetical (A-Z)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.alphabeticalDesc,
                    child: Text('Alphabetical (Z-A)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.releaseDateDesc,
                    child: Text('Release Date (Newest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.releaseDateAsc,
                    child: Text('Release Date (Oldest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.dateAddedDesc,
                    child: Text('Date Added (Newest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.dateAddedAsc,
                    child: Text('Date Added (Oldest First)'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text(
                'TV Shows Sort Method:',
                style: TextStyle(fontSize: 16),
              ),
              DropdownButton<SortMethod>(
                value: _tvShowSortMethod,
                onChanged: (SortMethod? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _tvShowSortMethod = newValue;
                    });
                    _saveSettings();
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: SortMethod.alphabeticalAsc,
                    child: Text('Alphabetical (A-Z)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.alphabeticalDesc,
                    child: Text('Alphabetical (Z-A)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.releaseDateDesc,
                    child: Text('Release Date (Newest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.releaseDateAsc,
                    child: Text('Release Date (Oldest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.dateAddedDesc,
                    child: Text('Date Added (Newest First)'),
                  ),
                  DropdownMenuItem(
                    value: SortMethod.dateAddedAsc,
                    child: Text('Date Added (Oldest First)'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'API Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<bool>(
                future: OrionAuthScreen.instance.shouldShowAuthButton(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: _showApiKeyDialog,
                          child: const Text('Set Orion API Key'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => OrionAuthScreen.instance.startAuthentication(context),
                          child: const Text('Authenticate Orion'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await OrionAuthScreen.instance.clearToken();
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Orion authentication cleared')),
                            );
                          },
                          child: const Text('Clear Orion Auth'),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 32),
              _buildOrionSettings(
                'Movie Search Settings',
                sortValue: _movieOrionSortValue,
                onSortChanged: (value) {
                  if (value != null) {
                    setState(() => _movieOrionSortValue = value);
                    _saveSettings();
                  }
                },
                minFileSize: _movieOrionMinFileSize,
                maxFileSize: _movieOrionMaxFileSize,
                onMinSizeChanged: (value) {
                  setState(() => _movieOrionMinFileSize = value);
                  _saveSettings();
                },
                onMaxSizeChanged: (value) {
                  setState(() => _movieOrionMaxFileSize = value);
                  _saveSettings();
                },
                subtitleLanguages: _movieOrionSubtitleLanguages,
                onSubtitleChanged: (value) {
                  if (value != null) {
                    setState(() => _movieOrionSubtitleLanguages = value);
                    _saveSettings();
                  }
                },
                audioLanguages: _movieOrionAudioLanguages,
                onAudioChanged: (value) {
                  if (value != null) {
                    setState(() => _movieOrionAudioLanguages = value);
                    _saveSettings();
                  }
                },
              ),
              
              _buildOrionSettings(
                'TV Show Search Settings',
                sortValue: _tvOrionSortValue,
                onSortChanged: (value) {
                  if (value != null) {
                    setState(() => _tvOrionSortValue = value);
                    _saveSettings();
                  }
                },
                minFileSize: _tvOrionMinFileSize,
                maxFileSize: _tvOrionMaxFileSize,
                onMinSizeChanged: (value) {
                  setState(() => _tvOrionMinFileSize = value);
                  _saveSettings();
                },
                onMaxSizeChanged: (value) {
                  setState(() => _tvOrionMaxFileSize = value);
                  _saveSettings();
                },
                subtitleLanguages: _tvOrionSubtitleLanguages,
                onSubtitleChanged: (value) {
                  if (value != null) {
                    setState(() => _tvOrionSubtitleLanguages = value);
                    _saveSettings();
                  }
                },
                audioLanguages: _tvOrionAudioLanguages,
                onAudioChanged: (value) {
                  if (value != null) {
                    setState(() => _tvOrionAudioLanguages = value);
                    _saveSettings();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 