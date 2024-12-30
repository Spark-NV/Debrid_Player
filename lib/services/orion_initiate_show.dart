import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class OrionInitiateShow {
  static final OrionInitiateShow instance = OrionInitiateShow._internal();
  OrionInitiateShow._internal();

  final String _baseUrl = 'https://api.orionoid.com';
  
  Future<Map<String, dynamic>?> resolveStream(String orionId, String streamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('orion_token');
      
      if (token == null) {
        debugPrint('No Orion auth token found');
        return null;
      }

      debugPrint('Resolving stream with Orion ID: $orionId, Stream ID: $streamId');
      
      final Map<String, String> formData = {
        'token': token,
        'mode': 'debrid',
        'action': 'resolve',
        'type': 'premiumize',
        'iditem': orionId,
        'idstream': streamId,
        'file': 'original',
      };

      debugPrint('Sending resolve request to Orion:');
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
          debugPrint('Stream resolution successful');
          if (data['data']?['show'] != null) {
            return {'data': data['data']['show']};
          }
          return data;
        } else {
          debugPrint('Stream resolution failed: ${data['result']?['message']}');
          return null;
        }
      } else {
        debugPrint('Stream resolution request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error during stream resolution:');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
} 