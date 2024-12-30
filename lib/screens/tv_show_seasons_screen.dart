import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/tv_show.dart';
import '../services/storage_service.dart';
import '../config/key_bindings.dart';
import './tv_show_episodes_screen.dart';

class TvShowSeasonsScreen extends StatefulWidget {
  final TvShow show;
  final Map<String, dynamic> metadata;

  const TvShowSeasonsScreen({
    super.key,
    required this.show,
    required this.metadata,
  });

  @override
  _TvShowSeasonsScreenState createState() => _TvShowSeasonsScreenState();
}

class _TvShowSeasonsScreenState extends State<TvShowSeasonsScreen> {
  int _focusedIndex = 0;
  final FocusNode _listFocusNode = FocusNode();
  bool _isFocusRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isFocusRequested && widget.metadata['seasons'] != null && widget.metadata['seasons'].isNotEmpty) {
        _listFocusNode.requestFocus();
        _isFocusRequested = true;
        print('Focus requested on first season');
      }
    });
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final posterWidth = screenSize.width * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.metadata['name'] ?? 'TV Show Details'),
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: posterWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 2/3,
                          child: FutureBuilder<File?>(
                            future: StorageService.instance.getPosterFile(widget.show.tmdbId!),
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
                        const SizedBox(height: 16),
                        Text(
                          widget.metadata['name'] ?? 'Unknown Title',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'First Aired: ${widget.metadata['first_air_date'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rating: ${widget.metadata['vote_average']?.toStringAsFixed(1) ?? 'N/A'} / 10',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (widget.metadata['genres'] != null) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (var genre in widget.metadata['genres'])
                                Chip(label: Text(genre['name'])),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: widget.metadata['seasons'] != null
                      ? ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: widget.metadata['seasons'].length,
                          itemBuilder: (context, index) {
                            final season = widget.metadata['seasons'][index];
                            return Focus(
                              focusNode: index == 0 ? _listFocusNode : null,
                              onFocusChange: (hasFocus) {
                                if (hasFocus) {
                                  setState(() {
                                    _focusedIndex = index;
                                  });
                                  print('Focus on season: ${season['name'] ?? 'Season ${season['season_number']}'}');
                                }
                              },
                              onKey: (node, event) {
                                if (event is RawKeyDownEvent &&
                                    KeyBindings.selectMedia.contains(event.logicalKey)) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TvShowEpisodesScreen(
                                        show: widget.show,
                                        metadata: widget.metadata,
                                        season: season,
                                      ),
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: ListTile(
                                selected: _focusedIndex == index,
                                selectedTileColor: Colors.blue.withOpacity(0.3),
                                title: Text(
                                  season['name'] ?? 'Season ${season['season_number']}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                subtitle: Text(
                                  '${season['episode_count']} Episodes',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                onTap: () {
                                  print('Selected season: ${season['season_number']}');
                                },
                              ),
                            );
                          },
                        )
                      : const Center(child: Text('No seasons available')),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.metadata['overview'] ?? 'No overview available',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        if (widget.metadata['credits']?['cast'] != null) ...[
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
                              itemCount: (widget.metadata['credits']['cast'] as List).length,
                              itemBuilder: (context, index) {
                                final actor = widget.metadata['credits']['cast'][index];
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 