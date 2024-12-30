import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/orion_stream_show.dart';
import '../services/orion_initiate_show.dart';
import '../config/key_bindings.dart';
import '../services/vlc_launcher_service.dart';

class TvShowStreamSelectionScreen extends StatelessWidget {
  final List<OrionStreamShow> streams;

  const TvShowStreamSelectionScreen({
    super.key,
    required this.streams,
  });

  bool _isSelectKey(LogicalKeyboardKey key) {
    return KeyBindings.selectMedia.contains(key);
  }

  Future<void> _handleStreamSelection(BuildContext context, OrionStreamShow stream) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resolving stream...')),
    );

    final result = await OrionInitiateShow.instance.resolveStream(
      stream.orionId,
      stream.id,
    );

    if (result != null) {
      try {
        await VlcLauncherService.instance.launchVlcWithFiles(result);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching VLC: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resolve stream')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Streams'),
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
      ),
      body: FocusScope(
        autofocus: true,
        child: ListView.builder(
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            return Focus(
              autofocus: index == 0,
              canRequestFocus: true,
              onKey: (node, event) {
                if (event is RawKeyDownEvent &&
                    KeyBindings.selectMedia.contains(event.logicalKey)) {
                  _handleStreamSelection(context, stream);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(stream.fileName),
                    subtitle: Text('Size: ${stream.formattedSize} • Quality: ${stream.quality}'),
                    onTap: () => _handleStreamSelection(context, stream),
                    selected: Focus.of(context).hasPrimaryFocus,
                    selectedTileColor: Theme.of(context).focusColor,
                    tileColor: Colors.transparent,
                    hoverColor: Theme.of(context).hoverColor.withOpacity(0.1),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 