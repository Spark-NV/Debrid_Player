import 'package:flutter/material.dart';
import 'movies_screen.dart';
import 'tv_shows_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'simkl_screen.dart';
import 'package:flutter/services.dart';
import 'package:simkl/config/key_bindings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
          Center(
            child: FocusTraversalGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMenuButton(context, 'Movies', Icons.movie, const MoviesScreen()),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'TV Shows', Icons.tv, const TVShowsScreen()),
                  const SizedBox(height: 20),
                  _buildMenuButton(context, 'Search', Icons.search, const SearchScreen()),
                  const SizedBox(height: 20),
                  _buildMenuButton(
                    context, 
                    'Get New Movies', 
                    Icons.arrow_circle_down, 
                    const SimklScreen(),
                    focusNode: FocusNode(
                      onKey: (node, event) {
                        if (event is RawKeyDownEvent && 
                            event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 40,
            child: _buildIconButton(
              context,
              Icons.settings,
              const SettingsScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, 
    String title, 
    IconData icon, 
    Widget screen, 
    {FocusNode? focusNode}
  ) {
    return Focus(
      focusNode: focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (KeyBindings.selectMedia.contains(event.logicalKey)) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
            return KeyEventResult.handled;
          }
          if (focusNode != null && 
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return Transform.scale(
            scale: isFocused ? 1.5 : 1.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFocused ? Colors.blue : Colors.blueGrey[800],
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 10,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => screen),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 30, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    IconData icon,
    Widget screen,
  ) {
    return Focus(
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (KeyBindings.selectMedia.contains(event.logicalKey)) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return Transform.scale(
            scale: isFocused ? 1.2 : 1.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFocused ? Colors.blue : Colors.blueGrey[800],
                padding: const EdgeInsets.all(12),
                shape: const CircleBorder(),
                elevation: 10,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => screen),
                );
              },
              child: Icon(icon, size: 24, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
} 