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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/base_card.dart';

class PlaylistBar extends StatelessWidget {
  PlaylistBar(
    this.playlistTitle, {
    super.key,
    this.playlistId,
    this.playlistArtwork,
    this.playlistData,
    this.onPressed,
    this.onDelete,
    this.cardIcon = FluentIcons.music_note_1_24_filled,
    this.showBuildActions = true,
    this.isAlbum = false,
    this.borderRadius = BorderRadius.zero,
  }) : playlistLikeStatus = ValueNotifier<bool>(
         isPlaylistAlreadyLiked(playlistData),
       );

  final Map? playlistData;
  final String? playlistId;
  final String playlistTitle;
  final String? playlistArtwork;
  final VoidCallback? onPressed;
  final VoidCallback? onDelete;
  final IconData cardIcon;
  final bool? isAlbum;
  final bool showBuildActions;
  final BorderRadius borderRadius;

  static const double artworkSize = 60;
  static const double iconSize = 27;

  final ValueNotifier<bool> playlistLikeStatus;
  final ValueNotifier<bool> hideNotifier = ValueNotifier(true);

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  void setVisibility(bool value) {
    hideNotifier.value = value;
  }

  void hide() {
    setVisibility(false);
  }

  void show() {
    setVisibility(true);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ValueListenableBuilder(
      valueListenable: hideNotifier,
      builder: (context, value, __) {
        return Visibility(
          visible: hideNotifier.value,
          child: Padding(
            padding: commonBarPadding,
            child: GestureDetector(
              onTap:
                  onPressed ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: RouteSettings(
                          name:
                              'playlist?yt=${playlistId ?? playlistData?['id']}',
                        ),
                        builder:
                            (context) => PlaylistPage(
                              page: 'playlist',
                              playlistData:
                                  playlistData ??
                                  {
                                    'title': playlistTitle,
                                    'ytid': playlistId,
                                    'image': playlistArtwork,
                                    'primary-type': 'playlist',
                                  },
                            ),
                      ),
                    );
                  },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: borderRadius),
                margin: const EdgeInsets.only(bottom: 3),
                child: Padding(
                  padding: commonBarContentPadding,
                  child: Row(
                    children: [
                      _buildAlbumArt(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              playlistTitle,
                              overflow: TextOverflow.ellipsis,
                              style: commonBarTitleStyle.copyWith(
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showBuildActions)
                        _buildActionButtons(context, primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt() {
    return BaseCard(
      icon: cardIcon,
      size: artworkSize,
      showIconLabel: false,
      inputData:
          playlistData ??
          {
            'title': playlistTitle,
            'ytid': playlistId,
            'image': playlistArtwork,
            'primary-type': 'playlist',
          },
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      icon: Icon(FluentIcons.more_horizontal_24_filled, color: primaryColor),
      onSelected: (String value) {
        switch (value) {
          case 'like':
            if ((playlistId ?? playlistData?['id']) != null) {
              final newValue = !playlistLikeStatus.value;
              playlistLikeStatus.value = newValue;
              updatePlaylistLikeStatus(
                playlistData ??
                    {
                      'ytid': playlistId,
                      'title': playlistTitle,
                      'image': playlistArtwork,
                      'primary-type': 'playlist',
                    },
                newValue,
              );
            }
            break;
          case 'remove':
            if (onDelete != null) onDelete!();
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          if (onDelete == null)
            PopupMenuItem<String>(
              value: 'like',
              child: Row(
                children: [
                  Icon(
                    likeStatusToIconMapper[playlistLikeStatus.value],
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    playlistLikeStatus.value
                        ? context.l10n!.removeFromLikedPlaylists
                        : context.l10n!.addToLikedPlaylists,
                  ),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem<String>(
              value: 'remove',
              child: Row(
                children: [
                  Icon(FluentIcons.delete_24_filled, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(context.l10n!.deletePlaylist),
                ],
              ),
            ),
        ];
      },
    );
  }
}
