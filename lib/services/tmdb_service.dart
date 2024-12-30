import 'package:http/http.dart' as http;
import 'dart:convert';
import './storage_service.dart';
import 'dart:io';
import '../config/paths_config.dart';

class TMDBService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/';
  String? tmdb_api_key;

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  TMDBService() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      final file = File(PathsConfig.apiKeysFilePath);

      if (!await file.exists()) {

        await Directory(PathsConfig.apiKeysDir).create(recursive: true);
   
        await file.writeAsString('tmdb_api_key = your_api_key_here');
        throw Exception(
          'TMDB api key not found. A template has been created at:\n'
          '${PathsConfig.apiKeysFilePath}\n'
          'Please add your TMDB api key.'
        );
      }

      final lines = await file.readAsLines();
      for (var line in lines) {
        if (line.startsWith('tmdb_api_key')) {
          tmdb_api_key = line.split('=')[1].trim();
          _headers['Authorization'] = 'Bearer $tmdb_api_key';
          break;
        }
      }

      if (tmdb_api_key == null || tmdb_api_key == 'your_api_key_here') {
        throw Exception('Please set a valid TMDB api key in the api_keys.txt file');
      }
    } catch (e) {
      print('Error loading TMDB api key: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMovieDetails(String tmdbId) async {
    try {
      print('Fetching TMDB movie details for ID: $tmdbId');
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/$tmdbId?append_to_response=credits'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Successfully received TMDB metadata for movie: ${data['title']}');
        return data;
      } else {
        print('TMDB API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load movie details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching movie details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTVShowDetails(String tmdbId) async {
    try {
      print('Fetching TMDB TV show details for ID: $tmdbId');
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/$tmdbId?append_to_response=credits'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Successfully received TMDB metadata for TV show: ${data['name']}');
        
        if (data['seasons'] != null) {
          final List<dynamic> seasons = data['seasons'];
          for (var i = 0; i < seasons.length; i++) {
            final basicSeasonInfo = seasons[i];
            final seasonNumber = basicSeasonInfo['season_number'];
            final seasonDetails = await getTVSeasonDetails(tmdbId, seasonNumber);
            
            seasons[i] = {
              ...seasonDetails,
              'episode_count': basicSeasonInfo['episode_count'],
            };
          }
        }
        
        return data;
      } else {
        print('TMDB API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load TV show details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching TV show details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTVSeasonDetails(String showId, int seasonNumber) async {
    try {
      print('Fetching TMDB TV season details for show ID: $showId, season: $seasonNumber');
      final response = await http.get(
        Uri.parse('$_baseUrl/tv/$showId/season/$seasonNumber?append_to_response=credits'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Successfully received TMDB season details with ${data['episodes']?.length ?? 0} episodes');
        return data;
      } else {
        print('TMDB API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load season details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching season details: $e');
      rethrow;
    }
  }

  String buildImageUrl(String size, String path) {
    return '$_imageBaseUrl$size$path';
  }

  Future<List<int>?> downloadImage(String url) async {
    try {
      print('Downloading image from: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print('Successfully downloaded image');
        return response.bodyBytes;
      }
      print('Failed to download image: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  Future<void> downloadActorImage(int actorId, String profilePath) async {
    if (await StorageService.instance.getActorImageFile(actorId) != null) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://image.tmdb.org/t/p/w185$profilePath'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        await StorageService.instance.saveActorImage(
          actorId,
          response.bodyBytes,
        );
      }
    } catch (e) {
      print('Error downloading actor image: $e');
    }
  }
}