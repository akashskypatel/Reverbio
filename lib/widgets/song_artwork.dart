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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/widgets/spinner.dart';

/// R1-R4 fix: SongArtworkWidget with null-safe image handling
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
    // R1 fix: Get artWorkPath with null guard
    final artWorkPath = mediaItem.extras?['artWorkPath'] as String?;
    final isFileImage = mediaItem.artUri?.scheme == 'file' && artWorkPath != null;

    if (isFileImage) {
      // R3 fix: Add errorBuilder to Image.file
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            cacheHeight: (size * 1.1).toInt(),
            cacheWidth: (size * 1.1).toInt(),
            File(artWorkPath),  // R1 fix: Now guaranteed non-null
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // R3 fix: Handle file I/O errors gracefully
              return _buildErrorWidget(context);
            },
          ),
        ),
      );
    } else {
      // R2 fix: Use null-safe toString with fallback
      final imageUrl = mediaItem.artUri?.toString() ?? '';
      
      // R4 fix: Consolidate image resolution - use CachedNetworkImage for all non-file images
      return CachedNetworkImage(
        width: size,
        height: size,
        memCacheHeight: (size * 1.1).toInt(),
        memCacheWidth: (size * 1.1).toInt(),
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) => ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image(image: imageProvider, fit: BoxFit.cover),
        ),
        placeholder: (context, url) => const Spinner(),
        errorWidget: (context, url, error) => _buildErrorWidget(context),
      );
    }
  }

  // R5 fix: Use errorWidgetIconSize parameter
  Widget _buildErrorWidget(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: Theme.of(context).colorScheme.secondary,
        ),
        child: Icon(
          FluentIcons.music_note_1_24_regular,
          color: Theme.of(context).colorScheme.secondaryContainer,
          size: errorWidgetIconSize,  // R5 fix: Wire up parameter
        ),
      ),
    );
  }
}
