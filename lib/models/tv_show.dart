class TvShow {
  final int? simklId;
  final String? tmdbId;
  final String? imdbId;
  final String? title;
  final String? firstAirDate;
  final String? dateAdded;
  final bool hasMetadata;
  bool isWatched;

  TvShow({
    this.simklId,
    this.tmdbId,
    this.imdbId,
    this.title,
    this.firstAirDate,
    this.dateAdded,
    this.hasMetadata = false,
    this.isWatched = false,
  });

  factory TvShow.fromJson(Map<String, dynamic> json) {
    final showData = json['show'] ?? json;
    
    String? tmdbId;
    String? imdbId;
    if (showData['ids'] != null) {
      tmdbId = showData['ids']['tmdb']?.toString();
      imdbId = showData['ids']['imdb']?.toString();
    }

    String? firstAirDate;
    if (showData['year'] != null) {
      firstAirDate = '${showData['year']}-01-01';
    }

    return TvShow(
      simklId: showData['ids']?['simkl'],
      tmdbId: tmdbId,
      imdbId: imdbId,
      title: showData['title'],
      firstAirDate: firstAirDate,
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
      'first_air_date': firstAirDate,
      'date_added': dateAdded,
      'has_metadata': hasMetadata ? 1 : 0,
    };
  }
} 