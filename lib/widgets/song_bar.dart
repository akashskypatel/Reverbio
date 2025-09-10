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
import 'package:media_kit/media_kit.dart';
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
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/bottom_sheet_bar.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongBar extends StatefulWidget {
  SongBar(
    this.song,
    this.context, {
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });
  final BuildContext context;
  final Map<String, dynamic> song;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final bool showMusicDuration;
  final BorderRadius borderRadius;
  final ValueNotifier<bool> _isErrorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isPreparedNotifier = ValueNotifier(false);
  final ValueNotifier<MediaItem?> _mediaItemNotifier = ValueNotifier(null);
  final ValueNotifier<Media?> _mediaNotifier = ValueNotifier(null);
  final ValueNotifier<Future<dynamic>?> _songMetadataFutureNotifier =
      ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> songMetadataNotifier =
      ValueNotifier(null);
  final ValueNotifier<int> _statusNotifier = ValueNotifier(0);
  late final ValueNotifier<BorderRadius> _borderRadiusNotifier = ValueNotifier(
    this.borderRadius,
  );
  final _mediaItemStreamController = StreamController<MediaItem>.broadcast();

  bool get isError => _isErrorNotifier.value;
  bool get isLoading => _isLoadingNotifier.value;
  bool get isPrepared => _isPreparedNotifier.value;
  Stream<MediaItem> get mediaItemStream => _mediaItemStreamController.stream;
  MediaItem get mediaItem => _mediaItemNotifier.value ?? mapToMediaItem(song);
  Media? get media => _mediaNotifier.value;
  final ValueNotifier<FutureTracker<void>?> songPrepareTracker = ValueNotifier(
    null,
  );

  @override
  _SongBarState createState() => _SongBarState();

  Future<void> _prepareSong() async {
    try {
      songMetadataNotifier.value = copyMap(song);
      _isLoadingNotifier.value = true;
      _statusNotifier.value = 1;
      _songMetadataFutureNotifier.value = getMetadataFuture(isPrepare: true);
      unawaited(
        _songMetadataFutureNotifier.value?.then((value) {
          song.addAll(value);
          songMetadataNotifier.value = copyMap(value);
          _isLoadingNotifier.value = false;
          _statusNotifier.value = 0;
        }),
      );
      await getSongUrl(song);
      if (song['songUrl'] == null || await checkUrl(song['songUrl']) >= 400) {
        song['songUrl'] = null;
        song['isError'] = true;
        song['error'] = context.l10n!.urlError;
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
      showToast(context.l10n!.errorCouldNotFindAStream);
    }
    songMetadataNotifier.value = copyMap(song);
  }

  Future<void> getYtSong(String? newYtid) async {
    if (!isSongValid(song)) return;
    _isLoadingNotifier.value = true;
    _statusNotifier.value = 1;
    await findYTSong(song, newYtid: newYtid);
    final ytid = ((song['ytid'] ?? song['id']) as String).ytid;
    if (ytid.isNotEmpty) {
      _songMetadataFutureNotifier.value = Future.value(song);
      _isLoadingNotifier.value = false;
      _statusNotifier.value = 0;
    } else {
      _isLoadingNotifier.value = false;
      _isErrorNotifier.value = true;
      _statusNotifier.value = 3;
    }
    if (isError) {
      showToast(context.l10n!.errorCouldNotFindAStream);
    }
  }

  Future getMetadataFuture({bool isPrepare = false}) {
    try {
      parseEntityId(song);
      if (!isSongValid(song) || (!isMusicbrainzSongValid(song) && isPrepare)) {
        return queueSongInfoRequest(song);
      } else {
        return Future.value(song);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      return Future.value(song);
    }
  }

  Future prepareSong() async {
    songPrepareTracker.value = FutureTracker(null);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.songMetadataNotifier.value = copyMap(widget.song);
        widget._songMetadataFutureNotifier.value = widget.getMetadataFuture();
      }
    });
    //widget._songMetadataFutureNotifier.addListener(_songMetadataListener);
  }

  @override
  void dispose() {
    widget._songMetadataFutureNotifier.value?.ignore();
    //widget._songMetadataFutureNotifier.removeListener(_songMetadataListener);
    super.dispose();
  }

  void _songMetadataListener() {
    if (mounted)
      setState(() {
        widget._isLoadingNotifier.value = true;
        widget._statusNotifier.value = 1;
      });
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: widget._songMetadataFutureNotifier,
      builder: (context, value, child) {
        return FutureBuilder(
          future: value,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.waiting &&
                !snapshot.hasError &&
                snapshot.hasData &&
                snapshot.data != null) {
              widget.song.addAll(snapshot.requireData);
            }
            return Stack(
              children: [
                Padding(
                  padding: commonBarPadding,
                  //TODO: add left/right sliding action to add song to queue or to offline
                  child: GestureDetector(
                    onDoubleTapDown: likeItem,
                    onSecondaryTapDown: (details) {
                      _showContextMenu(context, details);
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
                            _buildAlbumArt(primaryColor),
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
                                                widget.song['mbTitle'] ??
                                                    widget.song['title'] ??
                                                    widget.song['ytTitle'] ??
                                                    'unknown',
                                                overflow: TextOverflow.ellipsis,
                                                style: commonBarTitleStyle
                                                    .copyWith(
                                                      color: primaryColor,
                                                    ),
                                              ),
                                              if (isSongAlreadyOffline(
                                                widget.song,
                                              ))
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
                                                        _theme
                                                            .colorScheme
                                                            .primary,
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
                                      combineArtists(widget.song) ??
                                          widget.song['mbArtist'] ??
                                          widget.song['artist'] ??
                                          widget.song['ytArtist'] ??
                                          'unknown',
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ValueListenableBuilder(
                                valueListenable: widget._statusNotifier,
                                builder: (context, value, child) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting)
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
                            _buildActionButtons(context, primaryColor),
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

  void likeItem(TapDownDetails details) {
    final isLiked = isSongAlreadyLiked(widget.song);
    updateSongLikeStatus(widget.song, !isLiked);
    songLikeStatus.value = !isLiked;
    AnimatedHeart.show(context: context, details: details, like: !isLiked);
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
        items: _buildPopupMenuItems(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        if (widget.song['ytid'] == null || widget.song['ytid'].isEmpty)
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
        if (widget.song['ytid'] != null && widget.song['ytid'].isNotEmpty)
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
        if (widget.song['ytSongs'] != null && widget.song['ytSongs'].isNotEmpty)
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
        if (widget.song['rid'] != null && widget.song['rid'].isNotEmpty)
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
        } else {
          makeSongOffline(widget.song);
        }
        songOfflineStatus.value = !songOfflineStatus.value;
        break;
      case 'get_youtube':
        if (widget.song['ytid'] == null || widget.song['ytid'].isEmpty)
          widget.getYtSong(null);
      case 'youtube_links':
        if (widget.song['ytSongs'] != null && widget.song['ytSongs'].isNotEmpty)
          showYoutubeLinksBottomSheet(context, widget.getYtSong, widget.song);
      case 'youtube':
        if (widget.song['ytid'] != null && widget.song['ytid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://www.youtube.com/watch?v=${widget.song['ytid']}',
          );
          launchURL(uri);
        }
        break;
      case 'musicbrainz':
        if (widget.song['rid'] != null && widget.song['rid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://musicbrainz.org/recording/${widget.song['rid']}',
          );
          launchURL(uri);
        }
        break;
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
                'Un-match',
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
                          title: Text(playlist['title'] ?? 'unknown'),
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
