import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';

class SearchResultsScreen extends StatefulWidget {
  final List<Movie> movies;
  final List<TvShow> tvShows;
  final Function(Movie) onMovieSelected;
  final Function(TvShow) onTvShowSelected;

  const SearchResultsScreen({
    super.key,
    required this.movies,
    required this.tvShows,
    required this.onMovieSelected,
    required this.onTvShowSelected,
  });

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final FocusNode _firstItemFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_firstItemFocusNode.canRequestFocus) {
        _firstItemFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        title: const Text('Search Results'),
      ),
      body: ListView(
        children: [
          if (widget.movies.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Movies',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...widget.movies.map((movie) {
              final index = widget.movies.indexOf(movie);
              return ListTile(
                focusNode: index == 0 ? _firstItemFocusNode : null,
                title: Text(movie.title ?? 'Unknown Title'),
                subtitle: Text('Release Date: ${movie.releaseDate ?? 'Unknown'}'),
                onTap: () => widget.onMovieSelected(movie),
              );
            }),
          ],
          if (widget.tvShows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'TV Shows',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...widget.tvShows.map((tvShow) {
              final index = widget.tvShows.indexOf(tvShow);
              return ListTile(
                focusNode: index == 0 && widget.movies.isEmpty ? _firstItemFocusNode : null,
                title: Text(tvShow.title ?? 'Unknown Title'),
                subtitle: Text('First Air Date: ${tvShow.firstAirDate ?? 'Unknown'}'),
                onTap: () => widget.onTvShowSelected(tvShow),
              );
            }),
          ],
        ],
      ),
    );
  }
} 