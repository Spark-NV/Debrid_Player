import 'package:flutter/material.dart';
import 'dart:async';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle textStyle;

  const AutoScrollText({
    super.key,
    required this.text,
    required this.textStyle,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  late ScrollController _scrollController;
  Timer? _timer;
  bool _isScrolling = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrollingIfNeeded();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrollingIfNeeded() {
    if (!mounted) return;
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted || !_isScrolling || !_scrollController.hasClients) return;

      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentPosition = _scrollController.offset;

      if (maxScroll <= 0) return;

      if (currentPosition >= maxScroll) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(currentPosition + 0.5);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isScrolling = false),
      onExit: (_) => setState(() {
        _isScrolling = true;
        _startScrollingIfNeeded();
      }),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            widget.text,
            style: widget.textStyle,
          ),
        ),
      ),
    );
  }
} 