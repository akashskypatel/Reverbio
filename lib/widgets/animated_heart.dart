import 'package:flutter/material.dart';

class AnimatedHeart extends StatefulWidget {
  AnimatedHeart({required this.like, required this.position, super.key});

  final Offset position;
  final bool like;
  static const duration = Duration(milliseconds: 1000);
  @override
  State<AnimatedHeart> createState() => _AnimatedHeartState();
}

/// [AnimationController]s can be created with `vsync: this` because of
/// [TickerProviderStateMixin].
class _AnimatedHeartState extends State<AnimatedHeart>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController = AnimationController(
    duration: Duration(
      microseconds: AnimatedHeart.duration.inMicroseconds ~/ 2,
    ),
    vsync: this,
  )..repeat(reverse: true);
  late final CurvedAnimation _fadeAnimation = CurvedAnimation(
    parent: _fadeController,
    curve: Curves.ease,
  );
  late final AnimationController _scaleController = AnimationController(
    duration: AnimatedHeart.duration,
    vsync: this,
  )..repeat();
  late final CurvedAnimation _scaleAnimation = CurvedAnimation(
    parent: _scaleController,
    curve: Curves.ease,
  );

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _fadeAnimation.dispose();
    _scaleAnimation.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - (40 / 2),
      top: widget.position.dy - (40 / 2),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipOval(
            child: Icon(
              widget.like ? Icons.favorite : Icons.heart_broken,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startTimer() async {
    await Future.delayed(AnimatedHeart.duration);
  }
}
