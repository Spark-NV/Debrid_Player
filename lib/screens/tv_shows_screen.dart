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
      
      print('Initially loaded ${shows.length} TV shows');
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

  void _focusOnTvShow(TvShow show) {
    final index = _tvShows.indexWhere((s) => s.tmdbId == show.tmdbId);
    if (index != -1) {
      final key = GlobalKey();
      final context = key.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        _scrollController.animateTo(
          position.dy,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      setState(() {
        _selectedShow = _tvShows[index];
        _selectedIndex = index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listFocusNode.requestFocus();
      });
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
      body: Row(
        children: [
          if (_selectedShow != null) ...[
            SizedBox(
              width: 300,
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
                ListView.builder(
                  controller: _scrollController,
                  itemCount: _tvShows.length,
                  itemBuilder: (context, index) {
                    final show = _tvShows[index];
                    final isSelected = show.tmdbId == _selectedShow?.tmdbId;
                    
                    return Focus(
                      focusNode: index == 0 ? _listFocusNode : null,
                      onFocusChange: (hasFocus) {
                        if (hasFocus) {
                          _selectShow(show, index);
                        }
                      },
                      onKey: (node, event) {
                        if (event is RawKeyDownEvent &&
                            KeyBindings.selectMedia.contains(event.logicalKey)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TvShowSeasonsScreen(
                                show: show,
                                metadata: _selectedMetadata ?? {},
                              ),
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ListTile(
                        key: index == _selectedIndex ? GlobalKey() : null,
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.3),
                        title: Text(
                          show.title ?? 'Unknown Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: _selectedMetadata != null && isSelected
                            ? Text(
                                'First Air Date: ${show.firstAirDate ?? 'Unknown'}',
                                style: const TextStyle(color: Colors.grey),
                              )
                            : null,
                        focusColor: Colors.blue.withOpacity(0.3),
                        hoverColor: Colors.blue.withOpacity(0.2),
                      ),
                    );
                  },
                ),
                if (_isLoading && _tvShows.isEmpty)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),

          if (_selectedMetadata != null)
            Expanded(
              flex: 3,
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
                      if (_selectedMetadata!['genres'] != null) ...[
                        Wrap(
                          spacing: 4,
                          children: [
                            for (var genre in _selectedMetadata!['genres'])
                              Chip(label: Text(genre['name'])),
                          ],
                        ),
                        const SizedBox(height: 1),
                      ],
                      Text(
                        'Number of Seasons: ${_selectedMetadata!['number_of_seasons']?.toString() ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Number of Episodes: ${_selectedMetadata!['number_of_episodes']?.toString() ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Overview:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: AutoScrollText(
                          text: _selectedMetadata!['overview'] ?? 'No overview available',
                          textStyle: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedMetadata!['credits']?['cast'] != null) ...[
                        const Text(
                          'Cast:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var actor in (_selectedMetadata!['credits']['cast'] as List).take(5))
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
} 