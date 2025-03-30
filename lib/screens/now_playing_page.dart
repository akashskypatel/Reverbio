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
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/playback_icon_button.dart';
import 'package:reverbio/widgets/song_artwork.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

final _lyricsController = FlipCardController();

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, required this.navigatorObserver});
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  _NowPlayingPageState createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the RouteObserver
    final route = ModalRoute.of(context);
    if (route != null) {
      widget.navigatorObserver.subscribe(this, route as PageRoute);
    }
  }

  @override
  void dispose() {
    widget.navigatorObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800;
    const adjustedIconSize = 43.0;
    const adjustedMiniIconSize = 20.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_downward),
          splashColor: Colors.transparent,
          onPressed: () {
            GoRouter.of(context).pop(context);
          },
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          if (snapshot.data == null || !snapshot.hasData) {
            return const SizedBox.shrink();
          } else {
            final metadata = snapshot.data!;
            return isLargeScreen
                ? _DesktopLayout(
                  metadata: metadata,
                  size: size,
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                )
                : _MobileLayout(
                  metadata: metadata,
                  size: size,
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                );
          }
        },
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 5),
              NowPlayingArtwork(size: size, metadata: metadata),
              const SizedBox(height: 5),
              if (!(metadata.extras?['isLive'] ?? false))
                NowPlayingControls(
                  context: context,
                  size: size,
                  audioId: metadata.extras?['ytid'],
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                  metadata: metadata,
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        const Expanded(child: QueueListView()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        NowPlayingArtwork(size: size, metadata: metadata),
        const SizedBox(height: 10),
        if (!(metadata.extras?['isLive'] ?? false))
          NowPlayingControls(
            context: context,
            size: size,
            audioId: metadata.extras?['ytid'],
            adjustedIconSize: adjustedIconSize,
            adjustedMiniIconSize: adjustedMiniIconSize,
            metadata: metadata,
          ),
        if (!isLargeScreen) ...[
          const SizedBox(height: 10),
          BottomActionsRow(
            context: context,
            audioId: metadata.extras?['ytid'],
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
          ),
          const SizedBox(height: 35),
        ],
      ],
    );
  }
}

