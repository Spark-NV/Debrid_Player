import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/tv_show.dart';
import '../services/storage_service.dart';
import '../config/key_bindings.dart';
import 'episode_details_screen.dart';
import '../database/database_helper.dart';

class TvShowEpisodesScreen extends StatefulWidget {
  final TvShow show;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> season;

  const TvShowEpisodesScreen({
    super.key,
    required this.show,
    required this.metadata,
    required this.season,
  });

  @override
  _TvShowEpisodesScreenState createState() => _TvShowEpisodesScreenState();
}

class _TvShowEpisodesScreenState extends State<TvShowEpisodesScreen> {
  int _focusedIndex = 0;
  final FocusNode _listFocusNode = FocusNode();
  bool _isFocusRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isFocusRequested && widget.season['episodes'] != null && widget.season['episodes'].isNotEmpty) {
        _listFocusNode.requestFocus();
        _isFocusRequested = true;
        print('Focus requested on first episode');
      }
    });
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    super.dispose();
  }

 void _showPopoutMenu(dynamic episode) {
  final FocusNode buttonFocusNode = FocusNode();

  Navigator.of(context).popUntil((route) => route is! DialogRoute);

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (BuildContext dialogContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        buttonFocusNode.requestFocus();
      });

      return AlertDialog(
        title: Text('Options for Episode ${episode['episode_number']}'),
        content: FutureBuilder<bool>(
          future: DatabaseHelper.instance.getEpisodeWatchedStatus(
            widget.show.tmdbId!,
            widget.season['season_number'],
            episode['episode_number'],
          ),
          builder: (context, snapshot) {
            final bool isEpisodeWatched = snapshot.data ?? false;

            return SingleChildScrollView(
              child: ListBody(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      focusNode: buttonFocusNode,
                      onHover: (hovering) {
                        print('Hovering: $hovering');
                      },
                      focusColor: Colors.blue.withOpacity(0.3),
                      hoverColor: Colors.blue.withOpacity(0.3),
                      splashColor: Colors.blue.withOpacity(0.5),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();

                        final newWatchedStatus = !isEpisodeWatched;

                        await DatabaseHelper.instance.updateEpisodeWatchedStatus(
                          widget.show.tmdbId!,
                          widget.season['season_number'],
                          episode['episode_number'],
                          newWatchedStatus,
                        );

                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              newWatchedStatus
                                  ? 'Marked Episode ${episode['episode_number']} as watched'
                                  : 'Marked Episode ${episode['episode_number']} as unwatched',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          isEpisodeWatched
                              ? 'Mark as Unwatched'
                              : 'Mark as Watched',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final posterWidth = screenSize.width * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.metadata['name']} - ${widget.season['name']}'),
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        ),
      body: Row(
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
                    widget.metadata['name'] ?? 'Unknown Show',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.season['name'] ?? 'Season ${widget.season['season_number']}',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.season['episode_count']} Episodes',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (widget.season['air_date'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Air Date: ${widget.season['air_date']}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: widget.season['episodes'] != null
                ? ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: widget.season['episodes'].length,
                    itemBuilder: (context, index) {
                      final episode = widget.season['episodes'][index];
                      final episodeNumber = episode['episode_number'];
                      final episodeName = episode['name'];
                      
                      return FutureBuilder<bool>(
                        future: DatabaseHelper.instance.getEpisodeWatchedStatus(
                          widget.show.tmdbId!, 
                          widget.season['season_number'], 
                          episodeNumber
                        ),
                        builder: (context, snapshot) {
                          final bool isWatched = snapshot.data ?? false;
                          
                          return Focus(
                            focusNode: index == 0 ? _listFocusNode : null,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                setState(() {
                                  _focusedIndex = index;
                                });
                                print('Focus on episode: $episodeNumber');
                              }
                            },
                            onKey: (node, event) {
                              if (event is RawKeyDownEvent) {
                                if (KeyBindings.selectMedia.contains(event.logicalKey)) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EpisodeDetailsScreen(
                                        show: widget.show,
                                        episode: episode,
                                      ),
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey == KeyBindings.popoutMenu) {
                                  final episode = widget.season['episodes'][_focusedIndex];
                                  _showPopoutMenu(episode);
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: ListTile(
                              selected: _focusedIndex == index,
                              selectedTileColor: Colors.blue.withOpacity(0.3),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      episodeName != null && episodeName.isNotEmpty
                                          ? 'Episode $episodeNumber: $episodeName'
                                          : 'Episode $episodeNumber',
                                      style: TextStyle(
                                        fontSize: 18,
                                        decoration: isWatched 
                                          ? TextDecoration.none 
                                          : TextDecoration.none,
                                        color: isWatched 
                                          ? Colors.grey 
                                          : null,
                                      ),
                                    ),
                                  ),
                                  if (isWatched) 
                                    Icon(
                                      Icons.check_circle, 
                                      color: Colors.green, 
                                      size: 20,
                                    ),
                                ],
                              ),
                              subtitle: episode['air_date'] != null
                                  ? Text(
                                      'Air Date: ${episode['air_date']}',
                                      style: const TextStyle(color: Colors.grey),
                                    )
                                  : null,
                              onTap: () {
                                print('User tapped episode $episodeNumber');
                              },
                            ),
                          );
                        },
                      );
                    },
                  )
                : const Center(child: Text('No episodes available')),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.season['overview']?.isNotEmpty == true) ...[
                    const Text(
                      'Season Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.season['overview'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 