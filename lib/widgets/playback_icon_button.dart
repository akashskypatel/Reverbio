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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';

Widget buildPlaybackIconButton(
  PlaybackState? playerState,
  double iconSize,
  Color iconColor,
  Color backgroundColor,
  BuildContext context, {
  double elevation = 2,
  EdgeInsets padding = const EdgeInsets.all(15),
}) {
  final processingState = playerState?.processingState;
  final isPlaying = playerState?.playing ?? false;

  final iconDataAndAction = getIconFromProcessingState(
    processingState,
    isPlaying,
  );

  return Tooltip(
    message:
        (audioHandler.duration - audioHandler.position).inMilliseconds <= 100
            ? context.l10n!.repeat
            : isPlaying
            ? context.l10n!.pause
            : context.l10n!.play,
    child: RawMaterialButton(
      elevation: elevation,
      onPressed: iconDataAndAction.onPressed,
      fillColor: backgroundColor,
      splashColor: Colors.transparent,
      padding: padding,
      shape: const CircleBorder(),
      child: Icon(iconDataAndAction.iconData, color: iconColor, size: iconSize),
    ),
  );
}

_IconDataAndAction getIconFromProcessingState(
  AudioProcessingState? processingState,
  bool isPlaying,
) {
  switch (processingState) {
    case AudioProcessingState.buffering:
    case AudioProcessingState.loading:
      return _IconDataAndAction(iconData: FluentIcons.spinner_ios_16_filled);
    case AudioProcessingState.completed:
      return _IconDataAndAction(
        iconData:
            (audioHandler.duration - audioHandler.position).inMilliseconds <=
                    100
                ? FluentIcons.arrow_counterclockwise_24_filled
                : isPlaying
                ? FluentIcons.pause_24_filled
                : FluentIcons.play_24_filled,
        onPressed:
            () =>
                (audioHandler.duration - audioHandler.position)
                            .inMilliseconds <=
                        100
                    ? audioHandler.seek(Duration.zero)
                    : isPlaying
                    ? audioHandler.pause()
                    : audioHandler.play(),
      );
    default:
      return _IconDataAndAction(
        iconData:
            isPlaying
                ? FluentIcons.pause_24_filled
                : FluentIcons.play_24_filled,
        onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
      );
  }
}

class _IconDataAndAction {
  _IconDataAndAction({required this.iconData, this.onPressed});
  final IconData iconData;
  final VoidCallback? onPressed;
}
