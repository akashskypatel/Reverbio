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

import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/entities.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/formatter.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/animated_heart.dart';
import 'package:reverbio/widgets/spinner.dart';

class BaseCard extends StatefulWidget {
  BaseCard({
    super.key,
    this.icon = FluentIcons.music_note_1_24_regular,
    this.size = 220,
    this.iconSize,
    this.image,
    this.inputData,
    this.label,
    this.showOverflowLabel = false,
    this.showLike = false,
    this.onPressed,
    this.paddingValue = 8,
    this.loadingWidget,
    this.duration,
    //this.imageOverlayMask = false,
    this.showIconLabel = true,
    this.customButton,
  });
  final IconData icon;
  final double? iconSize;
  final int? duration;
  final double size;
  final String? label;
  final bool showOverflowLabel;
  final bool showLike;
  final bool showIconLabel;
  final Image? image;
  //final bool imageOverlayMask;
  final Map<dynamic, dynamic>? inputData;
  final ValueNotifier<bool> hideNotifier = ValueNotifier(true);
  final VoidCallback? onPressed;
  final double paddingValue;
  final Widget? loadingWidget;
  final IconButton? customButton;

  static const double typeLabelOffset = 10;
  @override
  State<BaseCard> createState() => _BaseCardState();

  void setVisibility(bool value) {
    hideNotifier.value = value;
  }

  void hide() {
    setVisibility(false);
  }

  void show() {
    setVisibility(true);
  }
}

class _BaseCardState extends State<BaseCard> {
  Future<dynamic>? _fetchingDataFuture;