class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
  });
  final Size size;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    const _padding = 50;
    const _radius = 17.0;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    final imageSize =
        isLandscape
            ? screenHeight * 0.40
            : (screenWidth + screenHeight) / 3.35 - _padding;
    const lyricsTextStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );

    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping: !offlineMode.value,
      controller: _lyricsController,
      frontWidget: SongArtworkWidget(
        metadata: metadata,
        size: imageSize,
        errorWidgetIconSize: size.width / 8,
        borderRadius: _radius,
      ),
      backWidget: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: FutureBuilder<String?>(
          future: getSongLyrics(metadata.artist ?? '', metadata.title),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Spinner();
            } else if (snapshot.hasError || snapshot.data == 'not found') {
              return Center(
                child: Text(
                  context.l10n!.lyricsNotAvailable,
                  style: lyricsTextStyle.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    snapshot.data!,
                    style: lyricsTextStyle.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class QueueListView extends StatelessWidget {
  const QueueListView({super.key});

  @override
  Widget build(BuildContext context) {
    final _textColor = Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            context.l10n!.playlist,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: _textColor),
          ),
        ),
        Expanded(
          child:
              activeQueue['list'].isEmpty
                  ? Center(
                    child: Text(
                      context.l10n!.noSongsInQueue,
                      style: TextStyle(color: _textColor),
                    ),
                  )
                  : ListView.builder(
                    itemCount: activeQueue['list'].length,
                    itemBuilder: (context, index) {
                      final borderRadius = getItemBorderRadius(
                        index,
                        activeQueue['list'].length,
                      );
                      return SongBar(
                        activeQueue['list'][index],
                        onPlay: () {
                          //TODO: fix playing new playlist
                          //playPlaylistSong(songIndex: index);
                        },
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: borderRadius,
                        showMusicDuration: true,
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class MarqueeTextWidget extends StatelessWidget {
  const MarqueeTextWidget({
    super.key,
    required this.text,
    required this.fontColor,
    required this.fontSize,
    required this.fontWeight,
  });
  final String text;
  final Color fontColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return MarqueeWidget(
      backDuration: const Duration(seconds: 1),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: fontColor,
        ),
      ),
    );
  }
}

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.context,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });
  final BuildContext context;
  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          SizedBox(
            width: screenWidth * 0.85,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MarqueeTextWidget(
                  text: metadata.title,
                  fontColor: Theme.of(context).colorScheme.primary,
                  fontSize: screenHeight * 0.028,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: 10),
                if (metadata.artist != null)
                  MarqueeTextWidget(
                    text: metadata.artist!,
                    fontColor: Theme.of(context).colorScheme.secondary,
                    fontSize: screenHeight * 0.017,
                    fontWeight: FontWeight.w500,
                  ),
              ],
            ),
          ),
          const Spacer(),
          const PositionSlider(),
          const Spacer(),
          PlayerControlButtons(
            context: context,
            metadata: metadata,
            iconSize: adjustedIconSize,
            miniIconSize: adjustedMiniIconSize,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class PositionSlider extends StatelessWidget {
  const PositionSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ValueListenableBuilder<PositionData>(
        valueListenable: audioHandler.positionDataNotifier,
        builder: (context, positionData, _) {
          final primaryColor = Theme.of(context).colorScheme.primary;
          return Column(
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
              _buildPositionRow(context, primaryColor, positionData),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPositionRow(
    BuildContext context,
    Color fontColor,
    PositionData positionData,
  ) {
    final positionText = formatDuration(positionData.position.inSeconds);
    final durationText = formatDuration(positionData.duration.inSeconds);
    final textStyle = TextStyle(fontSize: 15, color: fontColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(positionText, style: textStyle),
          Text(durationText, style: textStyle),
        ],
      ),
    );
  }
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.context,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final BuildContext context;
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _primaryColor = theme.colorScheme.primary;
    final _secondaryColor = theme.colorScheme.secondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildShuffleButton(_primaryColor, _secondaryColor, miniIconSize),
          Row(
            children: [
              _buildPreviousButton(_primaryColor, _secondaryColor, iconSize),
              const SizedBox(width: 10),
              _buildPlayPauseButton(_primaryColor, _secondaryColor, iconSize),
              const SizedBox(width: 10),
              _buildNextButton(_primaryColor, _secondaryColor, iconSize),
            ],
          ),
          _buildRepeatButton(_primaryColor, _secondaryColor, miniIconSize),
        ],
      ),
    );
  }

  Widget _buildShuffleButton(
    Color primaryColor,
    Color secondaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return value
            ? IconButton.filled(
              icon: Icon(
                FluentIcons.arrow_shuffle_24_filled,
                color: secondaryColor,
              ),
              iconSize: iconSize,
              onPressed: () {
                audioHandler.setShuffleMode(AudioServiceShuffleMode.none);
              },
            )
            : IconButton.filledTonal(
              icon: Icon(
                FluentIcons.arrow_shuffle_off_24_filled,
                color: primaryColor,
              ),
              iconSize: iconSize,
              onPressed: () {
                audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
              },
            );
      },
    );
  }

  Widget _buildPreviousButton(
    Color primaryColor,
    Color secondaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, repeatMode, __) {
        return IconButton(
          icon: Icon(
            FluentIcons.previous_24_filled,
            color: audioHandler.hasPrevious ? primaryColor : secondaryColor,
          ),
          iconSize: iconSize / 1.7,
          onPressed:
              () =>
                  repeatNotifier.value == AudioServiceRepeatMode.one
                      ? audioHandler.playAgain()
                      : audioHandler.skipToPrevious(),
          splashColor: Colors.transparent,
        );
      },
    );
  }

  Widget _buildPlayPauseButton(
    Color primaryColor,
    Color secondaryColor,
    double iconSize,
  ) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        return buildPlaybackIconButton(
          snapshot.data,
          iconSize,
          primaryColor,
          secondaryColor,
          elevation: 0,
          padding: EdgeInsets.all(iconSize * 0.40),
        );
      },
    );
  }

  Widget _buildNextButton(
    Color primaryColor,
    Color secondaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, repeatMode, __) {
        return IconButton(
          icon: Icon(
            FluentIcons.next_24_filled,
            color: audioHandler.hasNext ? primaryColor : secondaryColor,
          ),
          iconSize: iconSize / 1.7,
          onPressed:
              () =>
                  repeatNotifier.value == AudioServiceRepeatMode.one
                      ? audioHandler.playAgain()
                      : audioHandler.skipToNext(),
          splashColor: Colors.transparent,
        );
      },
    );
  }

  Widget _buildRepeatButton(
    Color primaryColor,
    Color secondaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, repeatMode, __) {
        return repeatMode != AudioServiceRepeatMode.none
            ? IconButton.filled(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.all
                    ? FluentIcons.arrow_repeat_all_24_filled
                    : FluentIcons.arrow_repeat_1_24_filled,
                color: secondaryColor,
              ),
              iconSize: iconSize,
              onPressed: () {
                repeatNotifier.value =
                    repeatMode == AudioServiceRepeatMode.all
                        ? AudioServiceRepeatMode.one
                        : AudioServiceRepeatMode.none;

                audioHandler.setRepeatMode(repeatMode);
              },
            )
            : IconButton.filledTonal(
              icon: Icon(
                FluentIcons.arrow_repeat_all_off_24_filled,
                color: primaryColor,
              ),
              iconSize: iconSize,
              onPressed: () {
                final _isSingleSongPlaying = activeQueue['list'].isEmpty;
                repeatNotifier.value =
                    _isSingleSongPlaying
                        ? AudioServiceRepeatMode.one
                        : AudioServiceRepeatMode.all;

                if (repeatNotifier.value == AudioServiceRepeatMode.one)
                  audioHandler.setRepeatMode(repeatNotifier.value);
              },
            );
      },
    );
  }
}

