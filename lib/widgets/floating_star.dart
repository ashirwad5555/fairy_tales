import 'package:flutter/material.dart';
import 'dart:math' as math;

class FloatingStar extends StatefulWidget {
  final double size;
  final Duration duration;

  const FloatingStar({
    Key? key,
    this.size = 20,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<FloatingStar> createState() => _FloatingStarState();
}

class _FloatingStarState extends State<FloatingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, math.sin(_controller.value * 2 * math.pi) * 10),
          child: Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: Icon(
              Icons.star,
              color: Colors.yellow.withOpacity(0.6),
              size: widget.size,
            ),
          ),
        );
      },
    );
  }
}
