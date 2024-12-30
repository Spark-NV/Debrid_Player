import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/tv_show.dart';
import '../services/storage_service.dart';
import '../services/orion_query_show.dart';
import '../services/orion_storage_service.dart';
import '../config/key_bindings.dart';
import '../models/orion_stream.dart';
import 'tv_show_stream_selection_screen.dart';
import '../database/database_helper.dart';
import '../models/orion_stream_show.dart';

class EpisodeDetailsScreen extends StatelessWidget {
  final TvShow show;
  final Map<String, dynamic> episode;
  final FocusNode _playButtonFocusNode = FocusNode();

  EpisodeDetailsScreen({
    super.key,
    required this.show,
    required this.episode,
  });

  Future<void> _handlePlayButton(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    debugPrint('Play button pressed for episode: ${episode['name']}');
    debugPrint('Show TMDB ID: ${show.tmdbId}');
    
    final imdbId = await DatabaseHelper.instance.getTvShowImdbId(show.tmdbId!);
    
    if (imdbId == null) {
      Navigator.pop(context);
      debugPrint('No IMDB ID found in database for TMDB ID: ${show.tmdbId}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No IMDB ID available for this show')),
      );
      return;
    }

    debugPrint('Found IMDB ID: $imdbId');
    final seasonNumber = episode['season_number'];
    final episodeNumber = episode['episode_number'];
    
    print('Found IMDB ID: $imdbId, Season: $seasonNumber, Episode: $episodeNumber');

    final cacheKey = '${imdbId}_s${seasonNumber}e${episodeNumber}';
    Map<String, dynamic>? result;
    
    if (await OrionStorageService.instance.hasValidCache(cacheKey)) {
      result = await OrionStorageService.instance.getOrionResponse(cacheKey);
      print('Using cached Orion response');
    } else {
      result = await OrionQueryShow.instance.searchShow(imdbId, seasonNumber, episodeNumber);
      if (result != null) {
        await OrionStorageService.instance.saveOrionResponse(cacheKey, result);
        print('Saved new Orion response to cache');
      }
    }
    
    Navigator.pop(context);
    
    if (result != null && OrionQueryShow.instance.hasValidStreams(result)) {
      final List<dynamic> streamData = result['data']?['streams'] ?? [];
      final streams = streamData
          .map((stream) => OrionStreamShow.fromJson({
                ...stream,
                'data': (result)?['data'] ?? {},
              }))
          .toList();

      if (streams.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TvShowStreamSelectionScreen(streams: streams),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid streams found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No streams found for this episode')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playButtonFocusNode.requestFocus();
    });

    final screenSize = MediaQuery.of(context).size;
    final posterWidth = screenSize.width * 0.2;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        title: Text(episode['name'] ?? 'Episode Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: posterWidth,
                        child: AspectRatio(
                          aspectRatio: 2/3,
                          child: FutureBuilder<File?>(
                            future: StorageService.instance.getPosterFile(show.tmdbId!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.file(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode['name'] ?? 'Unknown Episode',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Air Date: ${episode['air_date'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Episode Number: ${episode['episode_number'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Season: ${episode['season_number'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    episode['overview'] ?? 'No overview available',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                top: BorderSide(
                  color: Colors.grey[800]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    focusNode: _playButtonFocusNode,
                    onPressed: () => _handlePlayButton(context),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.hovered)) {
                            return Colors.blue[300]!;
                          }
                          if (states.contains(MaterialState.focused)) {
                            return Colors.green[400]!;
                          }
                          return Colors.blue;
                        },
                      ),
                      elevation: MaterialStateProperty.resolveWith<double>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.hovered)) {
                            return 8.0;
                          }
                          return 2.0;
                        },
                      ),
                      padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      overlayColor: MaterialStateProperty.all(
                        Colors.white.withOpacity(0.2),
                      ),
                      side: MaterialStateProperty.resolveWith<BorderSide>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.focused)) {
                            return const BorderSide(color: Colors.white, width: 2);
                          }
                          return BorderSide.none;
                        },
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'PLAY',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 