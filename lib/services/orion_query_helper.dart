import 'package:shared_preferences/shared_preferences.dart';

class OrionQueryHelper {
  static Future<Map<String, String>> getMovieQueryParams() async {
    final prefs = await SharedPreferences.getInstance();
    
    final params = <String, String>{};
    
    final minSize = prefs.getInt('movie_orion_min_filesize') ?? 1000;
    final maxSize = prefs.getInt('movie_orion_max_filesize') ?? 10000;
    params['filesize'] = '${minSize * 1000000}_${maxSize * 1000000}';
    
    if (prefs.getBool('movie_orion_audio_languages') ?? true) {
      params['audiolanguages'] = 'en';
    }
    if (prefs.getBool('movie_orion_subtitle_languages') ?? true) {
      params['subtitlelanguages'] = 'en';
    }
    
    final sortValueIndex = prefs.getInt('movie_orion_sort_value') ?? 2;
    final sortValues = ['best', 'filesize', 'videoquality'];
    params['sortvalue'] = sortValues[sortValueIndex];
    
    return params;
  }

  static Future<Map<String, String>> getTVShowQueryParams() async {
    final prefs = await SharedPreferences.getInstance();
    
    final params = <String, String>{};
    
    final minSize = prefs.getInt('tv_orion_min_filesize') ?? 300;
    final maxSize = prefs.getInt('tv_orion_max_filesize') ?? 4000;
    params['filesize'] = '${minSize * 1000000}_${maxSize * 1000000}';
    
    if (prefs.getBool('tv_orion_audio_languages') ?? true) {
      params['audiolanguages'] = 'en';
    }
    if (prefs.getBool('tv_orion_subtitle_languages') ?? true) {
      params['subtitlelanguages'] = 'en';
    }
    
    final sortValueIndex = prefs.getInt('tv_orion_sort_value') ?? 2;
    final sortValues = ['best', 'filesize', 'videoquality'];
    params['sortvalue'] = sortValues[sortValueIndex];
    
    return params;
  }
} 