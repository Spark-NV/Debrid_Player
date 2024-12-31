import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/movie.dart';
import '../models/tv_show.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/settings_screen.dart';
import '../config/paths_config.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('player.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    await Directory(PathsConfig.databaseDir).create(recursive: true);
    
    return await openDatabase(
      PathsConfig.databasePath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movies(
        simkl_id INTEGER PRIMARY KEY,
        tmdb_id TEXT,
        imdb_id TEXT,
        title TEXT,
        release_date TEXT,
        has_metadata INTEGER DEFAULT 0,
        date_added TEXT DEFAULT CURRENT_TIMESTAMP,
        is_watched INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('CREATE INDEX idx_movies_title ON movies(title COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_movies_release_date ON movies(release_date)');
    await db.execute('CREATE INDEX idx_movies_date_added ON movies(date_added)');
    await db.execute('CREATE INDEX idx_movies_imdb_id ON movies(imdb_id)');

    await db.execute('''
      CREATE TABLE tv_shows(
        simkl_id INTEGER PRIMARY KEY,
        tmdb_id TEXT,
        imdb_id TEXT,
        title TEXT,
        first_air_date TEXT,
        has_metadata INTEGER DEFAULT 0,
        date_added TEXT DEFAULT CURRENT_TIMESTAMP,
        is_watched INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('CREATE INDEX idx_tvshows_title ON tv_shows(title COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_tvshows_first_air_date ON tv_shows(first_air_date)');
    await db.execute('CREATE INDEX idx_tvshows_date_added ON tv_shows(date_added)');
    await db.execute('CREATE INDEX idx_tvshows_imdb_id ON tv_shows(imdb_id)');

    await db.execute('''
      CREATE TABLE episode_watched_status (
        tmdb_show_id TEXT,
        season_number INTEGER,
        episode_number INTEGER,
        is_watched INTEGER DEFAULT 0,
        PRIMARY KEY (tmdb_show_id, season_number, episode_number)
      )
    ''');

    await db.execute('CREATE INDEX idx_episode_watched_show ON episode_watched_status(tmdb_show_id)');
    await db.execute('CREATE INDEX idx_episode_watched_season ON episode_watched_status(tmdb_show_id, season_number)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE movies ADD COLUMN date_added TEXT DEFAULT CURRENT_TIMESTAMP');
      await db.execute('ALTER TABLE tv_shows ADD COLUMN date_added TEXT DEFAULT CURRENT_TIMESTAMP');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE movies ADD COLUMN release_date TEXT');
      await db.execute('ALTER TABLE tv_shows ADD COLUMN first_air_date TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE movies ADD COLUMN is_watched INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE tv_shows ADD COLUMN is_watched INTEGER DEFAULT 0');
    }
      if (oldVersion < 5) {
    await db.execute('''
      CREATE TABLE episode_watched_status (
        tmdb_show_id TEXT,
        season_number INTEGER,
        episode_number INTEGER,
        is_watched INTEGER DEFAULT 0,
        PRIMARY KEY (tmdb_show_id, season_number, episode_number)
      )
    ''');
    
    await db.execute('CREATE INDEX idx_episode_watched_show ON episode_watched_status(tmdb_show_id)');
    await db.execute('CREATE INDEX idx_episode_watched_season ON episode_watched_status(tmdb_show_id, season_number)');
  }
  }

  Future<void> insertMovie(Movie movie) async {
    if (movie.imdbId == null) return;
    
    final db = await database;
    await db.insert(
      'movies',
      {
        'simkl_id': movie.simklId,
        'tmdb_id': movie.tmdbId,
        'imdb_id': movie.imdbId,
        'title': movie.title,
        'release_date': movie.releaseDate,
        'has_metadata': 0,
        'date_added': DateTime.now().toIso8601String(),
        'is_watched': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMovies(List<Movie> movies) async {
    final validMovies = movies.where((movie) => movie.imdbId != null).toList();
    if (validMovies.isEmpty) return;
    
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (var movie in validMovies) {
      batch.insert(
        'movies',
        {
          'simkl_id': movie.simklId,
          'tmdb_id': movie.tmdbId,
          'imdb_id': movie.imdbId,
          'title': movie.title,
          'release_date': movie.releaseDate,
          'has_metadata': 0,
          'date_added': now,
          'is_watched': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  Future<List<Movie>> getAllMovies({SortMethod? sortMethod}) async {
    final db = await database;
    String orderBy;
    
    switch (sortMethod) {
      case SortMethod.alphabeticalAsc:
        orderBy = 'title COLLATE NOCASE ASC';
      case SortMethod.alphabeticalDesc:
        orderBy = 'title COLLATE NOCASE DESC';
      case SortMethod.releaseDateDesc:
        orderBy = 'release_date DESC';
      case SortMethod.releaseDateAsc:
        orderBy = 'release_date ASC';
      case SortMethod.dateAddedDesc:
        orderBy = 'date_added DESC';
      case SortMethod.dateAddedAsc:
        orderBy = 'date_added ASC';
      case null:
        orderBy = 'title COLLATE NOCASE ASC';
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      orderBy: orderBy,
    );
    
    return List.generate(maps.length, (i) {
      return Movie(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
        releaseDate: maps[i]['release_date'],
        dateAdded: maps[i]['date_added'],
        hasMetadata: maps[i]['has_metadata'] == 1,
        isWatched: maps[i]['is_watched'] == 1,
      );
    });
  }

  Future<void> deleteAllMovies() async {
    final db = await database;
    await db.delete('movies');
  }

  Future<void> insertTvShow(TvShow show) async {
    if (show.imdbId == null) return;
    
    final db = await database;
    await db.insert(
      'tv_shows',
      {
        'simkl_id': show.simklId,
        'tmdb_id': show.tmdbId,
        'imdb_id': show.imdbId,
        'title': show.title,
        'first_air_date': show.firstAirDate,
        'has_metadata': 0,
        'date_added': DateTime.now().toIso8601String(),
        'is_watched': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTvShows(List<TvShow> shows) async {
    final validShows = shows.where((show) => show.imdbId != null).toList();
    if (validShows.isEmpty) return;
    
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    
    for (var show in validShows) {
      batch.insert(
        'tv_shows',
        {
          'simkl_id': show.simklId,
          'tmdb_id': show.tmdbId,
          'imdb_id': show.imdbId,
          'title': show.title,
          'first_air_date': show.firstAirDate,
          'has_metadata': 0,
          'date_added': now,
          'is_watched': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  Future<List<TvShow>> getAllTvShows({SortMethod? sortMethod}) async {
    final db = await database;
    String orderBy;
    
    switch (sortMethod) {
      case SortMethod.alphabeticalAsc:
        orderBy = 'title COLLATE NOCASE ASC';
      case SortMethod.alphabeticalDesc:
        orderBy = 'title COLLATE NOCASE DESC';
      case SortMethod.releaseDateDesc:
        orderBy = 'first_air_date DESC';
      case SortMethod.releaseDateAsc:
        orderBy = 'first_air_date ASC';
      case SortMethod.dateAddedDesc:
        orderBy = 'date_added DESC';
      case SortMethod.dateAddedAsc:
        orderBy = 'date_added ASC';
      case null:
        orderBy = 'title COLLATE NOCASE ASC';
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'tv_shows',
      orderBy: orderBy,
    );

    return List.generate(maps.length, (i) {
      return TvShow(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
        firstAirDate: maps[i]['first_air_date'],
        dateAdded: maps[i]['date_added'],
        hasMetadata: maps[i]['has_metadata'] == 1,
        isWatched: maps[i]['is_watched'] == 1,
      );
    });
  }

  Future<void> deleteAllTvShows() async {
    final db = await database;
    await db.delete('tv_shows');
  }

  Future<List<Movie>> getMoviesWithoutMetadata() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'has_metadata = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return Movie(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
      );
    });
  }

  Future<List<TvShow>> getTvShowsWithoutMetadata() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tv_shows',
      where: 'has_metadata = ?',
      whereArgs: [0],
    );

    return List.generate(maps.length, (i) {
      return TvShow(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
      );
    });
  }

  Future<void> updateMovieMetadataStatus(String tmdbId, bool hasMetadata) async {
    final db = await database;
    await db.update(
      'movies',
      {'has_metadata': hasMetadata ? 1 : 0},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateTvShowMetadataStatus(String tmdbId, bool hasMetadata) async {
    final db = await database;
    await db.update(
      'tv_shows',
      {'has_metadata': hasMetadata ? 1 : 0},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  Future<bool> movieExists(int? simklId) async {
    if (simklId == null) return false;
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'movies',
      where: 'simkl_id = ?',
      whereArgs: [simklId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> tvShowExists(int? simklId) async {
    if (simklId == null) return false;
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'tv_shows',
      where: 'simkl_id = ?',
      whereArgs: [simklId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<SortMethod> getCurrentMovieSortMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return SortMethod.values[prefs.getInt('movie_sort_method') ?? 0];
  }

  Future<SortMethod> getCurrentTvShowSortMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return SortMethod.values[prefs.getInt('tvshow_sort_method') ?? 0];
  }

  Future<void> refreshSortOrder() async {
    final movieSort = await getCurrentMovieSortMethod();
    final tvSort = await getCurrentTvShowSortMethod();
    
    await getAllMovies(sortMethod: movieSort);
    await getAllTvShows(sortMethod: tvSort);
  }

  Future<void> updateMovieReleaseDate(String tmdbId, String releaseDate) async {
    final db = await database;
    await db.update(
      'movies',
      {'release_date': releaseDate},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateTvShowFirstAirDate(String tmdbId, String firstAirDate) async {
    final db = await database;
    await db.update(
      'tv_shows',
      {'first_air_date': firstAirDate},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateMovieTitle(String tmdbId, String title) async {
    final db = await database;
    await db.update(
      'movies',
      {'title': title},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateTvShowTitle(String tmdbId, String title) async {
    final db = await database;
    await db.update(
      'tv_shows',
      {'title': title},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<String?> getMovieImdbId(String tmdbId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'movies',
      columns: ['imdb_id'],
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['imdb_id'] : null;
  }

  Future<String?> getTvShowImdbId(String tmdbId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'tv_shows',
      columns: ['imdb_id'],
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['imdb_id'] : null;
  }

  Future<List<Movie>> searchMovies(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
    );

    return List.generate(maps.length, (i) {
      return Movie(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
        releaseDate: maps[i]['release_date'],
        dateAdded: maps[i]['date_added'],
        hasMetadata: maps[i]['has_metadata'] == 1,
      );
    });
  }

  Future<List<TvShow>> searchTvShows(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tv_shows',
      where: 'title LIKE ?',
      whereArgs: ['%$query%'],
    );

    return List.generate(maps.length, (i) {
      return TvShow(
        simklId: maps[i]['simkl_id'],
        tmdbId: maps[i]['tmdb_id'],
        title: maps[i]['title'],
        firstAirDate: maps[i]['first_air_date'],
        dateAdded: maps[i]['date_added'],
        hasMetadata: maps[i]['has_metadata'] == 1,
      );
    });
  }

  Future<void> updateMovieWatchedStatus(String tmdbId, bool isWatched) async {
    final db = await database;
    await db.update(
      'movies',
      {'is_watched': isWatched ? 1 : 0},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateTvShowWatchedStatus(String tmdbId, bool isWatched) async {
    final db = await database;
    await db.update(
      'tv_shows',
      {'is_watched': isWatched ? 1 : 0},
      where: 'tmdb_id = ?',
      whereArgs: [tmdbId],
    );
  }

  Future<void> updateEpisodeWatchedStatus(
    String tmdbShowId, 
    int seasonNumber, 
    int episodeNumber, 
    bool isWatched
  ) async {
    final db = await database;
    await db.insert(
      'episode_watched_status', 
      {
        'tmdb_show_id': tmdbShowId,
        'season_number': seasonNumber,
        'episode_number': episodeNumber,
        'is_watched': isWatched ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getEpisodeWatchedStatus(
    String tmdbShowId, 
    int seasonNumber, 
    int episodeNumber
  ) async {
    final db = await database;
    final result = await db.query(
      'episode_watched_status',
      where: 'tmdb_show_id = ? AND season_number = ? AND episode_number = ?',
      whereArgs: [tmdbShowId, seasonNumber, episodeNumber],
    );
    
    return result.isNotEmpty && result.first['is_watched'] == 1;
  }

  Future<List<int>> getWatchedEpisodesForSeason(
    String tmdbShowId, 
    int seasonNumber
  ) async {
    final db = await database;
    final results = await db.query(
      'episode_watched_status',
      where: 'tmdb_show_id = ? AND season_number = ? AND is_watched = 1',
      whereArgs: [tmdbShowId, seasonNumber],
    );
    
    return results.map((e) => e['episode_number'] as int).toList();
  }
} 