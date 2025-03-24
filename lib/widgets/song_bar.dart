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

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongBar extends StatefulWidget {
  SongBar(
    this.song,
    this.clearPlaylist, {
    this.backgroundColor,
    this.showMusicDuration = false,
    this.onPlay,
    this.onRemove,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final dynamic song;
  final bool clearPlaylist;
  final Color? backgroundColor;
  final VoidCallback? onRemove;
  final VoidCallback? onPlay;
  final bool showMusicDuration;
  final BorderRadius borderRadius;

  @override
  _SongBarState createState() => _SongBarState();
}

class _SongBarState extends State<SongBar> {
  dynamic loadedSong = false;
  bool isLoading = false;
  bool isError = false;
  TapDownDetails? doubleTapdetails;

  late final songLikeStatus = ValueNotifier<bool>(
    isSongAlreadyLiked(widget.song['ytid']),
  );
  late final songOfflineStatus = ValueNotifier<bool>(
    isSongAlreadyOffline(widget.song['ytid']),
  );
  final ValueNotifier<bool> isLikedAnimationPlaying = ValueNotifier(false);

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Padding(
          padding: commonBarPadding,
          child: GestureDetector(
            onDoubleTapDown: (details) {
              doubleTapdetails = details;
              likeItem();
            },
            onTap: widget.onPlay ?? _playSong,
            child: Card(
              color: widget.backgroundColor,
              shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
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
                            widget.song['artist'].toString(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: Spinner(),
                              )
                              : isError
                              ? Icon(
                                FluentIcons.error_circle_24_filled,
                                color: Theme.of(context).colorScheme.primary,
                              )
                              : const SizedBox.shrink(),
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
              (_, value, _) =>
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

  void likeItem() {
    final isLiked = isSongAlreadyLiked(widget.song['id']);
    updateSongLikeStatus(widget.song['id'], !isLiked);
    songLikeStatus.value = !isLiked;
    _startLikeAnimationTimer();
  }

  Future<void> _startLikeAnimationTimer() async {
    isLikedAnimationPlaying.value = true;
    await Future.delayed(AnimatedHeart.duration);
    isLikedAnimationPlaying.value = false;
  }

  void _playSong() async {
    if (mounted)
      setState(() {
        isLoading = true;
      });
    final loaded = await audioHandler.playSong(widget.song);

    if (activePlaylist.isNotEmpty && widget.clearPlaylist) {
      activePlaylist = {
        'ytid': '',
        'title': 'No Playlist',
        'image': '',
        'source': 'user-created',
        'list': [],
      };
      activeSongId = 0;
    }
    if (mounted)
      setState(() {
        loadedSong = loaded;
        isLoading = false;
        isError = loaded['source'] == null;
      });
  }

  Widget _buildAlbumArt(Color primaryColor) {
    const size = 55.0;

    final bool isOffline = widget.song['isOffline'] ?? false;
    final String? artworkPath = widget.song['artworkPath'];
    final lowResImageUrl = widget.song['lowResImage'].toString();
    final isDurationAvailable =
        widget.showMusicDuration && widget.song['duration'] != null;

    if (isOffline && artworkPath != null) {
      return _buildOfflineArtwork(artworkPath, size);
    }

    return _buildOnlineArtwork(
      lowResImageUrl,
      size,
      isDurationAvailable,
      primaryColor,
    );
  }

  Widget _buildOfflineArtwork(String artworkPath, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: commonBarRadius,
        child: Image.file(File(artworkPath), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildOnlineArtwork(
    String lowResImageUrl,
    double size,
    bool isDurationAvailable,
    Color primaryColor,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        if (lowResImageUrl.isEmpty)
          Icon(
            FluentIcons.music_note_1_24_filled,
            color: Theme.of(context).colorScheme.primary,
          )
        else
          CachedNetworkImage(
            key: Key(widget.song['ytid'].toString()),
            width: size,
            height: size,
            imageUrl: lowResImageUrl,
            imageBuilder:
                (context, imageProvider) => SizedBox(
                  width: size,
                  height: size,
                  child: ClipRRect(
                    borderRadius: commonBarRadius,
                    child: Image(
                      color:
                          isDurationAvailable
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                      colorBlendMode:
                          isDurationAvailable ? BlendMode.multiply : null,
                      opacity:
                          isDurationAvailable
                              ? const AlwaysStoppedAnimation(0.45)
                              : null,
                      image: imageProvider,
                      centerSlice: const Rect.fromLTRB(1, 1, 1, 1),
                    ),
                  ),
                ),
            errorWidget:
                (context, url, error) =>
                    BaseCard(iconSize: 30, paddingValue: 0, size: size),
          ),
        if (isDurationAvailable)
          SizedBox(
            width: size - 10,
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

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    /* final songLikeStatus = ValueNotifier<bool>(
      isSongAlreadyLiked(widget.song['ytid']),
    );
    final songOfflineStatus = ValueNotifier<bool>(
      isSongAlreadyOffline(widget.song['ytid']),
    ); */

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      icon: Icon(FluentIcons.more_horizontal_24_filled, color: primaryColor),
      onSelected: (String value) {
        switch (value) {
          case 'like':
            songLikeStatus.value = !songLikeStatus.value;
            updateSongLikeStatus(widget.song['ytid'], songLikeStatus.value);
            final likedSongsLength = currentLikedSongsLength.value;
            currentLikedSongsLength.value =
                songLikeStatus.value
                    ? likedSongsLength + 1
                    : likedSongsLength - 1;
            break;
          case 'remove':
            if (widget.onRemove != null) widget.onRemove!();
            break;
          case 'add_to_playlist':
            showAddToPlaylistDialog(context, widget.song);
            break;
          case 'offline':
            if (songOfflineStatus.value) {
              removeSongFromOffline(widget.song['ytid']);
              showToast(context, context.l10n!.songRemovedFromOffline);
            } else {
              makeSongOffline(widget.song);
              showToast(context, context.l10n!.songAddedToOffline);
            }
            songOfflineStatus.value = !songOfflineStatus.value;
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'like',
            child: ValueListenableBuilder<bool>(
              valueListenable: songLikeStatus,
              builder: (_, value, __) {
                return Row(
                  children: [
                    Icon(likeStatusToIconMapper[value], color: primaryColor),
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
                  Icon(FluentIcons.delete_24_filled, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(context.l10n!.removeFromPlaylist),
                ],
              ),
            ),
          PopupMenuItem<String>(
            value: 'add_to_playlist',
            child: Row(
              children: [
                Icon(FluentIcons.add_24_regular, color: primaryColor),
                const SizedBox(width: 8),
                Text(context.l10n!.addToPlaylist),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'offline',
            child: ValueListenableBuilder<bool>(
              valueListenable: songOfflineStatus,
              builder: (_, value, __) {
                return Row(
                  children: [
                    Icon(
                      value
                          ? FluentIcons.cellular_off_24_regular
                          : FluentIcons.cellular_data_1_24_regular,
                      color: primaryColor,
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
        ];
      },
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
                              context,
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
