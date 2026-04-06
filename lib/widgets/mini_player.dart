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
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/playback_icon_button.dart';
import 'package:reverbio/widgets/spinner.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key, required this.closeButton});
  final Widget closeButton;

  @override
  _MiniPlayerState createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  late ThemeData _theme;
  // R3 fix: Move like status to State field to avoid creating new ValueNotifier on every rebuild
  late final ValueNotifier<bool> _likeStatus;
  // R10 fix: Use ValueNotifier to persist volume slider value across dialog reopens
  late final ValueNotifier<double> _volumeNotifier;

  @override
  void initState() {
    super.initState();
    audioHandler.songValueNotifier.addListener(_songListener);
    // R3 fix: Initialize like status once
    _likeStatus = ValueNotifier<bool>(
      isSongAlreadyLiked(audioHandler.songValueNotifier.value),
    );
    // R10 fix: Initialize volume notifier
    _volumeNotifier = ValueNotifier<double>(audioHandler.volume);
  }

  @override
  void dispose() {
    audioHandler.songValueNotifier.removeListener(_songListener);
    // R3 fix: Dispose like status
    _likeStatus.dispose();
    // R10 fix: Dispose volume notifier
    _volumeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final colorScheme = _theme.colorScheme;

    return GestureDetector(
      onTap: () async {
        // R5/R6 fix: Use GoRouter consistently and reset nowPlayingOpen on navigation failure
        if (!nowPlayingOpen.value) {
          nowPlayingOpen.value = true;
          try {
            await context.push('/nowPlaying');
          } catch (e, stackTrace) {
            // R5 fix: Reset nowPlayingOpen on navigation failure
            nowPlayingOpen.value = false;
            logger.log('Error navigating to now playing page', e, stackTrace);
          }
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
                  onVolumePressed: () => _showVolumeSlider(context),
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
                // R12 fix: Make spacing conditional on reactive values
                ListenableBuilder(
                  listenable: audioHandler.queueSongMaps,
                  builder:
                      (context, _) =>
                          audioHandler.hasPrevious
                              ? const SizedBox(width: 10)
                              : const SizedBox.shrink(),
                ),
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
                  builder: _buildPlayPauseButton,
                ),
                ListenableBuilder(
                  listenable: audioHandler.queueSongMaps,
                  builder:
                      (context, _) =>
                          audioHandler.hasNext
                              ? const SizedBox(width: 10)
                              : const SizedBox.shrink(),
                ),
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
            // R2 fix: Removed dead large-screen branch - this is already large screen controls
            Row(
              children: [
                _buildLikeButton(),
                // R12 fix: Make spacing conditional on reactive values
                ListenableBuilder(
                  listenable: audioHandler.queueSongMaps,
                  builder:
                      (context, _) =>
                          audioHandler.hasPrevious
                              ? const SizedBox(width: 10)
                              : const SizedBox.shrink(),
                ),
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
                  builder: _buildPlayPauseButton,
                ),
                ListenableBuilder(
                  listenable: audioHandler.queueSongMaps,
                  builder:
                      (context, _) =>
                          audioHandler.hasNext
                              ? const SizedBox(width: 10)
                              : const SizedBox.shrink(),
                ),
                _buildNextButton(context),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // R3 fix: Use State field _likeStatus instead of creating new ValueNotifier on every rebuild
  Widget _buildLikeButton() {
    final primaryColor = _theme.colorScheme.primary;
    return ValueListenableBuilder<bool>(
      valueListenable: _likeStatus,
      builder: (context, value, __) {
        final icon = Icon(
          value ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
          color: primaryColor,
          size: 35,
        );
        void onPressed() {
          updateSongLikeStatus(
            audioHandler.songValueNotifier.value,
            !_likeStatus.value,
          );
          _likeStatus.value = !_likeStatus.value;
        }

        return buildIconDataButton(
          icon: IconDataAndAction(iconData: icon, onPressed: onPressed),
          35,
          _theme.colorScheme.primary,
          _theme.colorScheme.surfaceContainerHigh,
          context,
          elevation: 0,
          padding: const EdgeInsets.all(8),
          hoverColor: _theme.colorScheme.primary.withValues(alpha: 0.08),
          // R4 fix: Use correct tooltip for like/unlike
          tooltip: value ? 'Unlike' : 'Like',
        );
      },
    );
  }

  // R11 fix: Scope listener to only update changed fields instead of full rebuild
  void _songListener() {
    if (mounted) {
      // Only update like status, not full rebuild
      _likeStatus.value = isSongAlreadyLiked(
        audioHandler.songValueNotifier.value,
      );
    }
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    AsyncSnapshot<PlaybackState> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting)
      return const SizedBox.square(dimension: 35, child: Spinner());
    if (snapshot.hasError || snapshot.data == null)
      return const SizedBox.square(
        dimension: 35,
        child: Icon(FluentIcons.error_circle_24_filled),
      );
    else {
      return buildIconDataButton(
        playerState: snapshot.data,
        35,
        _theme.colorScheme.primary,
        _theme.colorScheme.surfaceContainerHigh,
        context,
        elevation: 0,
        padding: const EdgeInsets.all(8),
        hoverColor: _theme.colorScheme.primary.withValues(alpha: 0.08),
      );
    }
  }

  Widget _buildStopButton(BuildContext context) {
    final isPlaying = audioHandler.playing;
    return buildIconDataButton(
      icon: IconDataAndAction(
        iconData: Icon(
          FluentIcons.stop_24_filled,
          size: 35,
          color:
              isPlaying || audioHandler.position.inSeconds > 0
                  ? _theme.colorScheme.primary
                  : _theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
        onPressed:
            isPlaying || audioHandler.position.inSeconds > 0
                ? () => audioHandler.seekToStart()
                : null,
      ),
      35,
      _theme.colorScheme.primary,
      _theme.colorScheme.surfaceContainerHigh,
      context,
      elevation: 0,
      padding: const EdgeInsets.all(8),
      hoverColor: _theme.colorScheme.primary.withValues(alpha: 0.08),
      tooltip: context.l10n!.stop,
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return ListenableBuilder(
      listenable: audioHandler.queueSongMaps,
      builder: (context, __) {
        if (audioHandler.hasNext)
          return IconButton(
            onPressed: () async {
              await audioHandler.skipToNext();
            },
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
    return ListenableBuilder(
      listenable: audioHandler.queueSongMaps,
      builder: (context, __) {
        if (audioHandler.hasPrevious)
          return IconButton(
            onPressed: () async {
              await audioHandler.skipToPrevious();
            },
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
        child: ValueListenableBuilder(
          valueListenable: audioHandler.songValueNotifier,
          builder: (context, song, child) {
            if (song == null) return const SizedBox.shrink();
            return BaseCard(
              icon: FluentIcons.music_note_2_24_filled,
              size: 55,
              paddingValue: 0,
              loadingWidget: const Spinner(),
              inputData: song,
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    final titleColor = _theme.colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: audioHandler.songValueNotifier,
      builder: (context, song, child) {
        if (song == null) return const SizedBox.shrink();
        // R7 fix: Check isEmpty
        if (song.isEmpty) return const SizedBox.shrink();
        // R8 fix: Use safe cast instead of unsafe `as List`
        final artistData =
            (song['artist-credit'] ??
                    [song['artist'] ?? context.l10n!.unknown])
                as List? ??
            [];
        int index = 1;
        final artistLabels = artistData.fold<List<Widget>>([], (v, e) {
          v.add(_buildArtistLabel(e is String ? e : e['artist']));
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
                      songTitle(song).nullIfEmpty ?? context.l10n!.unknown,
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
                                .value !=
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
    // R7 fix: Check null before isEmpty
    return GestureDetector(
      onTap:
          artistData == null || artistData is String || artistData.isEmpty
              ? null
              : () async {
                try {
                  await context.push('/artist', extra: artistData);
                } catch (e, stackTrace) {
                  logger.log('Error navigating to artist page', e, stackTrace);
                }
              },
      child: Text(
        artistData is String
            ? artistData
            : artistData['name'] ??
                artistData['artist'] ??
                artistData['title'] ??
                context.l10n!.unknown,
        style: TextStyle(
          color: _theme.colorScheme.secondary,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  void _showVolumeSlider(BuildContext context) {
    // R10 fix: Initialize with current volume
    _volumeNotifier.value = audioHandler.volume;

    showDialog(
      context: context,
      builder: (_) {
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
                              _volumeNotifier.value = 0;
                            });
                            audioHandler.setVolume(_volumeNotifier.value);
                          },
                          icon: const Icon(FluentIcons.speaker_0_24_regular),
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _volumeNotifier,
                          builder: (context, value, _) {
                            return Slider(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              value: value,
                              max: 100,
                              label: '${value.toInt()}',
                              onChanged: (double newValue) {
                                setState(() {
                                  _volumeNotifier.value = newValue;
                                });
                                audioHandler.setVolume(newValue);
                              },
                            );
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
                              _volumeNotifier.value = 100;
                            });
                            audioHandler.setVolume(_volumeNotifier.value);
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
}

class PositionSlider extends StatelessWidget {
  PositionSlider({
    super.key,
    this.closeButton,
    required this.positionDataNotifier,
    this.onVolumePressed,
  });
  final Widget? closeButton;
  final ValueNotifier<PositionData> positionDataNotifier;
  final VoidCallback? onVolumePressed;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: _buildSlider(context, primaryColor, onVolumePressed),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    Color fontColor,
    VoidCallback? onVolumePressed,
  ) {
    return ValueListenableBuilder(
      valueListenable: positionDataNotifier,
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onVolumePressed,
              icon: const Icon(FluentIcons.speaker_2_24_regular),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
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
            const SizedBox(width: 10),
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
}
