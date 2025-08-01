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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/router_service.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongBar extends StatefulWidget {
  SongBar(
    this.song, {
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onPlay,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final dynamic song;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final VoidCallback? onPlay;
  final bool showMusicDuration;
  final BorderRadius borderRadius;
  final ValueNotifier<bool> _isErrorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPreparedNotifier = ValueNotifier(false);
  final ValueNotifier<MediaItem?> _mediaItemNotifier = ValueNotifier(null);
  late final ValueNotifier<BorderRadius> _borderRadiusNotifier = ValueNotifier(
    this.borderRadius,
  );
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();

  bool get isError => _isErrorNotifier.value;
  bool get isLoading => _isLoadingNotifier.value;
  bool get isPrimed => _isPreparedNotifier.value;
  Stream<MediaItem> get mediaItemStream => _mediaItemStreamController.stream;
  MediaItem get mediaItem => _mediaItemNotifier.value ?? mapToMediaItem(song);
  final FutureTracker<bool> _songFutureTracker = FutureTracker();

  @override
  _SongBarState createState() => _SongBarState();

  ///Returns false if song cannot play
  Future<bool> queueSong({bool play = false}) async {
    try {
      await PM.triggerHook(song, 'onQueueSong');
      _isLoadingNotifier.value = true;
      if (!isPrimed) unawaited(prepareSong());
      if (play) await _songFutureTracker.completer!.future;
      if (!isError) await audioHandler.queueSong(songBar: this, play: play);
      _isLoadingNotifier.value = false;
      _isErrorNotifier.value = isError;
    } catch (e, stackTrace) {
      _isLoadingNotifier.value = false;
      _isErrorNotifier.value = true;
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    if (isError) {
      final context = NavigationManager().context;
      showToast(context.l10n!.errorCouldNotFindAStream);
    }
    return !isError;
  }

  Future<bool> _prepareSong() async {
    _isLoadingNotifier.value = true;
    if (!isPrimed) await getSongUrl(song);
    _updateMediaItem(mapToMediaItem(song));
    _isPreparedNotifier.value = true;
    _isErrorNotifier.value =
        song.containsKey('isError') ? song['isError'] : false;
    _isLoadingNotifier.value = false;
    return !isError;
  }

  Future<void> prepareSong({bool shouldWait = false}) async {
    if (shouldWait)
      await _songFutureTracker.runFuture(_prepareSong());
    else
      unawaited(_songFutureTracker.runFuture(_prepareSong()));
  }

  void setBorder({BorderRadius borderRadius = BorderRadius.zero}) {
    _borderRadiusNotifier.value = borderRadius;
  }

  bool equals(SongBar other) {
    return checkSong(song, other.song);
  }

  void _updateMediaItem(MediaItem mediaItem) {
    _mediaItemStreamController.add(mediaItem);
    _mediaItemNotifier.value = mediaItem;
  }
}

class _SongBarState extends State<SongBar> {
  late ThemeData _theme;
  Future<dynamic>? _songMetadataFuture;
  dynamic loadedSong = false;

  TapDownDetails? doubleTapdetails;

  late final songLikeStatus = ValueNotifier<bool>(
    isSongAlreadyLiked(widget.song),
  );
  late final songOfflineStatus = ValueNotifier<bool>(
    isSongAlreadyOffline(widget.song),
  );
  final ValueNotifier<bool> isLikedAnimationPlaying = ValueNotifier(false);

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  @override
  void initState() {
    super.initState();
    final ids = Uri.parse('?${parseEntityId(widget.song)}').queryParameters;
    if ((ids['mb'] == null || widget.song['mbid'] == null) &&
        _songMetadataFuture == null) {
      //TODO: streamline
      widget.song['primary-type'] = widget.song['primary-type'] ?? 'song';
      _songMetadataFuture =
          widget.song['primary-type'].toLowerCase() != 'single'
              ? findMBSong(widget.song)
              : getSinglesDetails(widget.song);
      unawaited(
        _songMetadataFuture!.whenComplete(() {
          if (mounted)
            setState(() {
              widget._updateMediaItem(mapToMediaItem(widget.song));
            });
        }),
      );
    }
    widget._updateMediaItem(mapToMediaItem(widget.song));
  }

  @override
  void dispose() {
    _songMetadataFuture?.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    return Stack(
      children: [
        Padding(
          padding: commonBarPadding,
          //TODO: add left/right sliding action to add song to queue or to offline
          child: GestureDetector(
            onDoubleTapDown: (details) {
              doubleTapdetails = details;
              likeItem();
            },
            onSecondaryTapDown: (details) {
              _showContextMenu(context, details);
            },
            onTap:
                widget.onPlay ??
                () async {
                  await widget.queueSong(play: true);
                },
            child: Card(
              color: widget.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: widget._borderRadiusNotifier.value,
              ),
              margin: const EdgeInsets.only(bottom: 3),
              child: Padding(
                padding: commonBarContentPadding,
                child: Row(
                  children: [
                    _buildAlbumArt(primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.song['title'],
                            overflow: TextOverflow.ellipsis,
                            style: commonBarTitleStyle.copyWith(
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            combineArtists(widget.song) ??
                                widget.song['artist'] ??
                                '',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: _theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: widget._isLoadingNotifier,
                            builder: (context, value, _) {
                              if (value)
                                return _buildLoadingSpinner(context);
                              else
                                return const SizedBox.shrink();
                            },
                          ),
                          ValueListenableBuilder(
                            valueListenable: widget._isErrorNotifier,
                            builder: (context, value, _) {
                              if (value)
                                return _buildErrorIconWidget(context);
                              else
                                return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildActionButtons(context, primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: isLikedAnimationPlaying,
          builder:
              (context, value, __) =>
                  isLikedAnimationPlaying.value && doubleTapdetails != null
                      ? AnimatedHeart(
                        like: songLikeStatus.value,
                        position: doubleTapdetails!.localPosition,
                      )
                      : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildLoadingSpinner(BuildContext context) {
    return Tooltip(
      message: context.l10n!.loading,
      child: const SizedBox(width: 24, height: 24, child: Spinner()),
    );
  }

  Widget _buildErrorIconWidget(BuildContext context) {
    return Tooltip(
      message: context.l10n!.errorCouldNotFindAStream,
      child: Icon(
        FluentIcons.error_circle_24_filled,
        color: _theme.colorScheme.primary,
      ),
    );
  }

  void likeItem() {
    final isLiked = isSongAlreadyLiked(widget.song);
    updateSongLikeStatus(widget.song, !isLiked);
    songLikeStatus.value = !isLiked;
    _startLikeAnimationTimer();
  }

  Future<void> _startLikeAnimationTimer() async {
    isLikedAnimationPlaying.value = true;
    await Future.delayed(AnimatedHeart.duration);
    isLikedAnimationPlaying.value = false;
  }

  Widget _buildAlbumArt(Color primaryColor) {
    const size = 45.0;
    final isDurationAvailable =
        widget.showMusicDuration && widget.song['duration'] != null;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        BaseCard(
          inputData: widget.song,
          icon: FluentIcons.music_note_2_24_filled,
          size: size,
          paddingValue: 0,
          loadingWidget: const Spinner(),
          imageOverlayMask: true,
        ),
        if (isDurationAvailable)
          SizedBox(
            width: size,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '(${formatDuration(widget.song['duration'])})',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, TapDownDetails details) async {
    try {
      //TODO: fix positioning to account for navigation rail on large screen
      final RenderBox tappedBox = context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        tappedBox.size.width - details.globalPosition.dx,
        tappedBox.size.height - details.globalPosition.dy,
      );

      final value = await showMenu(
        context: context,
        position: position,
        color: _theme.colorScheme.surface,
        items: _buildPopupMenuItems(context),
      );
      if (value != null) {
        _popupMenuItemAction(value);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw ErrorDescription('There was an error');
    }
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems(BuildContext context) {
    try {
      final isInQueue = isSongInQueue(widget);
      return [
        PopupMenuItem<String>(
          value: 'like',
          child: ValueListenableBuilder<bool>(
            valueListenable: songLikeStatus,
            builder: (context, value, __) {
              return Row(
                children: [
                  Icon(
                    likeStatusToIconMapper[value],
                    color: _theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value
                        ? context.l10n!.removeFromLikedSongs
                        : context.l10n!.addToLikedSongs,
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.onRemove != null)
          PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                Icon(
                  FluentIcons.delete_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.removeFromPlaylist),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(
                FluentIcons.add_24_regular,
                color: _theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(context.l10n!.addToPlaylist),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: isInQueue ? 'remove_from_queue' : 'add_to_queue',
          child: Row(
            children: [
              Icon(
                isInQueue ? Icons.playlist_remove : Icons.playlist_add,
                color: _theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isInQueue
                    ? context.l10n!.removeSongFromQueue
                    : context.l10n!.addSongToQueue,
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'offline',
          child: ValueListenableBuilder<bool>(
            valueListenable: songOfflineStatus,
            builder: (context, value, __) {
              return Row(
                children: [
                  Icon(
                    value
                        ? FluentIcons.cellular_off_24_regular
                        : FluentIcons.cellular_data_1_24_regular,
                    color: _theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value
                        ? context.l10n!.removeOffline
                        : context.l10n!.makeOffline,
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.song['ytid'] != null)
          PopupMenuItem<String>(
            value: 'youtube',
            child: Row(
              children: [
                Icon(
                  FluentIcons.link_24_regular,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.openInYouTube),
              ],
            ),
          ),
        ...PM.getWidgetsByType(_getSongData, 'SongBarDropDown', context).map((
          e,
        ) {
          return e as PopupMenuItem<String>;
        }),
      ];
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw ErrorDescription('There was an error');
    }
  }

  dynamic _getSongData() {
    widget.song['album'] = widget.song['album'];
    widget.song['song'] = widget.song['title'];
    final data = widget.song;
    return data;
  }

  void _popupMenuItemAction(String value) {
    switch (value) {
      case 'like':
        songLikeStatus.value = !songLikeStatus.value;
        updateSongLikeStatus(widget.song, songLikeStatus.value);
        break;
      case 'remove':
        if (widget.onRemove != null) widget.onRemove!();
        break;
      case 'remove_from_queue':
        removeSongFromQueue(widget);
        break;
      case 'add_to_queue':
        addSongToQueue(widget);
        break;
      case 'add_to_playlist':
        showAddToPlaylistDialog(context, widget.song);
        break;
      case 'offline':
        if (songOfflineStatus.value) {
          unawaited(removeSongFromOffline(widget.song));
          showToast(context.l10n!.songRemovedFromOffline);
        } else {
          makeSongOffline(widget.song);
          showToast(context.l10n!.songAddedToOffline);
        }
        songOfflineStatus.value = !songOfflineStatus.value;
        break;
      case 'youtube':
        if (widget.song['ytid'] != null) {
          final uri = Uri.parse(
            'https://www.youtube.com/watch?v=${widget.song['ytid']}',
          );
          launchURL(uri);
        }
    }
  }

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _theme.colorScheme.surface,
      icon: Icon(FluentIcons.more_vertical_24_filled, color: primaryColor),
      onSelected: _popupMenuItemAction,
      itemBuilder: _buildPopupMenuItems,
    );
  }
}

void showAddToPlaylistDialog(BuildContext context, dynamic song) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        icon: const Icon(FluentIcons.text_bullet_list_add_24_filled),
        title: Text(context.l10n!.addToPlaylist),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child:
              userCustomPlaylists.value.isNotEmpty
                  ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: userCustomPlaylists.value.length,
                    itemBuilder: (context, index) {
                      final playlist = userCustomPlaylists.value[index];
                      return Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        elevation: 0,
                        child: ListTile(
                          title: Text(playlist['title']),
                          onTap: () {
                            showToast(
                              addSongInCustomPlaylist(
                                context,
                                playlist['title'],
                                song,
                              ),
                            );
                            GoRouter.of(context).pop(context);
                          },
                        ),
                      );
                    },
                  )
                  : Text(
                    context.l10n!.noCustomPlaylists,
                    textAlign: TextAlign.center,
                  ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(context.l10n!.cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
