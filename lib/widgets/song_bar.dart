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
import 'package:reverbio/services/queue_manager.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/services/song_preparation_controller.dart';
import 'package:reverbio/utilities/audio_tags.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
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
  // A1 fix: Factory constructor to share same NotifiableFuture instance
  // R211 fix: Accept optional songFuture parameter to allow sharing across rebuilds
  factory SongBar(
    Map<String, dynamic> songData, {
    Color? backgroundColor,
    bool showMusicDuration = false,
    VoidCallback? onRemove,
    BorderRadius borderRadius = BorderRadius.zero,
    LocalKey? key,
    NotifiableFuture<Map<String, dynamic>>? songFuture,
  }) {
    // R211 fix: Reuse provided songFuture or create new one
    final future = songFuture ?? NotifiableFuture<Map<String, dynamic>>(songData);
    return SongBar._(
      songData: songData,
      songFuture: future,
      backgroundColor: backgroundColor,
      showMusicDuration: showMusicDuration,
      onRemove: onRemove,
      borderRadius: borderRadius,
      key: key,
    );
  }

  // Private constructor that receives shared songFuture
  SongBar._({
    required this.songData,
    required this.songFuture,
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    super.key,
  }) : controller = SongPreparationController(
         song: songData,
         songFuture: songFuture,  // ✅ Same instance!
       );
  // R7 fix: Removed context field - use State's context instead
  final Map<String, dynamic> songData;
  final NotifiableFuture<Map<String, dynamic>> songFuture;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final bool showMusicDuration;
  final BorderRadius borderRadius;
  // A1 fix: Public controller for direct access by audio service
  final SongPreparationController controller;

  @override
  _SongBarState createState() => _SongBarState();

  // A1 fix: Direct property access instead of broken GlobalKey lookup
  Map<String, dynamic> get song => controller.song;
  String? get title => songTitle(song);
  String? get artist => songArtist(song);
  bool get isError => controller.isError;
  bool get isLoading => controller.isLoading;
  bool get isPrepared => controller.isPrepared;
  MediaItem? get mediaItem => controller.mediaItem;
  Media? get media => controller.media;
  Stream<MediaItem>? get mediaItemStream => controller.mediaItemStream;
  ValueNotifier<Map<String, dynamic>> get songMetadataNotifier =>
      controller.songMetadataNotifier;
  ValueNotifier<BorderRadius> get borderRadiusNotifier =>
      controller.borderRadiusNotifier;
  ValueNotifier<NotifiableFuture<void>?> get songPrepareTracker =>
      controller.songPrepareTracker;

  // A1 fix: Direct method calls on controller
  Future prepareSong() => controller.prepareSong();
  void setBorder({BorderRadius borderRadius = BorderRadius.zero}) =>
      controller.setBorder(borderRadius: borderRadius);
  bool setVisibility(bool show) => controller.setVisibility(show);
  bool equals(SongBar other) => checkSong(song, other.song);
}

class _SongBarState extends State<SongBar> {
  // A1 fix: Use widget's controller directly instead of creating duplicate
  SongPreparationController get controller => widget.controller;
  late ThemeData _theme;

  TapDownDetails? doubleTapDetails;

  late final songLikeStatus = ValueNotifier<bool>(
    isSongAlreadyLiked(widget.songData),
  );
  late final songOfflineStatus = ValueNotifier<bool>(
    isSongAlreadyOffline(widget.songData),
  );
  final ValueNotifier<bool> isLikedAnimationPlaying = ValueNotifier(false);
  Future<Tag?>? _songTagFuture;

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  // A1 fix: Direct access to widget's controller
  Map<String, dynamic> get song => widget.song;
  bool get isError => widget.isError;
  bool get isLoading => widget.isLoading;
  bool get isPrepared => widget.isPrepared;
  MediaItem? get mediaItem => widget.mediaItem;
  Media? get media => widget.media;
  Stream<MediaItem>? get mediaItemStream => widget.mediaItemStream;
  ValueNotifier<Map<String, dynamic>> get songMetadataNotifier =>
      widget.songMetadataNotifier;
  ValueNotifier<BorderRadius> get borderRadiusNotifier =>
      widget.borderRadiusNotifier;
  ValueNotifier<NotifiableFuture<void>?> get songPrepareTracker =>
      widget.songPrepareTracker;

