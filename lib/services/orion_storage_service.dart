import 'dart:io';
import 'dart:convert';
import '../config/paths_config.dart';

class OrionStorageService {
  static final OrionStorageService instance = OrionStorageService._internal();
  OrionStorageService._internal();

  static const Duration cacheDuration = Duration(hours: 1);

  Future<void> saveOrionResponse(String imdbId, Map<String, dynamic> response) async {
    try {
      final retrieved = response['data']?['count']?['retrieved'] ?? 0;
      if (retrieved == 0) {
        print('Skipping cache save for IMDB ID: $imdbId - No results retrieved');
        return;
      }

      final directory = Directory(PathsConfig.orionDir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${PathsConfig.orionDir}/$imdbId.json');
      
      final dataToSave = {
        'timestamp': DateTime.now().toIso8601String(),
        'response': response,
      };

      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(dataToSave),
      );

      print('Successfully saved Orion response for IMDB ID: $imdbId with ${retrieved} streams');
    } catch (e) {
      print('Error saving Orion response: $e');
    }
  }

  Future<Map<String, dynamic>?> getOrionResponse(String imdbId) async {
    try {
      final file = File('${PathsConfig.orionDir}/$imdbId.json');
      
      if (!await file.exists()) {
        print('No cache file exists for IMDB ID: $imdbId');
        return null;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      
      final response = data['response'] as Map<String, dynamic>;
      
      final retrieved = response['data']?['count']?['retrieved'] ?? 0;
      if (retrieved == 0) {
        print('Cached response for IMDB ID: $imdbId has no streams, treating as cache miss');
        await file.delete();
        return null;
      }

      final timestamp = DateTime.parse(data['timestamp']);
      if (DateTime.now().difference(timestamp) > cacheDuration) {
        print('Cache expired for IMDB ID: $imdbId (age: ${DateTime.now().difference(timestamp).inHours} hours)');
        return null;
      }

      print('Found valid cached Orion response for IMDB ID: $imdbId with ${retrieved} streams');
      return response;
    } catch (e) {
      print('Error reading Orion cache: $e');
      return null;
    }
  }

  bool isCacheValid(String timestamp) {
    final cacheTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final age = now.difference(cacheTime);
    return age <= cacheDuration;
  }

  Future<bool> hasValidCache(String imdbId) async {
    try {
      final file = File('${PathsConfig.orionDir}/$imdbId.json');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        return isCacheValid(data['timestamp']);
      }
      
      return false;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> clearExpiredCache() async {
    try {
      final directory = Directory(PathsConfig.orionDir);
      if (!await directory.exists()) return;

      await for (final file in directory.list()) {
        if (file is File && file.path.endsWith('.json')) {
          final content = await file.readAsString();
          final data = json.decode(content);
          
          if (!isCacheValid(data['timestamp'])) {
            await file.delete();
            print('Deleted expired cache file: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('Error clearing expired cache: $e');
    }
  }

  Future<DateTime?> getResponseTimestamp(String imdbId) async {
    try {
      final file = File('${PathsConfig.orionDir}/$imdbId.json');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        return DateTime.parse(data['timestamp']);
      }
      
      return null;
    } catch (e) {
      print('Error getting response timestamp: $e');
      return null;
    }
  }
} 