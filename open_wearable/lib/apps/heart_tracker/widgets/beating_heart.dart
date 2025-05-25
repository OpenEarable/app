import 'package:flutter/material.dart';

class BeatingHeart extends StatefulWidget {
  final double bpm; // beats per minute
  final double scale; // max scale factor
  final Widget? child;

  const BeatingHeart({
    super.key,
    required this.bpm,
    this.scale = 1.2,
    this.child,
  });

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant BeatingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _controller.dispose();
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    final beatDuration = Duration(milliseconds: (60000 / widget.bpm).round());

    _controller = AnimationController(
      vsync: this,
      duration: beatDuration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child ??
          Icon(
            Icons.favorite,
            color: Colors.red,
            size: 96,
          ),
    );
  }
}
