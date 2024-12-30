import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'orion_query_helper.dart';

class OrionQueryMovie {
  static final OrionQueryMovie instance = OrionQueryMovie._internal();
  OrionQueryMovie._internal();

  final String _baseUrl = 'https://api.orionoid.com';
  
  Future<Map<String, dynamic>?> searchMovie(String imdbId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('orion_token');
      
      if (token == null) {
        debugPrint('No Orion auth token found');
        return null;
      }

      debugPrint('Searching Orion for IMDB ID: $imdbId');
      
      final commonParams = await OrionQueryHelper.getMovieQueryParams();
      final Map<String, String> formData = {
        'token': token,
        'mode': 'stream',
        'action': 'retrieve',
        'access': 'premiumize,premiumizetorrent',
        'type': 'movie',
        'idimdb': imdbId,
        'limitcount': '40',
        'streamtype': 'torrent',
        ...commonParams,
      };

      debugPrint('Sending search request to Orion:');
      debugPrint('URL: $_baseUrl');
      debugPrint('Form data: $formData');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formData,
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body:');
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(json.decode(response.body));
      const int chunkSize = 800;
      for (var i = 0; i < prettyJson.length; i += chunkSize) {
        debugPrint(prettyJson.substring(i, i + chunkSize > prettyJson.length ? prettyJson.length : i + chunkSize));
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['result']?['status'] == 'success') {
          debugPrint('Search successful');
          final retrieved = data['data']?['count']?['retrieved'] ?? 0;
          if (retrieved == 0) {
            debugPrint('Search returned no streams');
            return null;
          }
          return data;
        } else {
          debugPrint('Search failed: ${data['result']?['message']}');
          return null;
        }
      } else {
        debugPrint('Search request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error during Orion search:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  bool hasValidStreams(Map<String, dynamic> response) {
    try {
      final streams = response['data']?['streams'];
      return streams != null && streams.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking streams: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> extractStreams(Map<String, dynamic> response) {
    try {
      final List<dynamic> streams = response['data']?['streams'] ?? [];
      return streams.map((stream) => stream as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error extracting streams: $e');
      return [];
    }
  }

  Future<bool> hasValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('orion_token');
    return token != null;
  }
} 