import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../screens/movie_details_screen.dart';
import '../screens/tv_show_seasons_screen.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import '../services/storage_service.dart';
import '../screens/search_results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  Future<void> _performSearch(String query) async {
    final movies = await DatabaseHelper.instance.searchMovies(query);
    final tvShows = await DatabaseHelper.instance.searchTvShows(query);

    if (movies.length == 1 && tvShows.isEmpty) {
      await _navigateToMovieDetailsScreen(movies.first);
    } else if (tvShows.length == 1 && movies.isEmpty) {
      await _navigateToTvShowSeasonsScreen(tvShows.first);
    } else if (movies.isNotEmpty || tvShows.isNotEmpty) {
      _navigateToSearchResultsScreen(movies, tvShows);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results found')),
      );
    }
  }

  void _navigateToSearchResultsScreen(List<Movie> movies, List<TvShow> tvShows) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          movies: movies,
          tvShows: tvShows,
          onMovieSelected: (movie) => _navigateToMovieDetailsScreen(movie),
          onTvShowSelected: (tvShow) => _navigateToTvShowSeasonsScreen(tvShow),
        ),
      ),
    );
  }

  Future<void> _navigateToMovieDetailsScreen(Movie movie) async {
    final metadata = await StorageService.instance.getMetadata(movie.tmdbId!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(
          movie: movie,
          metadata: metadata ?? {},
        ),
      ),
    );
  }

  Future<void> _navigateToTvShowSeasonsScreen(TvShow tvShow) async {
    final metadata = await StorageService.instance.getMetadata(tvShow.tmdbId!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvShowSeasonsScreen(
          show: tvShow,
          metadata: metadata ?? {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: const InputDecoration(
            hintText: 'Search...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: _performSearch,
        ),
      ),
    );
  }
} 