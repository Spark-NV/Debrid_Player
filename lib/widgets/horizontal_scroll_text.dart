import 'package:flutter/material.dart';

class HorizontalScrollText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const HorizontalScrollText({
    super.key,
    required this.text,
    this.textStyle,
    this.scrollDuration = const Duration(seconds: 10),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<HorizontalScrollText> createState() => _HorizontalScrollTextState();
}

class _HorizontalScrollTextState extends State<HorizontalScrollText> {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForScroll();
    });
  }

  void _checkForScroll() {
    if (!mounted) return;
    
    if (_scrollController.position.maxScrollExtent > 0) {
      _startScrolling();
    }
  }

  void _startScrolling() async {
    if (!mounted || _isScrolling) return;

    _isScrolling = true;
    while (mounted) {
      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;

      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: widget.scrollDuration,
        curve: Curves.easeInOut,
      );
      if (!mounted) return;

      await Future.delayed(widget.pauseDuration);
      if (!mounted) return;

      await _scrollController.animateTo(
        0,
        duration: widget.scrollDuration,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      child: Text(
        widget.text,
        style: widget.textStyle,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 