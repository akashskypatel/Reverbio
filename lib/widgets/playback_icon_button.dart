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
import 'package:reverbio/widgets/spinner.dart';

Widget buildIconDataButton(
  double iconSize,
  Color iconColor,
  Color backgroundColor,
  BuildContext context, {
  String? tooltip,
  PlaybackState? playerState,
  Color? hoverColor,
  IconDataAndAction? icon,
  double elevation = 2,
  EdgeInsets padding = const EdgeInsets.all(15),
}) {
  final processingState = playerState?.processingState;
  final isPlaying = playerState?.playing ?? false;

  final iconDataAndAction =
      icon ??
      getIconFromProcessingState(
        processingState,
        isPlaying,
        iconColor,
        size: iconSize,
      );
  tooltip =
      tooltip ??
      ((audioHandler.duration - audioHandler.position).inMilliseconds <= 100
          ? context.l10n!.repeat
          : isPlaying
          ? context.l10n!.pause
          : context.l10n!.play);
  return Tooltip(
    waitDuration: const Duration(milliseconds: 1500),
    message: tooltip,
    child: SizedBox.square(
      dimension: iconSize + padding.horizontal,
      child: RawMaterialButton(
        elevation: elevation,
        onPressed: iconDataAndAction.onPressed,
        fillColor: backgroundColor,
        hoverColor: hoverColor,
        splashColor: Colors.transparent,
        padding: padding,
        shape: const CircleBorder(),
        child: iconDataAndAction.iconData,
      ),
    ),
  );
}

IconDataAndAction getIconFromProcessingState(
  AudioProcessingState? processingState,
  bool isPlaying,
  Color iconColor, {
  double size = 35,
}) {
  Widget playIcon() => SizedBox.square(
    dimension: size,
    child: Icon(FluentIcons.play_24_filled, size: size, color: iconColor),
  );
  Widget pauseIcon() => SizedBox.square(
    dimension: size,
    child: Icon(FluentIcons.pause_24_filled, size: size, color: iconColor),
  );
  Widget replayIcon() => SizedBox.square(
    dimension: size,
    child: Icon(
      FluentIcons.arrow_counterclockwise_24_filled,
      size: size,
      color: iconColor,
    ),
  );
  Widget spinner() => SizedBox.square(dimension: size, child: const Spinner());
  IconDataAndAction playOrPause() => IconDataAndAction(
    iconData:
        (audioHandler.duration - audioHandler.position).inMilliseconds <= 100 &&
                (audioHandler.duration.inMilliseconds >= 100)
            ? replayIcon()
            : isPlaying
            ? pauseIcon()
            : playIcon(),
    onPressed:
        () =>
            (audioHandler.duration - audioHandler.position).inMilliseconds <=
                        100 &&
                    (audioHandler.duration.inMilliseconds >= 100)
                ? audioHandler.seek(Duration.zero)
                : isPlaying
                ? audioHandler.pause()
                : audioHandler.play(),
  );
  switch (processingState) {
    case AudioProcessingState.buffering:
    case AudioProcessingState.loading:
      return IconDataAndAction(iconData: spinner());
    default:
      return playOrPause();
  }
}

class IconDataAndAction {
  IconDataAndAction({required this.iconData, this.onPressed});
  final Widget iconData;
  final VoidCallback? onPressed;
}
