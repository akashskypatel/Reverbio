/*
 *     Copyright (C) 2025 Akashy Patel
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

import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/screens/now_playing_page.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/playback_icon_button.dart';
import 'package:reverbio/widgets/song_artwork.dart';

const double playerHeight = 120;

class MiniPlayer extends StatefulWidget {
  MiniPlayer({
    super.key,
    required this.metadata,
    required this.closeButton,
    required this.navigatorObserver,
  });
  final MediaItem metadata;
  final Widget closeButton;
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh),
      child: Column(
        children: [
          PositionSlider(
            closeButton: widget.closeButton,
            positionDataNotifier: audioHandler.positionDataNotifier,
          ),
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < 0) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    settings: const RouteSettings(name: 'nowPlaying?'),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return NowPlayingPage(
                        navigatorObserver: widget.navigatorObserver,
                      );
                    },
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      const begin = Offset(0, 1);
                      const end = Offset.zero;

                      final tween = Tween(begin: begin, end: end);
                      final curve = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      );

                      final offsetAnimation = tween.animate(curve);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                );
              }
            },
            onTap:
                () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    settings: const RouteSettings(name: 'nowPlaying?'),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return NowPlayingPage(
                        navigatorObserver: widget.navigatorObserver,
                      );
                    },
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      const begin = Offset(0, 1);
                      const end = Offset.zero;

                      final tween = Tween(begin: begin, end: end);
                      final curve = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      );

                      final offsetAnimation = tween.animate(curve);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _buildArtwork(),
                    _buildMetadata(colorScheme.primary, colorScheme.secondary),
                    Row(
                      children: [
                        _buildPreviousButton(context),
                        if (audioHandler.hasPrevious) const SizedBox(width: 10),
                        StreamBuilder<Duration>(
                          stream: audioHandler.audioPlayer.positionStream,
                          builder: (context, snapshot) {
                            return _buildStopButton(context);
                          },
                        ),
                        const SizedBox(width: 10),
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, snapshot) {
                            return _buildPlayPauseButton(context);
                          },
                        ),
                        if (audioHandler.hasNext) const SizedBox(width: 10),
                        _buildNextButton(context),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    final processingState = audioHandler.audioPlayer.state;
    final isPlaying = audioHandler.audioPlayer.playing;
    final iconDataAndAction = getIconFromState(processingState, isPlaying);
    return IconButton(
      onPressed: iconDataAndAction.onPressed,
      icon: Icon(
        iconDataAndAction.iconData,
        color: Theme.of(context).colorScheme.primary,
        size: 35,
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    final isPlaying = audioHandler.audioPlayer.playing;
    return IconButton(
      onPressed:
          isPlaying || audioHandler.audioPlayer.position.inSeconds > 0
              ? () => audioHandler.seekToStart()
              : null,
      icon: const Icon(FluentIcons.stop_24_filled, size: 35),
      color: Theme.of(context).colorScheme.primary,
      disabledColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }

  Widget _buildNextButton(BuildContext context) {
    if (audioHandler.hasNext)
      return IconButton(
        onPressed: () => audioHandler.skipToNext(),
        icon: Icon(
          FluentIcons.next_24_filled,
          color: Theme.of(context).colorScheme.primary,
          size: 25,
        ),
      );
    else
      return const SizedBox.shrink();
  }

  Widget _buildPreviousButton(BuildContext context) {
    if (audioHandler.hasPrevious)
      return IconButton(
        onPressed: () => audioHandler.skipToPrevious(),
        icon: Icon(
          FluentIcons.previous_24_filled,
          color: Theme.of(context).colorScheme.primary,
          size: 25,
        ),
      );
    else
      return const SizedBox.shrink();
  }

  Widget _buildArtwork() {
    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 7, right: 15),
      child: SongArtworkWidget(
        metadata: widget.metadata,
        size: 55,
        errorWidgetIconSize: 30,
      ),
    );
  }

  Widget _buildMetadata(Color titleColor, Color artistColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: MarqueeWidget(
            manualScrollEnabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.metadata.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.metadata.artist != null)
                  Text(
                    widget.metadata.artist!,
                    style: TextStyle(
                      color: artistColor,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PositionSlider extends StatelessWidget {
  const PositionSlider({
    super.key,
    this.closeButton,
    required this.positionDataNotifier,
  });
  final Widget? closeButton;
  final ValueNotifier<PositionData> positionDataNotifier;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: _buildSlider(context, primaryColor),
    );
  }

  Widget _buildSlider(BuildContext context, Color fontColor) {
    return ValueListenableBuilder(
      valueListenable: positionDataNotifier,
      builder: (context, value, _) {
        return Row(
          children: [
            _buildPositionText(context, fontColor, value),
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Slider(
                    value: value.position.inSeconds.toDouble(),
                    max: max(
                      value.position.inSeconds.toDouble(),
                      value.duration.inSeconds.toDouble(),
                    ),
                    onChanged: (value) {
                      audioHandler.seek(Duration(seconds: value.toInt()));
                    },
                  ),
                ],
              ),
            ),
            _buildDurationText(context, fontColor, value),
            closeButton ?? const SizedBox.shrink(),
          ],
        );
      },
    );
  }

  Widget _buildPositionText(
    BuildContext context,
    Color fontColor,
    PositionData positionData,
  ) {
    final positionText = formatDuration(positionData.position.inSeconds);
    final textStyle = TextStyle(fontSize: 12, color: fontColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(children: [Text(positionText, style: textStyle)]),
    );
  }

  Widget _buildDurationText(
    BuildContext context,
    Color fontColor,
    PositionData positionData,
  ) {
    final durationText = formatDuration(positionData.duration.inSeconds);
    final textStyle = TextStyle(fontSize: 12, color: fontColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [Text(durationText, style: textStyle)],
      ),
    );
  }
}
