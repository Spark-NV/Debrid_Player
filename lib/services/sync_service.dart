import 'dart:convert';
import '../database/database_helper.dart';
import 'storage_service.dart';
import 'tmdb_service.dart';

class SyncService {
  final TMDBService _tmdbService = TMDBService();

  Future<void> _processActors(List<dynamic> cast) async {
    for (var actor in cast) {
      if (actor['id'] != null && actor['profile_path'] != null) {
        await _tmdbService.downloadActorImage(
          actor['id'],
          actor['profile_path'],
        );
      }
    }
  }

  Future<void> syncMetadata() async {
    print('Starting metadata sync...');
    
    final allMovies = await DatabaseHelper.instance.getAllMovies();
    final allShows = await DatabaseHelper.instance.getAllTvShows();
    
    final movies = await DatabaseHelper.instance.getMoviesWithoutMetadata();
    final shows = await DatabaseHelper.instance.getTvShowsWithoutMetadata();
    
    print('Found ${movies.length} of ${allMovies.length} movies needing metadata');
    print('Found ${shows.length} of ${allShows.length} TV shows needing metadata');
    print('Skipping ${allMovies.length - movies.length} movies with existing metadata');
    print('Skipping ${allShows.length - shows.length} TV shows with existing metadata');

    for (var movie in movies) {
      try {
        if (movie.tmdbId == null) {
          print('Skipping movie ${movie.title}: No TMDB ID');
          continue;
        }
        print('Fetching metadata for movie: ${movie.title}');
        
        final metadata = await _tmdbService.getMovieDetails(movie.tmdbId!);
        
        await StorageService.instance.saveMetadata(movie.tmdbId!, metadata);
        
        if (metadata['title'] != null) {
          await DatabaseHelper.instance.updateMovieTitle(
            movie.tmdbId!,
            metadata['title'],
          );
        }
        if (metadata['release_date'] != null) {
          await DatabaseHelper.instance.updateMovieReleaseDate(
            movie.tmdbId!,
            metadata['release_date'],
          );
        }

        if (metadata['poster_path'] != null) {
          final posterUrl = await _tmdbService.buildImageUrl('w500', metadata['poster_path']);
          final posterBytes = await _tmdbService.downloadImage(posterUrl);
          if (posterBytes != null) {
            await StorageService.instance.savePoster(movie.tmdbId!, posterBytes);
          }
        }
        
        if (metadata['credits']?['cast'] != null) {
          await _processActors(metadata['credits']['cast']);
        }
        
        await DatabaseHelper.instance.updateMovieMetadataStatus(movie.tmdbId!, true);
      } catch (e) {
        print('Error fetching metadata for movie ${movie.title}: $e');
      }
    }

    for (var show in shows) {
      try {
        if (show.tmdbId == null) {
          print('Skipping TV show ${show.title}: No TMDB ID');
          continue;
        }
        print('Fetching metadata for TV show: ${show.title}');
        
        final metadata = await _tmdbService.getTVShowDetails(show.tmdbId!);
        
        await StorageService.instance.saveMetadata(show.tmdbId!, metadata);
        
        if (metadata['name'] != null) {
          await DatabaseHelper.instance.updateTvShowTitle(
            show.tmdbId!,
            metadata['name'],
          );
        }
        if (metadata['first_air_date'] != null) {
          await DatabaseHelper.instance.updateTvShowFirstAirDate(
            show.tmdbId!,
            metadata['first_air_date'],
          );
        }

        if (metadata['poster_path'] != null) {
          final posterUrl = await _tmdbService.buildImageUrl('w500', metadata['poster_path']);
          final posterBytes = await _tmdbService.downloadImage(posterUrl);
          if (posterBytes != null) {
            await StorageService.instance.savePoster(show.tmdbId!, posterBytes);
          }
        }
        
        if (metadata['credits']?['cast'] != null) {
          await _processActors(metadata['credits']['cast']);
        }
        
        await DatabaseHelper.instance.updateTvShowMetadataStatus(show.tmdbId!, true);
      } catch (e) {
        print('Error fetching metadata for show ${show.title}: $e');
      }
    }

    print('Metadata sync completed');
  }
} 