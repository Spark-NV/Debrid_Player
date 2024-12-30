import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/movie.dart';
import '../services/storage_service.dart';
import '../services/orion_query_movie.dart';
import '../services/orion_storage_service.dart';
import '../models/orion_stream.dart';
import '../screens/stream_selection_screen.dart';
import '../config/key_bindings.dart';
import '../database/database_helper.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;
  final Map<String, dynamic> metadata;
  final FocusNode _playButtonFocusNode = FocusNode();

  MovieDetailsScreen({
    super.key,
    required this.movie,
    required this.metadata,
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

    print('Play button pressed for movie: ${movie.title}');
    
    final imdbId = await DatabaseHelper.instance.getMovieImdbId(movie.tmdbId!);
    
    if (imdbId == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No IMDB ID available for this movie')),
      );
      return;
    }

    print('Found IMDB ID: $imdbId');

    Map<String, dynamic>? result;
    if (await OrionStorageService.instance.hasValidCache(imdbId)) {
      result = await OrionStorageService.instance.getOrionResponse(imdbId);
      print('Using cached Orion response');
    } else {
      result = await OrionQueryMovie.instance.searchMovie(imdbId);
      if (result != null) {
        await OrionStorageService.instance.saveOrionResponse(imdbId, result);
        print('Saved new Orion response to cache');
      }
    }
    
    Navigator.pop(context);
    
    if (result != null && OrionQueryMovie.instance.hasValidStreams(result)) {
      final List<dynamic> streamData = result['data']?['streams'] ?? [];
      final streams = streamData
          .map((stream) => OrionStream.fromJson({
                ...stream,
                'data': (result)?['data'] ?? {},
              }))
          .toList();

      if (streams.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StreamSelectionScreen(streams: streams),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid streams found')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No streams found for this movie')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('Requesting focus on play button for movie: ${movie.title}');
      _playButtonFocusNode.requestFocus();
    });

    final screenSize = MediaQuery.of(context).size;
    final posterWidth = screenSize.width * 0.2;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(metadata['title'] ?? 'Movie Details'),
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
                            future: StorageService.instance.getPosterFile(movie.tmdbId!),
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
                              metadata['title'] ?? 'Unknown Title',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 1),
                            if (metadata['genres'] != null) ...[
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (var genre in metadata['genres'])
                                    Chip(label: Text(genre['name'])),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (metadata['credits']?['cast'] != null) ...[
                              const Text(
                                'Cast',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: screenSize.height * 0.15,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: (metadata['credits']['cast'] as List).length,
                                  itemBuilder: (context, index) {
                                    final actor = metadata['credits']['cast'][index];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 16.0),
                                      child: Column(
                                        children: [
                                          FutureBuilder<File?>(
                                            future: StorageService.instance.getActorImageFile(actor['id']),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData && snapshot.data != null) {
                                                return CircleAvatar(
                                                  radius: screenSize.height * 0.04,
                                                  backgroundImage: FileImage(snapshot.data!),
                                                );
                                              }
                                              return CircleAvatar(
                                                radius: screenSize.height * 0.04,
                                                child: Text(
                                                  actor['name'][0],
                                                  style: const TextStyle(fontSize: 24),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          Text(actor['name']),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metadata['overview'] ?? 'No overview available',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 1.0),
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
                            return Colors.grey[300]!;
                          }
                          if (states.contains(MaterialState.focused)) {
                            return Colors.blue[400]!;
                          }
                          return Colors.grey[900]!;
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
                          color: Colors.white,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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