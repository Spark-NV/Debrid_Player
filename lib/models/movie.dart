class Movie {
  final int? simklId;
  final String? tmdbId;
  final String? imdbId;
  final String? title;
  final String? releaseDate;
  final String? dateAdded;
  final bool hasMetadata;
  bool isWatched;

  Movie({
    this.simklId,
    this.tmdbId,
    this.imdbId,
    this.title,
    this.releaseDate,
    this.dateAdded,
    this.hasMetadata = false,
    this.isWatched = false,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final movieData = json['movie'] ?? json;
    
    String? tmdbId;
    String? imdbId;
    if (movieData['ids'] != null) {
      tmdbId = movieData['ids']['tmdb']?.toString();
      imdbId = movieData['ids']['imdb']?.toString();
    }

    String? releaseDate;
    if (movieData['year'] != null) {
      releaseDate = '${movieData['year']}-01-01';
    }

    return Movie(
      simklId: movieData['ids']?['simkl'],
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: movieData['title'],
      releaseDate: releaseDate,
      dateAdded: DateTime.now().toIso8601String(),
      hasMetadata: false,
      isWatched: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'simkl_id': simklId,
      'tmdb_id': tmdbId,
      'imdb_id': imdbId,
      'title': title,
      'release_date': releaseDate,
      'date_added': dateAdded,
      'has_metadata': hasMetadata ? 1 : 0,
    };
  }
} 