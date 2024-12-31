import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';
import '../screens/settings_screen.dart';
import '../screens/movie_details_screen.dart';
import '../config/key_bindings.dart';
import '../widgets/auto_scroll_text.dart';
import '../widgets/horizontal_scroll_text.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final List<Movie> _movies = [];
  Movie? _selectedMovie;
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
    await _loadInitialMovies();
    
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
      _sortMethod = SortMethod.values[prefs.getInt('movie_sort_method') ?? 0];
      print('Loaded sort method: $_sortMethod');
    });
  }

  Future<void> _resetAndReload() async {
    setState(() {
      _movies.clear();
      _selectedMovie = null;
      _selectedMetadata = null;
    });
    await _loadInitialMovies();
  }

  Future<void> _loadInitialMovies() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final movies = await DatabaseHelper.instance.getAllMovies(
        sortMethod: _sortMethod,
      );
      
      setState(() {
        _movies.clear();
        _movies.addAll(movies);
        if (_movies.isNotEmpty) {
          _selectMovie(_movies[0], 0);
          _listFocusNode.requestFocus();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMovie(Movie movie, int index) async {
    final metadata = await StorageService.instance.getMetadata(movie.tmdbId!);
    setState(() {
      _selectedMovie = movie;
      _selectedMetadata = metadata;
      _selectedIndex = index;
    });
  }

  void _onMoviePressed(Movie movie) {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(
          movie: movie,
          metadata: _selectedMetadata ?? {},
        ),
      ),
    );
  }

  void _handleListScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(0);
        _selectMovie(_movies[0], 0);
      } else if (_scrollController.position.pixels == 0 && notification.metrics.extentBefore == 0) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _selectMovie(_movies[_movies.length - 1], _movies.length - 1);
      }
    }
  }

  Future<void> _jumpToLetter(String letter) async {
    setState(() {
      _isJumping = true;
      _jumpingToLetter = letter;
    });

    try {
      final index = _movies.indexWhere((movie) => 
        (movie.title ?? '').toUpperCase().startsWith(letter));
      
      if (index != -1) {
        _scrollController.jumpTo(
          index * 56.0,
        );
        setState(() {
          _selectedMovie = _movies[index];
          _selectedIndex = index;
          _isQuickAccessFocused = false;
        });
        
        await _selectMovie(_movies[index], index);
        
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

  void _focusOnMovie(Movie movie) {
    final index = _movies.indexWhere((m) => m.tmdbId == movie.tmdbId);
    if (index != -1) {
      _scrollController.jumpTo(index * 56.0);
      setState(() {
        _selectedMovie = _movies[index];
        _selectedIndex = index;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listFocusNode.requestFocus();
      });
    }
  }

  void _showPopoutMenu(Movie movie) {
  final FocusNode buttonFocusNode = FocusNode();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        buttonFocusNode.requestFocus();
      });

      return AlertDialog(
        title: Text('Options for ${movie.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: buttonFocusNode,
                focusColor: Colors.blue.withOpacity(0.3),
                hoverColor: Colors.blue.withOpacity(0.3),
                splashColor: Colors.blue.withOpacity(0.5),
                onTap: () async {
                  Navigator.pop(context);

                  final newWatchedStatus = !movie.isWatched;

                  await DatabaseHelper.instance.updateMovieWatchedStatus(
                    movie.tmdbId!,
                    newWatchedStatus,
                  );

                  setState(() {
                    movie.isWatched = newWatchedStatus;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        newWatchedStatus
                            ? 'Marked ${movie.title} as watched'
                            : 'Marked ${movie.title} as unwatched',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    movie.isWatched ? 'Mark as Unwatched' : 'Mark as Watched',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      primary: false,
      body: Row(
        children: [
          if (_selectedMovie != null) ...[
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${_movies.length} Movies',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<File?>(
                      future: StorageService.instance.getPosterFile(_selectedMovie!.tmdbId!),
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
                          itemCount: _movies.length,
                          itemBuilder: (context, index) {
                            final movie = _movies[index];
                            final isSelected = movie.tmdbId == _selectedMovie?.tmdbId;
                            
                            return SizedBox(
                              height: 56,
                              child: Focus(
                                focusNode: index == _selectedIndex ? _listFocusNode : null,
                                onFocusChange: (hasFocus) {
                                  if (hasFocus) {
                                    _selectMovie(movie, index);
                                  }
                                },
                                onKey: (node, event) {
                                  if (event is RawKeyDownEvent) {
                                    if (KeyBindings.selectMedia.contains(event.logicalKey)) {
                                      _onMoviePressed(movie);
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
                                    if (event.logicalKey == KeyBindings.popoutMenu) {
                                      _showPopoutMenu(movie);
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
                                          text: movie.title ?? 'Unknown Title',
                                          textStyle: TextStyle(
                                            fontSize: 18,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (movie.isWatched) 
                                        Icon(
                                          Icons.check_circle, 
                                          color: Colors.green, 
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  focusColor: Colors.blue.withOpacity(0.3),
                                  hoverColor: Colors.blue.withOpacity(0.2),
                                  onTap: () => _onMoviePressed(movie),
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
                if (_isLoading && _movies.isEmpty)
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
                      const SizedBox(height: 1),
                      if (_selectedMetadata!['genres'] != null) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var genre in (_selectedMetadata!['genres'] as List).take(2))
                              Chip(label: Text(genre['name'])),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        'Rating: ${_selectedMetadata!['vote_average']?.toStringAsFixed(1) ?? 'N/A'} / 10',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Runtime: ${_selectedMetadata!['runtime']?.toString() ?? 'N/A'} minutes',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Budget: \$${_selectedMetadata!['budget']?.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},'
                        ) ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Revenue: \$${_selectedMetadata!['revenue']?.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},'
                        ) ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Overview:',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
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
                          'Top Billed Cast:',
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