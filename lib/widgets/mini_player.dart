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

import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/screens/now_playing_page.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/playback_icon_button.dart';
import 'package:reverbio/widgets/spinner.dart';

const double playerHeight = 120;

class MiniPlayer extends StatefulWidget {
  MiniPlayer({
    super.key,
    required this.context,
    required this.mediaItem,
    required this.closeButton,
  });
  final MediaItem mediaItem;
  final Widget closeButton;
  final BuildContext context;

  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late ThemeData _theme;
  @override
  void initState() {
    super.initState();
    audioHandler.songValueNotifier.addListener(_songListener);
  }

  @override
  void dispose() {
    super.dispose();
    audioHandler.songValueNotifier.removeListener(_songListener);
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final colorScheme = _theme.colorScheme;

    return GestureDetector(
      onTap: () async {
        if (!nowPlayingOpen.value) {
          nowPlayingOpen.value = !nowPlayingOpen.value;
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (context) => const NowPlayingPage()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh),
        child: ClipRRect(
          child: Column(
            children: [
              if (!nowPlayingOpen.value)
                PositionSlider(
                  closeButton: widget.closeButton,
                  positionDataNotifier: audioHandler.positionDataNotifier,
                ),
              if (!nowPlayingOpen.value)
                if (isLargeScreen(context: context))
                  _buildLargeScreenControls(),
              if (!nowPlayingOpen.value)
                if (!isLargeScreen(context: context))
                  _buildSmallScreenControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeScreenControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _buildArtwork(),
            _buildMetadata(),
            Row(
              children: [
                _buildLikeButton(),
                _buildPreviousButton(context),
                if (audioHandler.hasPrevious) const SizedBox(width: 10),
                StreamBuilder<Duration>(
                  stream: audioHandler.positionStream,
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
    );
  }

  Widget _buildSmallScreenControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _buildArtwork(),
            _buildMetadata(),
            Row(
              children: [
                if (isLargeScreen(context: context)) ...[
                  _buildLikeButton(),
                  _buildPreviousButton(context),
                  if (audioHandler.hasPrevious) const SizedBox(width: 10),
                  StreamBuilder<Duration>(
                    stream: audioHandler.positionStream,
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
                ] else ...[
                  _buildLikeButton(),
                  const SizedBox(width: 10),
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, snapshot) {
                      return _buildPlayPauseButton(context);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLikeButton() {
    final status = ValueNotifier<bool>(
      isSongAlreadyLiked(audioHandler.songValueNotifier.value?.song),
    );
    final primaryColor = _theme.colorScheme.primary;
    return ValueListenableBuilder<bool>(
      valueListenable: status,
      builder: (context, value, __) {
        final icon = Icon(
          value ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
          color: primaryColor,
        );
        void onPressed() {
          updateSongLikeStatus(
            audioHandler.songValueNotifier.value?.song,
            !status.value,
          );
          status.value = !status.value;
        }

        return IconButton(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon: icon,
          iconSize: 35,
          onPressed: onPressed,
        );
      },
    );
  }

  void _songListener() {
    if (mounted) setState(() {});
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    final processingState = audioHandler.state;
    final isPlaying = audioHandler.playing;
    final iconDataAndAction = getIconFromProcessingState(
      processingState,
      isPlaying,
    );
    return IconButton(
      onPressed: iconDataAndAction.onPressed,
      icon: Icon(
        iconDataAndAction.iconData,
        color: _theme.colorScheme.primary,
        size: 35,
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    final isPlaying = audioHandler.playing;
    return IconButton(
      onPressed:
          isPlaying || audioHandler.position.inSeconds > 0
              ? () => audioHandler.seekToStart()
              : null,
      icon: const Icon(FluentIcons.stop_24_filled, size: 35),
      color: _theme.colorScheme.primary,
      disabledColor: _theme.colorScheme.secondaryContainer,
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: activeQueueLength,
      builder: (context, value, __) {
        if (audioHandler.hasNext)
          return IconButton(
            onPressed: () => audioHandler.skipToNext(),
            icon: Icon(
              FluentIcons.next_24_filled,
              color: _theme.colorScheme.primary,
              size: 25,
            ),
          );
        else
          return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPreviousButton(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: activeQueueLength,
      builder: (context, value, __) {
        if (audioHandler.hasPrevious)
          return IconButton(
            onPressed: () => audioHandler.skipToPrevious(),
            icon: Icon(
              FluentIcons.previous_24_filled,
              color: _theme.colorScheme.primary,
              size: 25,
            ),
          );
        else
          return const SizedBox.shrink();
      },
    );
  }

  Widget _buildArtwork() {
    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 7, right: 15),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 55, maxWidth: 55),
        child: BaseCard(
          icon: FluentIcons.music_note_2_24_filled,
          size: 55,
          paddingValue: 0,
          loadingWidget: const Spinner(),
          inputData: audioHandler.songValueNotifier.value?.song,
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    final titleColor = _theme.colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: audioHandler.songValueNotifier,
      builder: (context, value, child) {
        final song = audioHandler.songValueNotifier.value!.song;
        final artistData = (song['artist-credit'] ?? []) as List;
        int index = 1;
        final artistLabels = artistData.fold(<Widget>[], (v, e) {
          v.add(_buildArtistLabel(e['artist']));
          if (index != artistData.length)
            v.add(
              Text(
                ', ',
                style: TextStyle(
                  color: _theme.colorScheme.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            );
          index++;
          return v;
        });
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
                      audioHandler.songValueNotifier.value?.song['title'],
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        if (audioHandler
                                .audioPlayer
                                .songValueNotifier
                                .value
                                ?.song !=
                            null)
                          ...artistLabels,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistLabel(dynamic artistData) {
    return GestureDetector(
      onTap: () async {
        try {
          if (!mounted || artistData == null || artistData.isEmpty)
            throw Exception();
          await widget.context.push('/artist', extra: artistData);
        } catch (_) {}
      },
      child: Text(
        artistData['name'] ?? artistData['artist'] ?? artistData['title'] ?? '',
        style: TextStyle(
          color: _theme.colorScheme.secondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showVolumeSlider(context),
              icon: const Icon(FluentIcons.speaker_2_24_regular),
              color: Theme.of(context).colorScheme.primary,
            ),
            _buildPositionText(context, fontColor, value),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Slider(
                    value: value.position.inMilliseconds.toDouble(),
                    max: max(
                      value.position.inMilliseconds.toDouble(),
                      value.duration.inMilliseconds.toDouble(),
                    ),
                    onChanged: (value) {
                      audioHandler.seek(Duration(milliseconds: value.toInt()));
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
        mainAxisSize: MainAxisSize.min,
        children: [Text(durationText, style: textStyle)],
      ),
    );
  }

  void _showVolumeSlider(BuildContext context) => showDialog(
    context: context,
    builder: (_) {
      int _duelCommandment = audioHandler.volume.toInt();
      return StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return RotatedBox(
            quarterTurns: -1,
            child: AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 1,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          setState(() {
                            _duelCommandment = 0;
                          });
                          audioHandler.setVolume(_duelCommandment.toDouble());
                        },
                        icon: const Icon(FluentIcons.speaker_0_24_regular),
                      ),
                    ),
                    Expanded(
                      //width: MediaQuery.of(context).size.width * 0.25,
                      child: Slider(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        value: _duelCommandment.toDouble(),
                        max: 100,
                        label: '$_duelCommandment',
                        onChanged: (double newValue) {
                          setState(() {
                            _duelCommandment = newValue.round();
                          });
                          audioHandler.setVolume(_duelCommandment.toDouble());
                        },
                      ),
                    ),
                    RotatedBox(
                      quarterTurns: 1,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          setState(() {
                            _duelCommandment = 100;
                          });
                          audioHandler.setVolume(_duelCommandment.toDouble());
                        },
                        icon: const Icon(FluentIcons.speaker_2_24_regular),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
