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
import 'package:flutter/material.dart';
import 'package:reverbio/widgets/no_artwork_cube.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongArtworkWidget extends StatelessWidget {
  const SongArtworkWidget({
    super.key,
    required this.size,
    required this.metadata,
    this.borderRadius = 10.0,
    this.errorWidgetIconSize = 20.0,
  });
  final double size;
  final MediaItem metadata;
  final double borderRadius;
  final double errorWidgetIconSize;

  @override
  Widget build(BuildContext context) {
    return metadata.artUri?.scheme == 'file'
        ? SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(metadata.extras?['artWorkPath']),
              fit: BoxFit.cover,
            ),
          ),
        )
        : CachedNetworkImage(
          width: size,
          height: size,
          imageUrl: metadata.artUri.toString(),
          imageBuilder:
              (context, imageProvider) => ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Image(image: imageProvider, fit: BoxFit.cover),
              ),
          placeholder: (context, url) => const Spinner(),
          errorWidget:
              (context, url, error) =>
                  NullArtworkWidget(iconSize: errorWidgetIconSize),
        );
  }
}