class BottomActionsRow extends StatelessWidget {
  const BottomActionsRow({
    super.key,
    required this.context,
    required this.audioId,
    required this.metadata,
    required this.iconSize,
    required this.isLargeScreen,
  });
  final BuildContext context;
  final dynamic audioId;
  final MediaItem metadata;
  final double iconSize;
  final bool isLargeScreen;

  @override
  Widget build(BuildContext context) {
    final songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(audioId));
    final songOfflineStatus = ValueNotifier<bool>(
      isSongAlreadyOffline(audioId),
    );
    final _primaryColor = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        _buildOfflineButton(songOfflineStatus, _primaryColor),
        if (!offlineMode.value) _buildAddToPlaylistButton(_primaryColor),
        if (activeQueue['list'].isNotEmpty && !isLargeScreen)
          _buildQueueButton(context, _primaryColor),
        if (!offlineMode.value) ...[
          _buildLyricsButton(_primaryColor),
          _buildSleepTimerButton(context, _primaryColor),
          _buildLikeButton(songLikeStatus, _primaryColor),
        ],
      ],
    );
  }

  Widget _buildOfflineButton(ValueNotifier<bool> status, Color primaryColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: status,
      builder: (_, value, __) {
        return IconButton.filledTonal(
          icon: Icon(
            value
                ? FluentIcons.cellular_off_24_regular
                : FluentIcons.cellular_data_1_24_regular,
            color: primaryColor,
          ),
          iconSize: iconSize,
          onPressed: () {
            if (value) {
              removeSongFromOffline(audioId);
            } else {
              makeSongOffline(mediaItemToMap(metadata));
            }
            status.value = !status.value;
          },
        );
      },
    );
  }

  Widget _buildAddToPlaylistButton(Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(Icons.add, color: primaryColor),
      iconSize: iconSize,
      onPressed: () {
        showAddToPlaylistDialog(context, mediaItemToMap(metadata));
      },
    );
  }

  Widget _buildQueueButton(BuildContext context, Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(FluentIcons.apps_list_24_filled, color: primaryColor),
      iconSize: iconSize,
      onPressed: () {
        showCustomBottomSheet(
          context,
          ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: commonListViewBottmomPadding,
            itemCount: activeQueue['list'].length,
            itemBuilder: (BuildContext context, int index) {
              final borderRadius = getItemBorderRadius(
                index,
                activeQueue['list'].length,
              );
              return SongBar(
                activeQueue['list'][index],
                onPlay: () {
                  //TODO: fix playing new playlist
                  //playPlaylistSong(songIndex: index);
                },
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: borderRadius,
                showMusicDuration: true,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLyricsButton(Color primaryColor) {
    return IconButton.filledTonal(
      icon: Icon(FluentIcons.text_32_filled, color: primaryColor),
      iconSize: iconSize,
      onPressed: _lyricsController.flipcard,
    );
  }

  Widget _buildSleepTimerButton(BuildContext context, Color primaryColor) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: sleepTimerNotifier,
      builder: (_, value, __) {
        return IconButton.filledTonal(
          icon: Icon(
            value != null
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
            color: primaryColor,
          ),
          iconSize: iconSize,
          onPressed: () {
            if (value != null) {
              audioHandler.cancelSleepTimer();
              sleepTimerNotifier.value = null;
            } else {
              _showSleepTimerDialog(context);
            }
          },
        );
      },
    );
  }

  Widget _buildLikeButton(ValueNotifier<bool> status, Color primaryColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: status,
      builder: (_, value, __) {
        return IconButton.filledTonal(
          icon: Icon(
            value ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
            color: primaryColor,
          ),
          iconSize: iconSize,
          onPressed: () {
            updateSongLikeStatus(audioId, !status.value);
            status.value = !status.value;
          },
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final duration = sleepTimerNotifier.value ?? Duration.zero;
        var hours = duration.inMinutes ~/ 60;
        var minutes = duration.inMinutes % 60;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.l10n!.setSleepTimer),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n!.selectDuration),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n!.hours),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (hours > 0) {
                                setState(() {
                                  hours--;
                                });
                              }
                            },
                          ),
                          Text('$hours'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                hours++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n!.minutes),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (minutes > 0) {
                                setState(() {
                                  minutes--;
                                });
                              }
                            },
                          ),
                          Text('$minutes'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                minutes++;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => GoRouter.of(context).pop(context),
                  child: Text(context.l10n!.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final duration = Duration(hours: hours, minutes: minutes);
                    if (duration.inSeconds > 0) {
                      audioHandler.setSleepTimer(duration);
                      sleepTimerNotifier.value = Duration(
                        hours: hours,
                        minutes: minutes,
                      );
                      showToast(context, context.l10n!.addedSuccess);
                    }
                    GoRouter.of(context).pop(context);
                  },
                  child: Text(context.l10n!.setTimer),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
