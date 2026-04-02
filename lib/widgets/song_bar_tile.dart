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
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/audio_tags.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/marque.dart';
import 'package:reverbio/widgets/spinner.dart';
import 'package:reverbio/utilities/file_tagger.dart';

/// SongBarTile - Pure display widget for song tile layout
/// Extracted from SongBar as part of barrel split (A2)
class SongBarTile extends StatelessWidget {
  const SongBarTile({
    super.key,
    required this.song,
    required this.isLoading,
    required this.status,
    this.backgroundColor,
    required this.primaryColor,
    required this.theme,
    this.songTagFuture,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
  });

  final dynamic song;
  final bool isLoading;
  final int status;
  final Color? backgroundColor;
  final Color primaryColor;
  final ThemeData theme;
  final Future<Tag?>? songTagFuture;
  final VoidCallback? onTap;
  final GestureTapCallback? onDoubleTap;
  final GestureTapCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final title = songTitle(song).nullIfEmpty;
    final artist = (combineArtists(song) ?? songArtist(song)).nullIfEmpty;

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      margin: const EdgeInsets.only(bottom: 3),
      child: Padding(
        padding: commonBarContentPadding,
        child: Row(
          children: [
            _buildArtwork(context),
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
                                        : context.l10n!.unknown),
                                overflow: TextOverflow.ellipsis,
                                style: commonBarTitleStyle.copyWith(
                                  color: primaryColor,
                                ),
                              ),
                              if (isSongAlreadyOffline(song))
                                Padding(
                                  padding: const EdgeInsetsGeometry.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Icon(
                                    FluentIcons.arrow_download_24_filled,
                                    size: 14,
                                    color: theme.colorScheme.primary,
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
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildStatusWidget(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    const size = 45.0;
    return FutureBuilder<Tag?>(
      future: songTagFuture ?? FileTagger().getTagFromFileOrMetadata(song),
      builder: (context, snapshot) {
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
              child: Spinner(color: theme.colorScheme.onSecondary),
            ),
            duration: song['duration'],
            showIconLabel: false,
          );
        }
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
            child: Spinner(color: theme.colorScheme.onSecondary),
          ),
          duration: song['duration'],
          showIconLabel: false,
        );
      },
    );
  }

  Widget _buildStatusWidget(BuildContext context) {
    if (isLoading) {
      return _buildLoadingSpinner(context);
    }
    switch (status) {
      case 0:
        return const SizedBox.shrink();
      case 1:
        return _buildLoadingSpinner(context);
      case 3:
        return _buildErrorIconWidget(context);
      default:
        return const SizedBox.shrink();
    }
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
        color: theme.colorScheme.primary,
      ),
    );
  }
}
