import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tv_show.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';
import '../screens/settings_screen.dart';
import '../screens/tv_show_seasons_screen.dart';
import '../config/key_bindings.dart';
import '../widgets/auto_scroll_text.dart';
import '../widgets/horizontal_scroll_text.dart';

class TVShowsScreen extends StatefulWidget {
  const TVShowsScreen({super.key});

  @override
  State<TVShowsScreen> createState() => _TVShowsScreenState();
}

class _TVShowsScreenState extends State<TVShowsScreen> {
  final List<TvShow> _tvShows = [];
  TvShow? _selectedShow;
  Map<String, dynamic>? _selectedMetadata;
  int _selectedIndex = 0;
  SortMethod _sortMethod = SortMethod.alphabeticalAsc;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _listFocusNode = FocusNode();
  final FocusNode _quickAccessFocusNode = FocusNode();
  final List<String> _alphabet = List.generate(26, (i) => String.fromCharCode(65 + i));
  bool _isQuickAccessFocused = false;
  bool _isJumping = false;
  String? _jumpingToLetter;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadSortMethod();
    await _loadInitialShows();
    
    SharedPreferences.getInstance().then((prefs) {
      prefs.reload().then((_) {
        _loadSortMethod();
        _resetAndReload();
      });
    });
  }

  Future<void> _loadSortMethod() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortMethod = SortMethod.values[prefs.getInt('tvshow_sort_method') ?? 0];
      print('Loaded sort method: $_sortMethod');
    });
  }

  Future<void> _resetAndReload() async {
    setState(() {
      _tvShows.clear();
      _selectedShow = null;
      _selectedMetadata = null;
    });
    await _loadInitialShows();
  }

  Future<void> _loadInitialShows() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final shows = await DatabaseHelper.instance.getAllTvShows(
        sortMethod: _sortMethod,
      );
      
      setState(() {
        _tvShows.clear();
        _tvShows.addAll(shows);
        if (_tvShows.isNotEmpty) {
          _selectShow(_tvShows[0], 0);
          _listFocusNode.requestFocus();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectShow(TvShow show, int index) async {
    final metadata = await StorageService.instance.getMetadata(show.tmdbId!);
    setState(() {
      _selectedShow = show;
      _selectedMetadata = metadata;
      _selectedIndex = index;
    });
  }

  Future<void> _jumpToLetter(String letter) async {
    setState(() {
      _isJumping = true;
      _jumpingToLetter = letter;
    });

    try {
      final index = _tvShows.indexWhere((show) => 
        (show.title ?? '').toUpperCase().startsWith(letter));
      
      if (index != -1) {
        _scrollController.jumpTo(
          index * 56.0,
        );
        setState(() {
          _selectedShow = _tvShows[index];
          _selectedIndex = index;
          _isQuickAccessFocused = false;
        });
        
        await _selectShow(_tvShows[index], index);
        
        _quickAccessFocusNode.unfocus();
        FocusScope.of(context).unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _listFocusNode.requestFocus();
        });
      }
    } finally {
      setState(() {
        _isJumping = false;
        _jumpingToLetter = null;
      });
    }
  }

  void _focusOnTvShow(TvShow show) {
    final index = _tvShows.indexWhere((s) => s.tmdbId == show.tmdbId);
    if (index != -1) {
      _scrollController.jumpTo(index * 56.0);
      setState(() {
        _selectedShow = _tvShows[index];
        _selectedIndex = index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listFocusNode.requestFocus();
      });
    }
  }

  void _onShowPressed(TvShow show) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvShowSeasonsScreen(
          show: show,
          metadata: _selectedMetadata!,
        ),
      ),
    );
  }

  void _handleListScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
        _selectShow(_tvShows[0], 0);
      } else if (_scrollController.position.pixels == 0 && notification.metrics.extentBefore == 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _selectShow(_tvShows[_tvShows.length - 1], _tvShows.length - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('TV Shows'),
        toolbarHeight: 0,
      ),
      primary: false,
      body: Row(
        children: [
          if (_selectedShow != null) ...[
            SizedBox(
              width: 275,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${_tvShows.length} TV Shows',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<File?>(
                      future: StorageService.instance.getPosterFile(_selectedShow!.tmdbId!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.file(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _handleListScroll(notification);
                          return true;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _tvShows.length,
                          itemBuilder: (context, index) {
                            final show = _tvShows[index];
                            final isSelected = show.tmdbId == _selectedShow?.tmdbId;
                            
                            return SizedBox(
                              height: 56,
                              child: Focus(
                                focusNode: index == _selectedIndex ? _listFocusNode : null,
                                onFocusChange: (hasFocus) {
                                  if (hasFocus) {
                                    _selectShow(show, index);
                                  }
                                },
                                onKey: (node, event) {
                                  if (event is RawKeyDownEvent) {
                                    if (KeyBindings.selectMedia.contains(event.logicalKey)) {
                                      _onShowPressed(show);
                                      return KeyEventResult.handled;
                                    }
                                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                      if (_sortMethod == SortMethod.alphabeticalAsc) {
                                        setState(() {
                                          _isQuickAccessFocused = true;
                                          _quickAccessFocusNode.requestFocus();
                                        });
                                      }
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.withOpacity(0.3),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: HorizontalScrollText(
                                          text: show.title ?? 'Unknown Title',
                                          textStyle: TextStyle(
                                            fontSize: 18,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (show.isWatched) 
                                        Icon(
                                          Icons.check_circle, 
                                          color: Colors.green, 
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  subtitle: FutureBuilder<Map<String, dynamic>?>(
                                    future: StorageService.instance.getMetadata(show.tmdbId!),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data?['first_air_date'] != null) {
                                        return Text(
                                          snapshot.data!['first_air_date'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  focusColor: Colors.blue.withOpacity(0.3),
                                  hoverColor: Colors.blue.withOpacity(0.2),
                                  onTap: () => _onShowPressed(show),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _alphabet.length,
                        itemBuilder: (context, index) {
                          return Focus(
                            focusNode: index == 0 ? _quickAccessFocusNode : null,
                            onFocusChange: (hasFocus) {
                              setState(() {
                                _isQuickAccessFocused = hasFocus;
                              });
                            },
                            onKey: (node, event) {
                              if (event is RawKeyDownEvent) {
                                if (KeyBindings.selectMedia.contains(event.logicalKey)) {
                                  _jumpToLetter(_alphabet[index]);
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                  setState(() {
                                    _isQuickAccessFocused = false;
                                    _listFocusNode.requestFocus();
                                  });
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final focusNode = Focus.of(context);
                                final isFocused = _isQuickAccessFocused && 
                                         FocusScope.of(context).focusedChild == focusNode;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: 21,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isFocused ? Colors.red.withOpacity(0.7) : null,
                                  ),
                                  child: Transform.scale(
                                    scale: isFocused ? 2.3 : 1.0,
                                    child: Text(
                                      _alphabet[index],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isFocused ? Colors.white : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (_isLoading && _tvShows.isEmpty)
                  const Center(child: CircularProgressIndicator()),
                if (_isJumping)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Jumping to letter $_jumpingToLetter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_selectedMetadata != null)
            Expanded(
              flex: 2,
              child: Container(
                height: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border(
                    left: BorderSide(
                      color: Colors.grey[800]!,
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMetadata!['name'] ?? 'Unknown Title',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedMetadata!['first_air_date'] != null 
                            ? 'First Aired: ${_selectedMetadata!['first_air_date']}'
                            : 'First Aired: N/A',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_selectedMetadata!['genres'] != null) ...[
                        Wrap(
                          spacing: 4,
                          children: [
                            for (var genre in (_selectedMetadata!['genres'] as List).take(2))
                              Chip(label: Text(genre['name'])),
                          ],
                        ),
                        const SizedBox(height: 1),
                      ],
                      Text(
                        'Number of Seasons: ${_selectedMetadata!['number_of_seasons']?.toString() ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Number of Episodes: ${_selectedMetadata!['number_of_episodes']?.toString() ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Overview:',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: AutoScrollText(
                          text: _selectedMetadata!['overview'] ?? 'No overview available',
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 17),
                      if (_selectedMetadata!['credits']?['cast'] != null) ...[
                        const Text(
                          'Cast:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (var actor in (_selectedMetadata!['credits']['cast'] as List).take(4))
                              Chip(label: Text(actor['name'])),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _quickAccessFocusNode.dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 