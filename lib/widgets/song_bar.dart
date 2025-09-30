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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/mediaitem.dart';
import 'package:reverbio/utilities/notifiable_future.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/bottom_sheet_bar.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongBar extends StatefulWidget {
  SongBar(
    this.songData,
    this.context, {
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    super.key,
  }) : songFuture = initializeSongBarFuture(songData),
       songMetadataNotifier = ValueNotifier(copyMap(songData)),
       _borderRadiusNotifier = ValueNotifier(borderRadius);
  final BuildContext context;
  final Map<String, dynamic> songData;
  final NotifiableFuture<Map<String, dynamic>> songFuture;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final bool showMusicDuration;
  final BorderRadius borderRadius;
  final ValueNotifier<bool> _isVisible = ValueNotifier(true);
  final ValueNotifier<bool> _isErrorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPreparedNotifier = ValueNotifier(false);
  final ValueNotifier<MediaItem?> _mediaItemNotifier = ValueNotifier(null);
  final ValueNotifier<Media?> _mediaNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>> songMetadataNotifier;
  final ValueNotifier<int> _statusNotifier = ValueNotifier(0);
  final ValueNotifier<BorderRadius> _borderRadiusNotifier;
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();
  Map<String, dynamic> get song => songMetadataNotifier.value;
  String? get title => song['mbTitle'] ?? song['title'] ?? song['ytTitle'];
  String? get artist => song['mbArtist'] ?? song['artist'] ?? song['ytArtist'];
  bool get isError => _isErrorNotifier.value;
  bool get isLoading => _isLoadingNotifier.value;
  bool get isPrepared => _isPreparedNotifier.value;
  Stream<MediaItem> get mediaItemStream => _mediaItemStreamController.stream;
  MediaItem get mediaItem => _mediaItemNotifier.value ?? mapToMediaItem(song);
  Media? get media => _mediaNotifier.value;
  final ValueNotifier<NotifiableFuture<void>?> songPrepareTracker =
      ValueNotifier(null);

  @override
  _SongBarState createState() => _SongBarState();

  bool setVisibility(bool show) {
    return _isVisible.value = show;
  }

  Future<void> _prepareSong() async {
    try {
      final _song = copyMap(songMetadataNotifier.value)
        ..addAll(songFuture.resultOrData ?? {});
      songMetadataNotifier.value = _song;
      _isLoadingNotifier.value = true;
      _statusNotifier.value = 1;
      songFuture.copyValuesFrom(getMetadataFuture(isPrepare: true));
      await songFuture.completerFuture;
      await getSongUrl(song).then((value) {
        final _song = copyMap(songMetadataNotifier.value)..addAll(value);
        songMetadataNotifier.value = _song;
      });
      if (song['songUrl'] == null || await checkUrl(song['songUrl']) >= 400) {
        song['songUrl'] = null;
        song['isError'] = true;
        song['error'] = L10n.current.urlError;
      }
      await _updateMediaItem();
      _isPreparedNotifier.value = true;
      _statusNotifier.value = 0;
      _statusNotifier.value =
          song.containsKey('isError')
              ? ((song['isError'] ?? false) ? 3 : 0)
              : 0;
      _isErrorNotifier.value =
          song.containsKey('isError') ? song['isError'] : false;
      _isLoadingNotifier.value = false;
    } catch (e, stackTrace) {
      _isLoadingNotifier.value = false;
      _isErrorNotifier.value = true;
      _statusNotifier.value = 3;
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
    }
    if (isError) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
    final _song = copyMap(songMetadataNotifier.value)
      ..addAll(songFuture.resultOrData ?? {});
    songMetadataNotifier.value = _song;
  }

  Future<void> getYtSong(String? newYtid) async {
    if (!isSongValid(song)) return;
    _isLoadingNotifier.value = true;
    _statusNotifier.value = 1;
    final ytSong = await findYTSong(song, newYtid: newYtid);
    final ytid = ((song['ytid'] ?? song['id']) as String).ytid;
    if (ytid.isNotEmpty && isYouTubeSongValid(ytSong)) {
      final _song = copyMap(ytSong)..addAll(songFuture.resultOrData ?? {});
      songMetadataNotifier.value = _song;
      _isLoadingNotifier.value = false;
      _statusNotifier.value = 0;
      final uri = Uri.parse('https://www.youtube.com/watch?v=$ytid');
      await launchURL(uri);
    } else {
      _isLoadingNotifier.value = false;
      _isErrorNotifier.value = true;
      _statusNotifier.value = 3;
    }
    if (isError) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
  }

  NotifiableFuture<Map<String, dynamic>> getMetadataFuture({
    bool isPrepare = false,
  }) {
    try {
      parseEntityId(song);
      if (!isSongValid(song) || (!isMusicbrainzSongValid(song) && isPrepare)) {
        return queueSongInfoRequest(song);
      } else {
        return NotifiableFuture.fromValue(song);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return NotifiableFuture.fromValue(song);
    }
  }

  Future prepareSong() async {
    songPrepareTracker.value = NotifiableFuture();
    return songPrepareTracker.value!.runFuture(_prepareSong());
  }

  void setBorder({BorderRadius borderRadius = BorderRadius.zero}) {
    _borderRadiusNotifier.value = borderRadius;
  }

  bool equals(SongBar other) {
    return checkSong(song, other.song);
  }

  Future<void> _updateMediaItem() async {
    song['image'] = (await getValidImage(song))?.toString();
    _mediaItemNotifier.value = mapToMediaItem(song);
    if (song['songUrl'] != null && !isError)
      _mediaNotifier.value = await audioHandler.buildAudioSource(this);
  }
}