  String? dataType;
  final borderRadius = 13.0;
  late final buttonSize = widget.size * 0.20;
  late final double artistHeight =
      MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late ThemeData _theme;
  @override
  void initState() {
    super.initState();
    dataType = _parseDataType();
    _fetchingDataFuture = _getUpdatedDate();
    unawaited(
      _fetchingDataFuture?.then((data) {
        if (mounted)
          setState(() {
            widget.inputData?.addAll(copyMap(data));
            dataType = _parseDataType();
          });
      }),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  dynamic _getUpdatedDate() {
    if ((widget.inputData?['id'] != null &&
            (widget.inputData?['title'] ??
                    widget.inputData?['name'] ??
                    widget.inputData?['artist']) ==
                null) ||
        ([
              'artist',
              'album',
              'single',
              'ep',
              'broadcast',
              'other',
            ].contains(widget.inputData?['primary-type']?.toLowerCase()) &&
            widget.inputData?['musicbrainz'] == null))
      switch (dataType) {
        case 'playlist':
          return getPlaylistInfoForWidget(widget.inputData);
        case 'artist':
          return getArtistDetails(widget.inputData);
        case 'album':
        case 'single':
        case 'ep':
        case 'broadcast':
        case 'other':
          return queueAlbumInfoRequest(widget.inputData).completerFuture;
        default:
      }
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final colorScheme = _theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.hideNotifier,
      builder:
          (context, value, __) => Visibility(
            visible: value,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.paddingValue),
              child: SizedBox(
                width: widget.size,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onDoubleTapDown:
                          (details) => _toggleLike(context, details: details),
                      onTap: () {
                        if (widget.onPressed != null) widget.onPressed!();
                      },
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(borderRadius),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          width: widget.size,
                          height: widget.size,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(borderRadius),
                              color: colorScheme.secondary,
                              backgroundBlendMode:
                                  (widget.duration != null &&
                                          widget.duration! > 0)
                                      ? BlendMode.multiply
                                      : null,
                            ),
                            child: Stack(
                              alignment: AlignmentDirectional.center,
                              children: [
                                if (mounted) _buildImage(context),
                                if (widget.label != null) _buildLabel(),
                                if (widget.showLike) _buildLiked(),
                                if (!widget.showLike &&
                                    widget.customButton != null)
                                  _buildCustomButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showOverflowLabel) _buildOverflowLabel(context),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  String? _parseDataType() {
    if (widget.inputData?['primary-type'] != null)
      return widget.inputData?['primary-type'].toString().toLowerCase();
    return null;
  }

  Widget _buildImage(BuildContext context) {
    return FutureBuilder(
      initialData: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          if (widget.loadingWidget == null)
            SizedBox.square(
              dimension: widget.size * .50,
              child: const Spinner(),
            )
          else
            SizedBox.square(
              dimension: widget.size * .50,
              child: widget.loadingWidget,
            ),
          if (widget.duration != null && widget.duration! > 0)
            SizedBox(
              width: 45,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '(${formatDuration(widget.duration!)})',
                  style: TextStyle(
                    color: _theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      future: _getImage(context),
      builder: (context, snapshot) {
        Widget? _widget;
        if (snapshot.connectionState == ConnectionState.none ||
            snapshot.hasError ||
            snapshot.data == null) {
          _widget = _buildNoArtworkCard(context);
        }
        _widget = snapshot.data;
        return Stack(
          alignment: AlignmentDirectional.center,
          children: <Widget>[
            _widget!,
            if (widget.duration != null && widget.duration! > 0)
              SizedBox(
                width: 45,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '(${formatDuration(widget.duration!)})',
                    style: TextStyle(
                      color: _theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<Widget> _getImage(BuildContext context) async {
    try {
      if (widget.image != null)
        return widget.image!.copyWith(
          color:
              (widget.duration != null && widget.duration! > 0)
                  ? _theme.colorScheme.primaryContainer
                  : null,
          colorBlendMode:
              (widget.duration != null && widget.duration! > 0)
                  ? BlendMode.multiply
                  : null,
          opacity:
              (widget.duration != null && widget.duration! > 0)
                  ? const AlwaysStoppedAnimation(0.45)
                  : null,
        );
      final image = await getValidImage(widget.inputData);
      if (image == null) return _buildNoArtworkCard(context);
      if (image.isFileUri && doesFileExist(image.toString())) {
        return _buildFileArtworkCard(image.toFilePath(), context);
      } else if (await checkUrl(image.toString()) <= 300)
        return _buildOnlineArtworkCard(image, context);
      return _buildNoArtworkCard(context);
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}',
        e,
        stackTrace,
      );
      return _buildNoArtworkCard(context);
    }
  }

  Widget _buildFileArtworkCard(String path, BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, __, ___) => _buildNoArtworkCard(context),
          color:
              (widget.duration != null && widget.duration! > 0)
                  ? _theme.colorScheme.primaryContainer
                  : null,
          colorBlendMode:
              (widget.duration != null && widget.duration! > 0)
                  ? BlendMode.multiply
                  : null,
          opacity:
              (widget.duration != null && widget.duration! > 0)
                  ? const AlwaysStoppedAnimation(0.45)
                  : null,
        ),
      ),
    );
  }

  Widget _buildOnlineArtworkCard(Uri imageUrl, BuildContext context) {
    return CachedNetworkImage(
      key: Key(imageUrl.toString()),
      imageUrl: imageUrl.toString(),
      height: widget.size,
      width: widget.size,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Spinner(),
      errorWidget: (context, url, error) => _buildNoArtworkCard(context),
      color:
          (widget.duration != null && widget.duration! > 0)
              ? _theme.colorScheme.primaryContainer
              : null,
      colorBlendMode:
          (widget.duration != null && widget.duration! > 0)
              ? BlendMode.multiply
              : null,
    );
  }

  Widget _buildNoArtworkCard(BuildContext context) {
    if (widget.image != null)
      return widget.image!.copyWith(
        color:
            (widget.duration != null && widget.duration! > 0)
                ? _theme.colorScheme.primaryContainer
                : null,
        colorBlendMode:
            (widget.duration != null && widget.duration! > 0)
                ? BlendMode.multiply
                : null,
        opacity:
            (widget.duration != null && widget.duration! > 0)
                ? const AlwaysStoppedAnimation(0.45)
                : null,
      );
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                widget.icon,
                size:
                    widget.showIconLabel
                        ? widget.size * .25
                        : widget.size * .45,
                color: _theme.colorScheme.onSecondary,
              ),
              if (widget.inputData != null && widget.showIconLabel)
                Padding(
                  padding: EdgeInsets.all(widget.paddingValue),
                  child: Text(
                    widget.inputData?['artist'] ??
                        widget.inputData?['title'] ??
                        widget.inputData?['name'] ??
                        widget.inputData?['value'] ??
                        '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _theme.colorScheme.onSecondary,
                      fontSize: widget.size * .1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomButton() {
    if (widget.customButton == null) return const SizedBox.shrink();
    final _customButton = widget.customButton!;
    final shadowOffset = -(buttonSize / 18);
    return Align(
      alignment: Alignment.topRight,
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(shadowOffset + (shadowOffset * .5), shadowOffset),
            child: IconButton(
              onPressed: null,
              icon: Icon(
                (_customButton.icon as Icon).icon,
                size: _customButton.iconSize ?? buttonSize,
                color: _theme.colorScheme.surface,
              ),
            ),
          ),
          IconButton(
            onPressed: _customButton.onPressed,
            icon: Icon(
              (_customButton.icon as Icon).icon,
              size: _customButton.iconSize ?? buttonSize,
            ),
            color: _theme.colorScheme.primary,
            hoverColor: _theme.colorScheme.surface.withAlpha(128),
          ),
        ],
      ),
    );
  }

  Widget _buildLiked() {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListenableBuilder(
          listenable: _getLikeNotifier(),
          builder: (context, child) {
            return FutureBuilder(
              future: Future.microtask(_getLikeStatus),
              builder: (context, snapshot) {
                bool value = false;
                if (!snapshot.hasError &&
                    snapshot.hasData &&
                    snapshot.data != null &&
                    snapshot.connectionState != ConnectionState.waiting)
                  value = snapshot.data!;
                final liked =
                    value
                        ? FluentIcons.heart_12_filled
                        : FluentIcons.heart_12_regular;
                final shadowOffset = -(buttonSize / 18);
                return Align(
                  alignment: Alignment.topRight,
                  child: Stack(
                    children: [
                      Transform.translate(
                        offset: Offset(
                          shadowOffset + (shadowOffset * .5),
                          shadowOffset,
                        ),
                        child: IconButton(
                          onPressed: null,
                          icon: Icon(
                            liked,
                            size: buttonSize,
                            color: _theme.colorScheme.surface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _toggleLike(context);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(liked, size: buttonSize),
                        color: _theme.colorScheme.primary,
                        hoverColor: _theme.colorScheme.surface.withAlpha(128),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Listenable _getLikeNotifier() {
    switch (dataType) {
      case 'playlist':
        return userLikedPlaylists;
      case 'album':
      case 'single':
      case 'ep':
      case 'broadcast':
      case 'other':
        return userLikedAlbumsList;
      case 'artist':
        return userLikedArtistsList;
      default:
        return ValueNotifier(0);
    }
  }

  void _toggleLike(BuildContext context, {TapDownDetails? details}) async {
    final liked = await _updateLikeStatus();
    if (details != null)
      AnimatedHeart.show(context: context, details: details, like: liked);
  }

  Future<bool> _updateLikeStatus() async {
    final liked = _getLikeStatus();
    switch (dataType) {
      case 'playlist':
        await updatePlaylistLikeStatus(widget.inputData, !liked);
      case 'album':
      case 'single':
      case 'ep':
      case 'broadcast':
      case 'other':
        await updateAlbumLikeStatus(widget.inputData, !liked);
      case 'artist':
        await updateArtistLikeStatus(widget.inputData, !liked);
      default:
        return liked;
    }
    return _getLikeStatus();
  }

  bool _getLikeStatus() {
    var liked = false;
    switch (dataType) {
      case 'playlist':
        liked = isPlaylistAlreadyLiked(widget.inputData);
      case 'album':
      case 'single':
      case 'ep':
      case 'broadcast':
      case 'other':
        if (widget.inputData?['source'] == 'youtube')
          liked = isPlaylistAlreadyLiked(widget.inputData);
        else
          liked = isAlbumAlreadyLiked(widget.inputData);
      case 'artist':
        liked = isArtistAlreadyLiked(widget.inputData);
      default:
        liked = false;
    }
    return liked;
  }

  Widget _buildLabel() {
    const double paddingValue = 4;
    const double typeLabelOffset = 10;
    final colorScheme = _theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: typeLabelOffset,
        vertical: typeLabelOffset,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(paddingValue),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          overflow: TextOverflow.ellipsis,
          widget.label!, //_labelType(),
          style: _theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  String _labelType() {
    switch (dataType) {
      case 'artist':
        return context.l10n!.artist;
      case 'playlist':
        return context.l10n!.playlist;
      case 'album':
        return context.l10n!.album;
      case 'single':
        return context.l10n!.single;
      case 'ep':
        return context.l10n!.extendedPlay;
      case 'broadcast':
        return context.l10n!.broadcast;
      case 'other':
        return context.l10n!.other;
      default:
        return context.l10n!.other;
    }
  }

  Widget _buildOverflowLabel(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: artistHeight, minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          children: [
            Text(
              widget.inputData == null ? '' : _getCardTitle(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _theme.colorScheme.secondary,
                fontSize: 13,
                fontFamily: 'montserrat',
                fontVariations: [const FontVariation('wght', 300)],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: _getCardSubTitle().isEmpty ? 2 : 1,
              softWrap: true,
            ),
            if (_getCardSubTitle().isNotEmpty)
              Text(
                widget.inputData == null ? '' : _getCardSubTitle(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _theme.colorScheme.secondary,
                  fontSize: 13,
                  fontFamily: 'montserrat',
                  fontVariations: [const FontVariation('wght', 300)],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: true,
              ),
          ],
        ),
      ),
    );
  }

  String _getCardTitle() {
    return widget.inputData?['title'] ??
        widget.inputData?['artist'] ??
        widget.inputData?['name'] ??
        widget.inputData?['value'] ??
        '';
  }

  String _getCardSubTitle() {
    String title = '';
    if (widget.inputData?['first-release-date'] != null)
      title =
          '(${tryParseDate(widget.inputData?['first-release-date']).year}${tryParseDate(widget.inputData?['first-release-date']).isAfter(DateTime.now()) ? ' ${context.l10n!.upcoming})' : ')'}';
    else
      title = '';
    return title;
  }
}
