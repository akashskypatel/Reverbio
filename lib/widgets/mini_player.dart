/*
 *     Copyright (C) 2025 Valeri Gokadze
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
 *     please visit: https://github.com/gokadzev/Reverbio
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

const double playerHeight = 117;

class MiniPlayer extends StatelessWidget {
  MiniPlayer({super.key, required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < 0) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return const NowPlayingPage();
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

                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
        }
      },
      onTap:
          () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return const NowPlayingPage();
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

                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        height: playerHeight,
        decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PositionSlider(),
            Row(
              children: <Widget>[
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
    if (isPlaying || audioHandler.audioPlayer.position.inSeconds > 0)
      return IconButton(
        onPressed: () => audioHandler.stop(),
        icon: Icon(
          FluentIcons.stop_24_filled,
          color: Theme.of(context).colorScheme.primary,
          size: 35,
        ),
      );
    else
      return IconButton(
        onPressed: null,
        icon: Icon(
          FluentIcons.stop_24_filled,
          color: Theme.of(context).colorScheme.secondaryContainer,
          size: 35,
        ),
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
        metadata: metadata,
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
                  metadata.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (metadata.artist != null)
                  Text(
                    metadata.artist!,
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
  const PositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: StreamBuilder<PositionData>(
        stream: audioHandler.positionDataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const SizedBox.shrink();
          }
          final positionData = snapshot.data!;
          final primaryColor = Theme.of(context).colorScheme.primary;
          return _buildSlider(context, primaryColor, positionData);
        },
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    Color fontColor,
    PositionData positionData,
  ) {
    return Row(
      children: [
        _buildPositionText(context, fontColor, positionData),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Slider(
                value: positionData.position.inSeconds.toDouble(),
                max: max(
                  positionData.position.inSeconds.toDouble(),
                  positionData.duration.inSeconds.toDouble(),
                ),
                onChanged: (value) {
                  audioHandler.seek(Duration(seconds: value.toInt()));
                },
              ),
            ],
          ),
        ),
        _buildDurationText(context, fontColor, positionData),
      ],
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