class _SongBarState extends State<SongBar> {
  late ThemeData _theme;

  TapDownDetails? doubleTapDetails;

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
    widget.songFuture.addListener(_listener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          if (widget.songFuture.isComplete) {
            final _song = copyMap(widget.songMetadataNotifier.value)
              ..addAll(widget.songFuture.resultOrData ?? {});
            widget.songMetadataNotifier.value = _song;
            widget._isLoadingNotifier.value = false;
            widget._statusNotifier.value = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    widget.songFuture.removeListener(_listener);
    super.dispose();
  }

  void _listener() {
    if (widget.songFuture.isComplete && widget.songFuture.hasResult) {
      final _song = copyMap(widget.songMetadataNotifier.value)
        ..addAll(widget.songFuture.resultOrData ?? {});
      widget.songMetadataNotifier.value = _song;
    } else
      widget.songFuture.completerFuture?.then((value) {
        if (mounted)
          setState(() {
            if (widget.songFuture.isComplete && widget.songFuture.hasResult) {
              final _song = copyMap(widget.songMetadataNotifier.value)
                ..addAll(widget.songFuture.resultOrData ?? {});
              widget.songMetadataNotifier.value = _song;
            }
            widget._isLoadingNotifier.value = false;
            widget._statusNotifier.value = 0;
          });
      });
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: widget._isVisible,
      builder:
          (context, value, child) => Visibility(
            visible: value,
            child: _buildSongBar(context, primaryColor),
          ),
    );
  }

  Widget _buildSongBar(BuildContext context, Color primaryColor) {
    return ListenableBuilder(
      listenable: widget.songFuture,
      builder: (context, child) {
        return widget.songFuture.build(
          idle: () => _getSongBar(context, primaryColor),
          loading: () => _getSongBar(context, primaryColor),
          data: (_) => _getSongBar(context, primaryColor),
          error: (_, __) => _getSongBar(context, primaryColor),
        );
      },
    );
  }