  // A1 fix: Direct method calls on widget's controller
  Future prepareSong() => widget.prepareSong();
  void setBorder({BorderRadius borderRadius = BorderRadius.zero}) =>
      widget.setBorder(borderRadius: borderRadius);
  bool setVisibility(bool show) => widget.setVisibility(show);
  bool equals(SongBar other) => checkSong(song, other.song);

  @override
  void initState() {
    super.initState();
    // R176 fix: Only run future if not already loading or complete
    if (!widget.songFuture.isLoading && !widget.songFuture.isComplete) {
      widget.songFuture.runFuture(getSongInfo(widget.songData));
    }
    _songTagFuture = _fetchSongTag();
    widget.songFuture.addListener(_listener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          if (widget.songFuture.isComplete) {
            final _song = copyMap(widget.controller.songMetadataNotifier.value)
              ..addAll(widget.songFuture.resultOrData ?? {});
            widget.controller.songMetadataNotifier.value = _song;
            widget.controller.isLoadingNotifier.value = false;
            widget.controller.statusNotifier.value = 0;
          }
        });
      }
    });
  }

  // R86 fix: Dispose old widget's controller when widget is updated
  @override
  void didUpdateWidget(SongBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dispose the old controller to prevent resource leak
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.dispose();
      oldWidget.songFuture.removeListener(_listener);
      oldWidget.songFuture.dispose();
    }
  }

  @override
  void dispose() {
    // A1 fix: Dispose controller which handles all ValueNotifiers
    widget.controller.dispose();
    songLikeStatus.dispose();
    songOfflineStatus.dispose();
    isLikedAnimationPlaying.dispose();
    widget.songFuture.removeListener(_listener);
    widget.songFuture.dispose();
    super.dispose();
  }

  // R259 fix: Only fetch song tag when necessary - avoid unnecessary FFprobe I/O
  Future<Tag?> _fetchSongTag() {
    // Skip tag fetch if:
    // 1. Song is not offline (online YouTube song)
    // 2. Song already has cached audioTags
    // 3. Song metadata is already complete
    if (!isSongAlreadyOffline(widget.song)) {
      return Future.value();
    }
    if (widget.song['audioTags'] != null &&
        widget.song['audioTags'] is Map &&
        (widget.song['audioTags'] as Map).isNotEmpty) {
      return Future.value();
    }
    // Only fetch from file for offline songs missing metadata
    return FileTagger().getTagFromFileOrMetadata(widget.song);
  }

  void invalidateSongTag() {
    setState(() {
      _songTagFuture = _fetchSongTag();
    });
  }

  void _listener() {
    // R13 fix: Guard against disposed state
    if (!mounted) return;
    if (widget.songFuture.isComplete && widget.songFuture.hasResult) {
      final _song = copyMap(widget.controller.songMetadataNotifier.value)
        ..addAll(widget.songFuture.resultOrData ?? {});
      widget.controller.songMetadataNotifier.value = _song;
    } else
      widget.songFuture.completerFuture?.then((value) {
        if (mounted)
          setState(() {
            if (widget.songFuture.isComplete && widget.songFuture.hasResult) {
              final _song = copyMap(widget.controller.songMetadataNotifier.value)
                ..addAll(widget.songFuture.resultOrData ?? {});
              widget.controller.songMetadataNotifier.value = _song;
            }
            widget.controller.isLoadingNotifier.value = false;
            widget.controller.statusNotifier.value = 0;
          });
      });
  }

  // R6 fix: Race condition guard in _prepareSong
  Future<void> _prepareSong() async {
    if (widget.controller.isPreparing) return;
    widget.controller.isPreparing = true;
    try {
      final _song = copyMap(widget.controller.songMetadataNotifier.value)
        ..addAll(widget.songFuture.resultOrData ?? {});
      widget.controller.songMetadataNotifier.value = _song;
      widget.controller.isLoadingNotifier.value = true;
      widget.controller.statusNotifier.value = 1;
      widget.songFuture.copyValuesFrom(getMetadataFuture(isPrepare: true));
      await widget.songFuture.completerFuture;
      await getSongUrl(widget.song).then((value) {
        final _song = copyMap(widget.controller.songMetadataNotifier.value)
          ..addAll(value);
        widget.controller.songMetadataNotifier.value = _song;
      });
      // R4 fix: Create new map copy instead of mutating via getter bypass
      if (widget.song['songUrl'] == null ||
          await checkUrl(widget.song['songUrl']) >= 400) {
        final _song =
            copyMap(widget.controller.songMetadataNotifier.value)
              ..['songUrl'] = null
              ..['isError'] = true
              ..['error'] = L10n.current.urlError;
        widget.controller.songMetadataNotifier.value = _song;
      }
      await _updateMediaItem();
      widget.controller.isPreparedNotifier.value = true;
      widget.controller.statusNotifier.value = 0;
      widget.controller.statusNotifier.value =
          widget.song.containsKey('isError')
              ? ((widget.song['isError'] ?? false) ? 3 : 0)
              : 0;
      widget.controller.isErrorNotifier.value =
          widget.song.containsKey('isError') ? widget.song['isError'] : false;
      widget.controller.isLoadingNotifier.value = false;
    } catch (e, stackTrace) {
      widget.controller.isLoadingNotifier.value = false;
      widget.controller.isErrorNotifier.value = true;
      widget.controller.statusNotifier.value = 3;
      logger.log('Error in prepareSong:', e, stackTrace);
    } finally {
      widget.controller.isPreparing = false;
    }
    if (widget.controller.isErrorNotifier.value) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
    final _song = copyMap(widget.controller.songMetadataNotifier.value)
      ..addAll(widget.songFuture.resultOrData ?? {});
    widget.controller.songMetadataNotifier.value = _song;
  }

  Future<void> getYtSong(String? newYtid) async {
    if (!isSongValid(widget.song)) return;
    widget.controller.isLoadingNotifier.value = true;
    widget.controller.statusNotifier.value = 1;
    final ytSong = await findYTSong(widget.song, newYtid: newYtid);
    final ytid = (widget.song['ytid'] ?? widget.song['id']) as String? ?? '';
    if (ytid.isNotEmpty && isYouTubeSongValid(ytSong)) {
      final _song = copyMap(ytSong)
        ..addAll(widget.songFuture.resultOrData ?? {});
      widget.controller.songMetadataNotifier.value = _song;
      widget.controller.isLoadingNotifier.value = false;
      widget.controller.statusNotifier.value = 0;
      // R14 fix: Don't auto-launch YouTube - just update song data
      // User can manually open in YouTube from context menu if desired
      // final uri = Uri.parse('https://www.youtube.com/watch?v=$ytid');
      // await launchURL(uri);
    } else {
      widget.controller.isLoadingNotifier.value = false;
      widget.controller.isErrorNotifier.value = true;
      widget.controller.statusNotifier.value = 3;
    }
    if (widget.controller.isErrorNotifier.value) {
      showToast(L10n.current.errorCouldNotFindAStream);
    }
  }

  NotifiableFuture<Map<String, dynamic>> getMetadataFuture({
    bool isPrepare = false,
  }) {
    try {
      if (!isSongValid(widget.song) ||
          (!isMusicbrainzSongValid(widget.song) && isPrepare)) {
        return queueSongInfoRequest(widget.song);
      } else {
        return NotifiableFuture.fromValue(widget.song);
      }
    } catch (e, stackTrace) {
      logger.log('Error in getMetadataFuture:', e, stackTrace);
      return NotifiableFuture.fromValue(widget.song);
    }
  }

  Future<void> _updateMediaItem() async {
    widget.song['image'] = (await getValidImage(widget.song))?.toString();
    widget.controller.mediaItemNotifier.value = mapToMediaItem(widget.song);
    widget.controller.addMediaItemToStream(widget.controller.mediaItemNotifier.value!);
    if (widget.song['songUrl'] != null && !widget.controller.isErrorNotifier.value)
      widget.controller.mediaNotifier.value = await audioHandler.buildAudioSource(
        widget.songData,
      );
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final primaryColor = _theme.colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: widget.controller.isVisible,
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
        final title = songTitle(song).nullIfEmpty;
        final artist = (combineArtists(song) ?? songArtist(song)).nullIfEmpty;
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
                    song: widget.songData,
                    play: true,
                    skipOnError: true,
                  );
                },
                child: Card(
                  color: widget.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: widget.controller.borderRadiusNotifier.value,
                  ),
                  margin: const EdgeInsets.only(bottom: 3),
                  child: Padding(
                    padding: commonBarContentPadding,
                    child: Row(
                      children: [
                        _buildArtwork(song),
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
                                                    ? context.l10n!.loading
                                                    : kDebugMode
                                                    ? 'unknown ${(song as Map)['id']}'
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
                                          ? context.l10n!.loading
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
                            valueListenable: widget.controller.statusNotifier,
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

  Widget _buildArtwork(dynamic song) {
    const size = 45.0;
    return FutureBuilder<Tag?>(
      future: _songTagFuture,
      builder: (context, snapshot) {
        // R11 fix: Remove unreachable else branch - simplify to single BaseCard
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data == null ||
            snapshot.hasError ||
            snapshot.data!.pictures.isEmpty) {
          return BaseCard(
            inputData: song,
            icon: FluentIcons.music_note_2_24_filled,
            size: size,
            paddingValue: 0,
            loadingWidget: SizedBox.square(
              dimension: 35,
              child: Spinner(color: _theme.colorScheme.onSecondary),
            ),
            duration: song['duration'],
            showIconLabel: false,
          );
        }
        // Has valid picture data
        return BaseCard(
          inputData: song,
          image: Image.memory(
            snapshot.data!.pictures.first.bytes,
            cacheHeight: (size * 1.1).toInt(),
            cacheWidth: (size * 1.1).toInt(),
          ),
          icon: FluentIcons.music_note_2_24_filled,
          size: size,
          paddingValue: 0,
          loadingWidget: SizedBox.square(
            dimension: 35,
            child: Spinner(color: _theme.colorScheme.onSecondary),
          ),
          duration: song['duration'],
          showIconLabel: false,
        );
      },
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
        await _popupMenuItemAction(context, value, song);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      // R7 fix: Show error toast instead of rethrowing as ErrorDescription
      if (context.mounted) {
        showToast('Failed to open menu: $e');
      }
    }
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems(
    BuildContext context,
    dynamic song,
  ) {
    try {
      final isInQueue = isSongInQueue(widget.songData);
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
          )
        else
          PopupMenuItem<String>(
            value: 'get_musicbrainz',
            child: Row(
              children: [
                Icon(
                  FluentIcons.database_search_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.getMetadata),
              ],
            ),
          ),
        if (isSongAlreadyOffline(song))
          PopupMenuItem<String>(
            value: 'tag',
            child: Row(
              children: [
                Icon(
                  FluentIcons.tag_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.editTags),
              ],
            ),
          ),
        if (isSongAppOfflineOnly(song) && !isSongInDeviceLibrary(song))
          PopupMenuItem<String>(
            value: 'move_to_library',
            child: Row(
              children: [
                Icon(
                  FluentIcons.folder_arrow_right_24_filled,
                  color: _theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(context.l10n!.moveToLibrary),
              ],
            ),
          ),
        if (enablePlugins.value)
          // R10 fix: Pass function that returns widget.song instead of removed _getSongData
          ...PM
              .getWidgetsByType(() => widget.song, 'SongBarDropDown', context)
              .map((e) {
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

  // R10 fix: Remove no-op transformation - was just self-assignment
  // This function was a no-op that assigned song['album'] = song['album'] and returned the same object
  // Callers can use song directly

  Future<void> _popupMenuItemAction(
    BuildContext context,
    String value,
    dynamic song,
  ) async {
    switch (value) {
      case 'like':
        songLikeStatus.value = !songLikeStatus.value;
        unawaited(updateSongLikeStatus(song, songLikeStatus.value));
        break;
      case 'remove':
        if (widget.onRemove != null) widget.onRemove!();
        break;
      case 'remove_from_queue':
        removeSongFromQueue(widget.songData);
        break;
      case 'add_to_queue':
        addSongToQueue(widget.songData);
        break;
      case 'add_to_playlist':
        showAddToPlaylistDialog(context, song);
        break;
      case 'offline':
        if (songOfflineStatus.value) {
          unawaited(removeSongFromOffline(song));
        } else {
          unawaited(makeSongOffline(song));
        }
        songOfflineStatus.value = !songOfflineStatus.value;
        break;
      case 'get_youtube':
        if (song['ytid'] == null || song['ytid'].isEmpty)
          unawaited(getYtSong(null));
        // R5 fix: Add missing break to prevent fall-through
        break;
      case 'youtube_links':
        if (song['ytSongs'] != null && song['ytSongs'].isNotEmpty)
          showYoutubeLinksBottomSheet(context, getYtSong, song);
        // R5 fix: Add missing break to prevent fall-through
        break;
      case 'youtube':
        if (song['ytid'] != null && song['ytid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://www.youtube.com/watch?v=${song['ytid']}',
          );
          await launchURL(uri);
        }
        break;
      case 'musicbrainz':
        if (song['rid'] != null && song['rid'].isNotEmpty) {
          final uri = Uri.parse(
            'https://musicbrainz.org/recording/${song['rid'] ?? song['mbid']}',
          );
          await launchURL(uri);
        }
        break;
      case 'get_musicbrainz':
        // R15 fix: Use widget.song after _prepareSong to get fresh data
        await _prepareSong();
        final uri = Uri.parse(
          'https://musicbrainz.org/recording/${widget.song['rid'] ?? widget.song['mbid']}',
        );
        await launchURL(uri);
        break;
      case 'tag':
        openMetadataForm(context, song);
        break;  // R5 fix: Prevent fall-through to move_to_library
      case 'move_to_library':
        {
          final count = await moveSongToDeviceLibrary(song);
          if (count > 0) {
            userOfflineSongs.removeWhere((e) => checkEntityId(song['id'], e));
            showToast('${context.l10n!.movedFiles} $count', context: context);
          } else {
            showToast(context.l10n!.notMoved, context: context);
          }
        }
    }
  }

  // R7/R9 fix: Use GoRouter navigation consistently instead of Navigator.push
  void openMetadataForm(BuildContext context, dynamic song) {
    final songId = song['id'] ?? '';
    context.go('/editMetadata?song=$songId');
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
      onSelected: (value) async {
        await _popupMenuItemAction(context, value, song);
      },
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
            // R12 fix: Remove unreachable else branch - index is always < linkList.length
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
                            // R8 fix: Use consistent Navigator.of(context).pop()
                            final result = addSongToCustomPlaylist(
                              playlist['title'],
                              song,
                            );
                            showToast(result.toLocalizedString());
                            Navigator.of(context).pop();
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

/// A1 fix: Moved from song.dart to decouple entity from widget layer
/// R211 fix: Accept optional songFuture to share across rebuilds
/// R7 fix: Removed context parameter - SongBar no longer stores context
SongBar initializeSongBar(
  Map<String, dynamic> song, {
  BorderRadius? borderRadius,
  NotifiableFuture<Map<String, dynamic>>? songFuture,
}) {
  return SongBar(
    song,
    borderRadius: borderRadius ?? BorderRadius.zero,
    showMusicDuration: true,
    songFuture: songFuture,
  );
}

/// A1 fix: Moved from song.dart to decouple entity from widget layer
NotifiableFuture<Map<String, dynamic>> initializeSongBarFuture(dynamic song) {
  try {
    parseEntityId(song);
    if (!isSongValid(song)) {
      return queueSongInfoRequest(song);
    } else {
      final futureTracker = NotifiableFuture<Map<String, dynamic>>(song)
        ..runFuture(Future.value(song));
      return futureTracker;
    }
  } catch (e, stackTrace) {
    logger.log('Error in ${stackTrace.getCurrentMethodName()}:', e, stackTrace);
    final futureTracker = NotifiableFuture<Map<String, dynamic>>(song)
      ..runFuture(Future.value(song));
    return futureTracker;
  }
}
