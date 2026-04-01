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

import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';

class ArtistHeader extends StatelessWidget {
  const ArtistHeader(
    this.image,
    this.title, {
    super.key,
    this.songsLength = 0,
    this.albumsLength = 0,
  });

  final Widget image;
  final String title;
  final int songsLength;
  final int albumsLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    // R3 fix: Add responsive layout with breakpoint
    final isWide = MediaQuery.sizeOf(context).width > 600;
    // R4 fix: Use textTheme.headlineLarge instead of hardcoded fontSize: 40
    // R5 fix: Conditionally hide subtitle when empty
    final hasSongs = songsLength > 0;
    final hasAlbums = albumsLength > 0;
    // R1 fix: Add • separator between song count and album count
    String subTitle;
    if (hasSongs && hasAlbums) {
      subTitle = '$songsLength ${context.l10n!.songs} • $albumsLength ${context.l10n!.albums}';
    } else if (hasSongs) {
      subTitle = '$songsLength ${context.l10n!.songs}';
    } else if (hasAlbums) {
      subTitle = '$albumsLength ${context.l10n!.albums}';
    } else {
      subTitle = '';
    }
    
    // R6 fix: Use Flexible instead of Expanded for better layout behavior
    final textContent = Flexible(
      child: Column(
        children: [
          Text(
            title,
            style: textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ) ?? textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              fontSize: 40,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
          if (hasSongs || hasAlbums) ...[
            const SizedBox(height: 8),
            Text(
              subTitle.toUpperCase(),
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
    
    return Padding(
      padding: const EdgeInsets.all(6),
      child: isWide
          ? Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
                const SizedBox(width: 16),
                textContent,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
                const SizedBox(height: 16),
                textContent,
              ],
            ),
    );
  }
}