  Widget _getSongBar(BuildContext context, Color primaryColor) {
    return ValueListenableBuilder(
      valueListenable: widget.songMetadataNotifier,
      builder: (context, song, child) {
        song = widget.songMetadataNotifier.value;
        final isLoading = widget.songFuture.isLoading;
        final title = song['mbTitle'] ?? song['title'] ?? song['ytTitle'];
        final artist =
            combineArtists(song) ??
            song['mbArtist'] ??
            song['artist'] ??
            song['ytArtist'];
        return Stack(
          children: [
            Padding(
              padding: commonBarPadding,
              //TODO: add left/right sliding action to add song to queue or to offline
              child: GestureDetector(
                onDoubleTapDown: (details) => likeItem(details, song),
                onSecondaryTapDown: (details) {
                  _showContextMenu(context, details, song);
                },
                onTap: () async {
                  await audioHandler.prepare(
                    songBar: widget,
                    play: true,
                    skipOnError: true,
                  );
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
                        _buildAlbumArt(primaryColor, song),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Expanded(
                                    child: MarqueeWidget(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title ??
                                                (isLoading
                                                    ? 'Loading...'
                                                    : kDebugMode
                                                    ? 'unknown ${song['id']}'
                                                    : context.l10n!.unknown),
                                            overflow: TextOverflow.ellipsis,
                                            style: commonBarTitleStyle.copyWith(
                                              color: primaryColor,
                                            ),
                                          ),
                                          if (isSongAlreadyOffline(song))
                                            Padding(
                                              padding:
                                                  const EdgeInsetsGeometry.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: Icon(
                                                FluentIcons
                                                    .arrow_download_24_filled,
                                                size: 14,
                                                color:
                                                    _theme.colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              MarqueeWidget(
                                child: Text(
                                  artist ??
                                      (isLoading
                                          ? 'Loading...'
                                          : context.l10n!.unknown),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 13,
                                    color: _theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ValueListenableBuilder(
                            valueListenable: widget._statusNotifier,
                            builder: (context, value, child) {
                              if (isLoading)
                                return _buildLoadingSpinner(context);
                              switch (value) {
                                case 0:
                                  return const SizedBox.shrink();
                                case 1:
                                  return _buildLoadingSpinner(context);
                                case 3:
                                  return _buildErrorIconWidget(context);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        _buildActionButtons(context, primaryColor, song),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingSpinner(BuildContext context) {
    return Tooltip(
      waitDuration: const Duration(milliseconds: 1500),
      message: context.l10n!.loading,
      child: const SizedBox(width: 24, height: 24, child: Spinner()),
    );
  }

  Widget _buildErrorIconWidget(BuildContext context) {
    return Tooltip(
      waitDuration: const Duration(milliseconds: 1500),
      message: context.l10n!.errorCouldNotFindAStream,
      child: Icon(
        FluentIcons.error_circle_24_filled,
        color: _theme.colorScheme.primary,
      ),
    );
  }

  void likeItem(TapDownDetails details, dynamic song) {
    final isLiked = isSongAlreadyLiked(song);
    updateSongLikeStatus(song, !isLiked);
    songLikeStatus.value = !isLiked;
    AnimatedHeart.show(context: context, details: details, like: !isLiked);
  }

  Widget _buildAlbumArt(Color primaryColor, dynamic song) {
    const size = 45.0;
    final isDurationAvailable =
        widget.showMusicDuration && song['duration'] != null;
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        BaseCard(
          inputData: song,
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
                '(${formatDuration(song['duration'])})',
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

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    dynamic song,
  ) async {
    try {
      //TODO: fix positioning to account for navigation rail on large screen
      final RenderBox tappedBox = context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromLTRB(
        details.globalPosition.dx - (isLargeScreen() ? navigationRailWidth : 0),
        details.globalPosition.dy,
        tappedBox.size.width -
            details.globalPosition.dx -
            (isLargeScreen() ? navigationRailWidth : 0),
        tappedBox.size.height - details.globalPosition.dy,
      );

      final value = await showMenu(
        context: context,
        position: position,
        color: _theme.colorScheme.surface,
        items: _buildPopupMenuItems(context, song),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
      if (value != null) {
        _popupMenuItemAction(value, song);
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

  List<PopupMenuItem<String>> _buildPopupMenuItems(
    BuildContext context,
    dynamic song,
  ) {
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
        if (song['ytid'] == null || song['ytid'].isEmpty)
          PopupMenuItem<String>(
            value: 'get_youtube',
            child: Row(
              children: [
                Icon(
                  FluentIcons.link_24_regular,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.getYouTube),
              ],
            ),
          ),
        if (song['ytid'] != null && song['ytid'].isNotEmpty)
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
        if (song['ytSongs'] != null && song['ytSongs'].isNotEmpty)
          PopupMenuItem<String>(
            value: 'youtube_links',
            child: Row(
              children: [
                Icon(
                  FluentIcons.apps_list_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.youtubeLinks),
              ],
            ),
          ),
        if (song['rid'] != null && song['rid'].isNotEmpty)
          PopupMenuItem<String>(
            value: 'musicbrainz',
            child: Row(
              children: [
                Icon(
                  FluentIcons.database_link_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.openInMusicBrainz),
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

  dynamic _getSongData(dynamic song) {
    song['album'] = song['album'];
    song['song'] = song['title'];
    final data = song;
    return data;
  }

  void _popupMenuItemAction(String value, dynamic song) {
    switch (value) {
      case 'like':
        songLikeStatus.value = !songLikeStatus.value;
        updateSongLikeStatus(song, songLikeStatus.value);
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
        showAddToPlaylistDialog(context, song);
        break;
      case 'offline':
        if (songOfflineStatus.value) {
          unawaited(removeSongFromOffline(song));
        } else {
          makeSongOffline(song);
        }
        songOfflineStatus.value = !songOfflineStatus.value;
        break;
      case 'get_youtube':
        if (song['ytid'] == null || song['ytid'].isEmpty)
          widget.getYtSong(null);
      case 'youtube_links':
        if (song['ytSongs'] != null && song['ytSongs'].isNotEmpty)
          showYoutubeLinksBottomSheet(context, widget.getYtSong, song);
      case 'youtube':
        if (song['ytid'] != null && song['ytid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://www.youtube.com/watch?v=${song['ytid']}',
          );
          launchURL(uri);
        }
        break;
      case 'musicbrainz':
        if (song['rid'] != null && song['rid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://musicbrainz.org/recording/${song['rid']}',
          );
          launchURL(uri);
        }
        break;
    }
  }

  Widget _buildActionButtons(
    BuildContext context,
    Color primaryColor,
    dynamic song,
  ) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _theme.colorScheme.surface,
      icon: Icon(FluentIcons.more_vertical_24_filled, color: primaryColor),
      onSelected: (value) => _popupMenuItemAction(value, song),
      itemBuilder: (context) => _buildPopupMenuItems(context, song),
    );
  }
}

void showYoutubeLinksBottomSheet(
  BuildContext context,
  Function(String?) updateYtLink,
  dynamic song,
) {
  final linkList = (song['ytSongs'] ?? []) as List;
  final _theme = Theme.of(context);
  final activatedColor = _theme.colorScheme.secondaryContainer;
  final inactivatedColor = _theme.colorScheme.surfaceContainerHigh;
  showCustomBottomSheet(
    context,
    StatefulBuilder(
      builder: (context, setState) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: commonListViewBottomPadding,
          itemCount: linkList.length,
          itemBuilder: (context, index) {
            final borderRadius = getItemBorderRadius(index, linkList.length);
            if (index < linkList.length) {
              final link = linkList[index];
              final linkYtid = ((link['ytid'] ?? link['id']) as String).ytid;
              final songYtid = ((song['ytid'] ?? song['id']) as String).ytid;
              final selected = songYtid.contains(linkYtid);
              final openInYoutube = IconButton(
                onPressed: () {
                  final uri = Uri.parse(
                    'https://www.youtube.com/watch?v=$linkYtid',
                  );
                  launchURL(uri);
                },
                icon: const Icon(FluentIcons.link_24_regular),
              );
              return BottomSheetBar(
                link['ytTitle'],
                selected ? activatedColor : inactivatedColor,
                subtitle: link['ytArtist'],
                borderRadius: borderRadius,
                actions: [openInYoutube],
                onTap: () async {
                  await updateYtLink(linkYtid);
                  if (context.mounted) setState(() {});
                },
              );
            } else {
              return BottomSheetBar(
                context.l10n!.unMatch,
                inactivatedColor,
                borderRadius: borderRadius,
              );
            }
          },
        );
      },
    ),
  );
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
              userCustomPlaylists.isNotEmpty
                  ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: userCustomPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = userCustomPlaylists[index];
                      return Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        elevation: 0,
                        child: ListTile(
                          title: Text(
                            playlist['title'] ?? context.l10n!.unknown,
                          ),
                          onTap: () {
                            showToast(
                              addSongToCustomPlaylist(
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
