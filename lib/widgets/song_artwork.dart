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

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.mediaItem,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });
  final double size;
  final MediaItem mediaItem;
  final double borderRadius;
  final double errorWidgetIconSize;

  @override
  Widget build(BuildContext context) {
    return mediaItem.artUri?.scheme == 'file'
        ? SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(mediaItem.extras?['artWorkPath']),
              fit: BoxFit.cover,
            ),
          ),
        )
        : CachedNetworkImage(
          width: size,
          height: size,
          imageUrl: mediaItem.artUri.toString(),
          imageBuilder:
              (context, imageProvider) => ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image(image: imageProvider, fit: BoxFit.cover),
              ),
          placeholder: (context, url) => const Spinner(),
          errorWidget:
              (context, url, error) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Theme.of(context).colorScheme.secondary,
                ),
                child: Icon(
                  FluentIcons.music_note_1_24_regular,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
        );
  }
}
