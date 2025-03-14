/*
 *     Copyright (C) 2025 Valeri Gokadze
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
 *     please visit: https://github.com/gokadzev/Reverbio
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/widgets/no_artwork_cube.dart';

class ArtistCube extends StatelessWidget {
  ArtistCube(
    this.artist, {
    super.key,
    this.artistData,
    this.cubeIcon = FluentIcons.music_note_1_24_regular,
    this.size = 220,
    this.borderRadius = 13,
  }) : artistLikeStatus = ValueNotifier<bool>(
         isPlaylistAlreadyLiked(artist['ytid']),
       );

  final Map? artistData;
  final Map artist;
  final IconData cubeIcon;
  final double size;
  final double borderRadius;

  static const double paddingValue = 4;
  static const double typeLabelOffset = 10;
  static const double iconSize = 30;

  final ValueNotifier<bool> artistLikeStatus;

  static const likeStatusToIconMapper = {
    true: FluentIcons.heart_24_filled,
    false: FluentIcons.heart_24_regular,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildImage(context),
          if (borderRadius == 13 && artist['image'] != null)
            Positioned(
              top: typeLabelOffset,
              right: typeLabelOffset,
              child: _buildLabel(context),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return artist['image'] != null
        ? CachedNetworkImage(
          key: Key(artist['image'].toString()),
          imageUrl: artist['image'].toString(),
          height: size,
          width: size,
          fit: BoxFit.cover,
          errorWidget:
              (context, url, error) => NullArtworkWidget(
                icon: cubeIcon,
                iconSize: iconSize,
                size: size,
                title: artist['title'],
              ),
        )
        : NullArtworkWidget(
          icon: cubeIcon,
          iconSize: iconSize,
          size: size,
          title: artist['title'],
        );
  }

  Widget _buildLabel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(paddingValue),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        artist['isAlbum'] != null && artist['isAlbum'] == true
            ? context.l10n!.album
            : context.l10n!.playlist,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
