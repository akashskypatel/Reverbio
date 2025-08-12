/*
 *     Copyright (C) 2025 Akash Patel
 *
 *     Reverbio is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Reverbio is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

import 'package:flutter/material.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';

class AnimatedHeart {
  static void show({
    required BuildContext context,
    required TapDownDetails details,
    required bool like,
    Duration duration = const Duration(milliseconds: 1000),
  }) {
    // Create an OverlayEntry
    final overlayEntry = OverlayEntry(
      builder:
          (context) => _AnimatedHeartOverlay(
            details: details,
            like: like,
            duration: duration,
          ),
    );

    // Insert into overlay
    Overlay.of(context).insert(overlayEntry);

    // Remove after animation completes
    Future.delayed(duration, overlayEntry.remove);
  }
}

class _AnimatedHeartOverlay extends StatefulWidget {
  const _AnimatedHeartOverlay({
    required this.details,
    required this.like,
    required this.duration,
  });

  final TapDownDetails details;
  final bool like;
  final Duration duration;

  @override
  State<_AnimatedHeartOverlay> createState() => _AnimatedHeartOverlayState();
}

class _AnimatedHeartOverlayState extends State<_AnimatedHeartOverlay>
    with TickerProviderStateMixin {
  late ThemeData _theme;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: Duration(microseconds: widget.duration.inMicroseconds ~/ 2),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.ease,
    );

    _scaleController = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.ease,
    );

    // Auto-remove after animation completes
    _scaleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _fadeController.dispose();
        _scaleController.dispose();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Positioned(
      left:
          widget.details.globalPosition.dx -
          20 -
          (isLargeScreen() ? navigationRailWidth : 0), // Center the icon
      top: widget.details.globalPosition.dy - 20,
      child: IgnorePointer(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Icon(
              widget.like ? Icons.favorite : Icons.heart_broken,
              size: 40,
              color: _theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
