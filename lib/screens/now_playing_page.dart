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
import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/models/position_data.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/playback_icon_button.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

final _lyricsController = FlipCardController();

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  _NowPlayingPageState createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  late ThemeData _theme;
  late bool _isLargeScreen;

  @override
  void deactivate() {
    nowPlayingOpen.value = false;
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isLargeScreen = isLargeScreen(context: context);
    final size = MediaQuery.sizeOf(context);
    _theme = Theme.of(context);
    const adjustedIconSize = 43.0;
    final adjustedMiniIconSize = _isLargeScreen ? pageHeaderIconSize : 20.0;
    final songLikeStatus = ValueNotifier<bool>(
      isSongAlreadyLiked(audioHandler.songValueNotifier.value?.song),
    );
    final songOfflineStatus = ValueNotifier<bool>(
      isSongAlreadyOffline(audioHandler.songValueNotifier.value?.song),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(FluentIcons.arrow_left_24_filled),
          iconSize: pageHeaderIconSize,
          splashColor: Colors.transparent,
          onPressed: () {
            nowPlayingOpen.value = !nowPlayingOpen.value;
            GoRouter.of(context).pop();
          },
        ),
        actions: [
          _buildSyncButton(),
          if (_isLargeScreen)
            ..._buildActionList(
              songLikeStatus,
              songOfflineStatus,
              adjustedMiniIconSize,
            ),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, snapshot) {
          if (snapshot.data == null || !snapshot.hasData) {
            return const SizedBox.shrink();
          } else {
            final mediaItem = snapshot.data!;
            return _isLargeScreen
                ? _DesktopLayout(
                  mediaItem: mediaItem,
                  size: size,
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                )
                : _MobileLayout(
                  mediaItem: mediaItem,
                  size: size * .65,
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                  isLargeScreen: _isLargeScreen,
                  actions: _buildActionList(
                    songLikeStatus,
                    songOfflineStatus,
                    adjustedMiniIconSize,
                  ),
                );
          }
        },
      ),
    );
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: () async {},
    );
  }

  List<Widget> _buildActionList(
    ValueNotifier<bool> songLikeStatus,
    ValueNotifier<bool> songOfflineStatus,
    double iconSize,
  ) {
    final _primaryColor = _theme.colorScheme.primary;
    return [
      _buildVolumeButton(_primaryColor, iconSize),
      _buildOfflineButton(songOfflineStatus, _primaryColor, iconSize),
      if (!offlineMode.value)
        _buildAddToPlaylistButton(_primaryColor, iconSize),
      if (audioHandler.queueSongBars.isNotEmpty &&
          !isLargeScreen(context: context))
        _buildQueueButton(context, _primaryColor, iconSize),
      if (!offlineMode.value) ...[
        _buildLyricsButton(_primaryColor, iconSize),
        _buildSleepTimerButton(context, _primaryColor, iconSize),
        _buildLikeButton(songLikeStatus, _primaryColor, iconSize),
      ],
    ];
  }

  Widget _buildVolumeButton(Color primaryColor, double iconSize) {
    final icon = Icon(
      FluentIcons.speaker_2_24_regular,
      size: iconSize,
      color: primaryColor,
    );
    if (_isLargeScreen)
      return IconButton(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        icon: icon,
        iconSize: iconSize,
        onPressed: () => _showVolumeSlider(context),
        tooltip: context.l10n!.volume,
      );
    return IconButton.filledTonal(
      icon: icon,
      iconSize: iconSize,
      onPressed: () => _showVolumeSlider(context),
      tooltip: context.l10n!.volume,
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
                      //width: MediaQuery.of(context).size.width * 0.15,
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

  Widget _buildOfflineButton(
    ValueNotifier<bool> status,
    Color primaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: status,
      builder: (context, value, __) {
        final icon = Icon(
          value
              ? FluentIcons.cellular_off_24_regular
              : FluentIcons.cellular_data_1_24_regular,
          color: primaryColor,
        );
        void onPressed(value) {
          if (value) {
            unawaited(
              removeSongFromOffline(audioHandler.songValueNotifier.value?.song),
            );
          } else {
            makeSongOffline(audioHandler.songValueNotifier.value?.song);
          }
          status.value = !status.value;
        }

        if (_isLargeScreen)
          return IconButton(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: icon,
            iconSize: iconSize,
            onPressed: () => onPressed(value),
            tooltip: context.l10n!.offlineMode,
          );
        return IconButton.filledTonal(
          icon: icon,
          iconSize: iconSize,
          onPressed: () => onPressed(value),
          tooltip: context.l10n!.offlineMode,
        );
      },
    );
  }

  Widget _buildAddToPlaylistButton(Color primaryColor, double iconSize) {
    final icon = Icon(FluentIcons.add_24_filled, color: primaryColor);
    void onPressed() {
      showAddToPlaylistDialog(
        context,
        audioHandler.songValueNotifier.value?.song,
      );
    }

    if (_isLargeScreen)
      return IconButton(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        icon: icon,
        iconSize: iconSize,
        onPressed: onPressed,
        tooltip: context.l10n!.addToPlaylist,
      );
    return IconButton.filledTonal(
      icon: icon,
      iconSize: iconSize,
      onPressed: onPressed,
      tooltip: context.l10n!.addToPlaylist,
    );
  }

  Widget _buildQueueButton(
    BuildContext context,
    Color primaryColor,
    double iconSize,
  ) {
    final icon = Icon(FluentIcons.apps_list_24_filled, color: primaryColor);
    void onPressed() {
      showCustomBottomSheet(
        context,
        ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: commonListViewBottomPadding,
          itemCount: audioHandler.queueSongBars.length,
          itemBuilder: (BuildContext context, int index) {
            return audioHandler.queueSongBars[index];
          },
        ),
      );
    }

    if (_isLargeScreen)
      return IconButton(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        icon: icon,
        iconSize: iconSize,
        onPressed: onPressed,
        tooltip: context.l10n!.queue,
      );
    return IconButton.filledTonal(
      icon: icon,
      iconSize: iconSize,
      onPressed: onPressed,
      tooltip: context.l10n!.queue,
    );
  }

  Widget _buildLyricsButton(Color primaryColor, double iconSize) {
    final icon = Icon(FluentIcons.text_32_filled, color: primaryColor);
    if (_isLargeScreen)
      return IconButton(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        icon: icon,
        iconSize: iconSize,
        onPressed: _lyricsController.flipcard,
        tooltip: context.l10n!.lyrics,
      );
    return IconButton.filledTonal(
      icon: icon,
      iconSize: iconSize,
      onPressed: _lyricsController.flipcard,
      tooltip: context.l10n!.lyrics,
    );
  }

  Widget _buildSleepTimerButton(
    BuildContext context,
    Color primaryColor,
    double iconSize,
  ) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: sleepTimerNotifier,
      builder: (context, value, __) {
        final icon = Icon(
          value != null
              ? FluentIcons.timer_24_filled
              : FluentIcons.timer_24_regular,
          color: primaryColor,
        );
        void onPressed(value) {
          if (value != null) {
            audioHandler.cancelSleepTimer();
            sleepTimerNotifier.value = null;
          } else {
            _showSleepTimerDialog(context);
          }
        }

        if (_isLargeScreen)
          return IconButton(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: icon,
            iconSize: iconSize,
            onPressed: () => onPressed(value),
            tooltip: context.l10n!.setSleepTimer,
          );
        return IconButton.filledTonal(
          icon: icon,
          iconSize: iconSize,
          onPressed: () => onPressed(value),
          tooltip: context.l10n!.setSleepTimer,
        );
      },
    );
  }

  Widget _buildLikeButton(
    ValueNotifier<bool> status,
    Color primaryColor,
    double iconSize,
  ) {
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

        if (_isLargeScreen)
          return IconButton(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon: icon,
            iconSize: iconSize,
            onPressed: onPressed,
            tooltip:
                value
                    ? context.l10n!.removeFromLikedSongs
                    : context.l10n!.addToLikedSongs,
          );
        return IconButton.filledTonal(
          icon: icon,
          iconSize: iconSize,
          onPressed: onPressed,
          tooltip:
              value
                  ? context.l10n!.removeFromLikedSongs
                  : context.l10n!.addToLikedSongs,
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
                            icon: const Icon(FluentIcons.subtract_24_filled),
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
                            icon: const Icon(FluentIcons.add_24_filled),
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
                            icon: const Icon(FluentIcons.subtract_24_filled),
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
                            icon: const Icon(FluentIcons.add_24_filled),
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
                      showToast(context.l10n!.addedSuccess);
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

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.mediaItem,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
  });
  final MediaItem mediaItem;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;

  @override
  Widget build(BuildContext context) {
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    return Row(
      children: [
        Flexible(
          fit: FlexFit.tight,
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              const SizedBox(height: 5),
              NowPlayingArtwork(size: size, mediaItem: mediaItem),
              const SizedBox(height: 5),
              if (!(mediaItem.extras?['isLive'] ?? false))
                NowPlayingControls(
                  context: context,
                  size: size,
                  audioId: mediaItem.extras?['ytid'],
                  adjustedIconSize: adjustedIconSize,
                  adjustedMiniIconSize: adjustedMiniIconSize,
                  mediaItem: mediaItem,
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        if (isLandscape)
          const Flexible(fit: FlexFit.tight, child: QueueListView()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.mediaItem,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.actions,
  });
  final MediaItem mediaItem;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        const SizedBox(height: 10),
        NowPlayingArtwork(size: size, mediaItem: mediaItem),
        const SizedBox(height: 10),
        if (!(mediaItem.extras?['isLive'] ?? false))
          NowPlayingControls(
            context: context,
            size: size,
            audioId: mediaItem.extras?['ytid'],
            adjustedIconSize: adjustedIconSize,
            adjustedMiniIconSize: adjustedMiniIconSize,
            mediaItem: mediaItem,
          ),
        if (!isLargeScreen) ...[
          const SizedBox(height: 10),
          BottomActionsRow(
            context: context,
            audioId: mediaItem.extras?['ytid'],
            mediaItem: mediaItem,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            actions: actions,
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
    required this.mediaItem,
  });
  final Size size;
  final MediaItem mediaItem;

  @override
  Widget build(BuildContext context) {
    const _padding = 50;
    const _radius = 17.0;
    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    final imageSize =
        isLandscape
            ? screenHeight * 0.40
            : (screenWidth + screenHeight) / 4 - _padding;
    const lyricsTextStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
    );
    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping: !offlineMode.value,
      controller: _lyricsController,
      frontWidget: BaseCard(
        icon: FluentIcons.music_note_2_24_filled,
        size: imageSize,
        paddingValue: 0,
        loadingWidget: const Spinner(),
        inputData: audioHandler.songValueNotifier.value?.song,
      ),
      backWidget: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: FutureBuilder<String?>(
          future: getSongLyrics(mediaItem.artist ?? '', mediaItem.title),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Spinner();
            } else if (snapshot.hasError ||
                snapshot.data == 'not found' ||
                snapshot.data == null) {
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
            context.l10n!.queue,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: _textColor),
          ),
        ),
        Flexible(
          fit: FlexFit.tight,
          child:
              audioHandler.queueSongBars.isEmpty
                  ? Center(
                    child: Text(
                      context.l10n!.noSongsInQueue,
                      style: TextStyle(color: _textColor),
                    ),
                  )
                  : ListView(children: audioHandler.queueSongBars),
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

class NowPlayingControls extends StatefulWidget {
  const NowPlayingControls({
    super.key,
    required this.context,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.mediaItem,
  });
  final BuildContext context;
  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem mediaItem;

  @override
  _NowPlayingControlsState createState() => _NowPlayingControlsState();
}

class _NowPlayingControlsState extends State<NowPlayingControls> {
  late ThemeData _theme;
  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final screenWidth = widget.size.width;
    final screenHeight = widget.size.height;
    return ValueListenableBuilder(
      valueListenable: audioHandler.songValueNotifier,
      builder: (context, value, child) {
        final song = audioHandler.songValueNotifier.value!.song;
        final artistData = (song['artist-credit'] ?? [song['artist'] ?? 'unknown']) as List;
        int index = 1;
        final artistLabels = artistData.fold(<Widget>[], (v, e) {
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
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 10,
          children: [
            SizedBox(
              width: screenWidth,
              child: Column(
                children: [
                  MarqueeTextWidget(
                    text: song['mbTitle'] ??
                              song['title'] ??
                              song['ytTitle'] ??
                              'unknown',
                    fontColor: Theme.of(context).colorScheme.primary,
                    fontSize: screenHeight * 0.028,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
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
            const PositionSlider(),
            PlayerControlButtons(
              context: context,
              mediaItem: widget.mediaItem,
              iconSize: widget.adjustedIconSize,
              miniIconSize: widget.adjustedMiniIconSize,
            ),
          ],
        );
      },
    );
  }

  Widget _buildArtistLabel(dynamic artistData) {
    final screenHeight = widget.size.height;
    return GestureDetector(
      onTap: () async {
        try {
          if (!mounted || artistData == null || artistData.isEmpty)
            throw Exception();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ArtistPage(page: '/artist', artistData: artistData),
              settings: RouteSettings(name: '/artist?${artistData is String ? artistData : artistData['id']}'),
            ),
          );
        } catch (_) {}
      },
      child: MarqueeTextWidget(
        text:
            artistData['name'] ??
            artistData['artist'] ??
            artistData['title'] ??
            'unknown',
        fontColor: Theme.of(context).colorScheme.secondary,
        fontSize: screenHeight * 0.025,
        fontWeight: FontWeight.w500,
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
                value: positionData.position.inMilliseconds.toDouble(),
                max: max(
                  positionData.position.inMilliseconds.toDouble(),
                  positionData.duration.inMilliseconds.toDouble(),
                ),
                onChanged: (value) {
                  audioHandler.seek(Duration(milliseconds: value.toInt()));
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
    required this.mediaItem,
    required this.iconSize,
    required this.miniIconSize,
  });
  final BuildContext context;
  final MediaItem mediaItem;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final _primaryColor = theme.colorScheme.primary;
    final _secondaryColor = theme.colorScheme.secondaryContainer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildShuffleButton(
                  _primaryColor,
                  _secondaryColor,
                  miniIconSize,
                ),
                Row(
                  children: [
                    _buildPreviousButton(
                      _primaryColor,
                      _secondaryColor,
                      iconSize,
                    ),
                    const SizedBox(width: 10),
                    _buildPlayPauseButton(
                      _primaryColor,
                      _secondaryColor,
                      iconSize,
                    ),
                    const SizedBox(width: 10),
                    _buildNextButton(_primaryColor, _secondaryColor, iconSize),
                  ],
                ),
                _buildRepeatButton(
                  _primaryColor,
                  _secondaryColor,
                  miniIconSize,
                ),
              ],
            ),
          );
        },
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
      builder: (context, value, __) {
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
              tooltip: context.l10n!.shuffle,
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
              tooltip: context.l10n!.shuffle,
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
      builder: (context, repeatMode, __) {
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
          tooltip: context.l10n!.previous,
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
        return buildIconDataButton(
          playerState: snapshot.data,
          iconSize,
          primaryColor,
          secondaryColor,
          context,
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
      builder: (context, repeatMode, __) {
        return IconButton(
          icon: Icon(
            FluentIcons.next_24_filled,
            color: audioHandler.hasNext ? primaryColor : secondaryColor,
          ),
          iconSize: iconSize / 1.7,
          onPressed:
              repeatNotifier.value == AudioServiceRepeatMode.one
                  ? () async {
                    await audioHandler.playAgain();
                  }
                  : () async {
                    await audioHandler.skipToNext();
                  },
          splashColor: Colors.transparent,
          tooltip: context.l10n!.next,
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
      builder: (context, repeatMode, __) {
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
              tooltip: context.l10n!.repeat,
            )
            : IconButton.filledTonal(
              icon: Icon(
                FluentIcons.arrow_repeat_all_off_24_filled,
                color: primaryColor,
              ),
              iconSize: iconSize,
              onPressed: () {
                final _isSingleSongPlaying = audioHandler.queueSongBars.isEmpty;
                repeatNotifier.value =
                    _isSingleSongPlaying
                        ? AudioServiceRepeatMode.one
                        : AudioServiceRepeatMode.all;

                if (repeatNotifier.value == AudioServiceRepeatMode.one)
                  audioHandler.setRepeatMode(repeatNotifier.value);
              },
              tooltip: context.l10n!.repeat,
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
    required this.mediaItem,
    required this.iconSize,
    required this.isLargeScreen,
    required this.actions,
  });
  final BuildContext context;
  final dynamic audioId;
  final MediaItem mediaItem;
  final double iconSize;
  final bool isLargeScreen;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    return Wrap(alignment: WrapAlignment.center, spacing: 8, children: actions);
  }
}
