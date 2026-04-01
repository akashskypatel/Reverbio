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

// R6 fix: Extract responsive breakpoint to constant
const _responsiveBreakpoint = 480.0;

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
    // R5 fix: Use context.l10n instead of context.l10n!
    // R8 fix: Handle songsLength == 0 edge case
    String buildSubtitle() {
      final l10n = context.l10n;
      if (songsLength == 0) {
        return 'NO SONGS';
      }
      if (albumsLength != null && albumsLength! > 0) {
        return '$songsLength ${l10n?.songs ?? 'Songs'} • $albumsLength ${l10n?.albums ?? 'Albums'}'.toUpperCase();
      }
      return '$songsLength ${l10n?.songs ?? 'Songs'}'.toUpperCase();
    }
    
    // R7 fix: Remove leading underscore from local function names
    List<Widget> buildRowWidgets() {
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
                    buildSubtitle(),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
              : customWidget!,  // R3 fix: Non-null asserted (checked above)
        ),
      ];
    }
    
    // R7 fix: Remove leading underscore from local function names
    List<Widget> buildColumnWidgets() {
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
                  buildSubtitle(),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
            : customWidget!,  // R3 fix: Non-null asserted (checked above)
      ];
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child:
          // R4 fix: Use MediaQuery.sizeOf to avoid unnecessary rebuilds
          // R6 fix: Use extracted constant for responsive breakpoint
          MediaQuery.sizeOf(context).width > _responsiveBreakpoint
              ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: buildRowWidgets(),
              )
              : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: buildColumnWidgets(),
              ),
    );
  }
}
