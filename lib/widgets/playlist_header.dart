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

class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader(
    this.image,
    this.title,
    this.songsLength, {
    super.key,
    this.customWidget,
    this.albumsLength,
  });

  final Widget image;
  final String title;
  final int songsLength;
  final int? albumsLength;
  final Widget? customWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // R1/R2 fix: Build subtitle with proper separator
    String _buildSubtitle() {
      if (albumsLength != null && albumsLength! > 0) {
        return '$songsLength ${context.l10n!.songs} • $albumsLength ${context.l10n!.albums}'.toUpperCase();
      }
      return '$songsLength ${context.l10n!.songs}'.toUpperCase();
    }
    
    // R1 fix: Separate widget builders for Row and Column to avoid spacer issues
    List<Widget> _buildRowWidgets() {
      return [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        const SizedBox(width: 16),
        Flexible(
          child: customWidget == null
              ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildSubtitle(),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
              : customWidget ?? const SizedBox.shrink(),
        ),
      ];
    }
    
    List<Widget> _buildColumnWidgets() {
      return [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        const SizedBox(height: 16),
        customWidget == null
            ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _buildSubtitle(),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
            : customWidget ?? const SizedBox.shrink(),
      ];
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child:
          MediaQuery.of(context).size.width > 480
              ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: _buildRowWidgets(),
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: _buildColumnWidgets(),
              ),
    );
  }
}
