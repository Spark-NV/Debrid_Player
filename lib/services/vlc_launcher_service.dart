import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/orion_debrid_file.dart';

class VlcLauncherService {
  static final VlcLauncherService instance = VlcLauncherService._internal();
  VlcLauncherService._internal();

  Future<void> launchVlcWithFiles(Map<String, dynamic> debridResponse) async {
    try {
      final List<dynamic> filesData = debridResponse['data']?['files'] ?? [];
      
      final files = filesData
          .map((file) => OrionDebridFile.fromJson(file['original']))
          .where((file) => file.category != OrionFileCategory.other)
          .toList();

      final videoFile = files.firstWhere(
        (file) => file.category == OrionFileCategory.video,
        orElse: () => throw Exception('No video file found'),
      );

      debugPrint('Launching VLC with URL: ${videoFile.link}');

      final intent = AndroidIntent(
        action: 'action_view',
        data: 'vlc://${videoFile.link}',
        package: 'org.videolan.vlc',
      );
      
      await intent.launch();
      debugPrint('VLC launch successful');
      
    } catch (e) {
      debugPrint('Error launching VLC: $e');
      rethrow;
    }
  }
} 
