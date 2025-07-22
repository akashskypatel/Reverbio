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

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/album.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/spinner.dart';

class BaseCard extends StatefulWidget {
  BaseCard({
    super.key,
    this.icon = FluentIcons.music_note_1_24_regular,
    this.size = 220,
    this.iconSize,
    this.image,
    this.inputData,
    this.showLabel = false,
    this.showOverflowLabel = false,
    this.showLike = false,
    this.onPressed,
    this.paddingValue = 8,
    this.loadingWidget,
    this.imageOverlayMask = false,
    this.showIconLabel = true,
  });
  final IconData icon;
  final double? iconSize;
  final double size;
  final bool showLabel;
  final bool showOverflowLabel;
  final bool showLike;
  final bool showIconLabel;
  final CachedNetworkImage? image;
  final bool imageOverlayMask;
  final Map<dynamic, dynamic>? inputData;
  final ValueNotifier<bool> hideNotifier = ValueNotifier(true);
  final VoidCallback? onPressed;
  final double paddingValue;
  final Widget? loadingWidget;
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
  late ValueNotifier<bool> isLikedNotifier = ValueNotifier(_getLikeStatus());
  Future<dynamic>? _fetchingDataFuture;

  String? dataType;
  final borderRadius = 13.0;
  late final likeSize =
      widget.iconSize == null ? (widget.size * 0.20) : widget.iconSize;
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
            widget.inputData?.addAll(Map<String, dynamic>.from(data));
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
          return getAlbumDetailsById(widget.inputData);
        default:
      }
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    isLikedNotifier.value = _getLikeStatus();
    final colorScheme = _theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.hideNotifier,
      builder:
          (context, value, __) => Visibility(
            visible: value,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.paddingValue),
              child: GestureDetector(
                onTap: widget.onPressed,
                child: SizedBox(
                  width: widget.size,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
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
                            ),
                            child: Stack(
                              children: [
                                if (mounted)
                                  FutureBuilder(
                                    initialData:
                                        widget.loadingWidget != null
                                            ? SizedBox(
                                              width: widget.size,
                                              height: widget.size,
                                              child: widget.loadingWidget,
                                            )
                                            : _buildNoArtworkCard(context),
                                    future: _buildImage(context),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                              ConnectionState.none ||
                                          snapshot.hasError ||
                                          snapshot.data == null) {
                                        if (widget.loadingWidget != null)
                                          return SizedBox(
                                            width: widget.size,
                                            height: widget.size,
                                            child: widget.loadingWidget,
                                          );
                                        return _buildNoArtworkCard(context);
                                      }
                                      return snapshot.data!;
                                    },
                                  ),
                                if (widget.showLabel) _buildLabel(),
                                if (widget.showLike) _buildLiked(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.showOverflowLabel)
                        _buildOverflowLabel(context),
                    ],
                  ),
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

  Future<Widget> _buildImage(BuildContext context) async {
    try {
      final images = parseImage(widget.inputData) ?? [];
      if (images.isEmpty) return _buildNoArtworkCard(context);
      for (final path in images) {
        if (isFilePath(path) && doesFileExist(path)) return _buildFileArtworkCard(path, context);
        final imageUrl = Uri.parse(path);
        if (await checkUrl(imageUrl.toString()) <= 300)
          return _buildOnilneArtworkCard(imageUrl, context);
      }
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
              widget.imageOverlayMask
                  ? _theme.colorScheme.primaryContainer
                  : null,
          colorBlendMode: widget.imageOverlayMask ? BlendMode.multiply : null,
          opacity:
              widget.imageOverlayMask
                  ? const AlwaysStoppedAnimation(0.45)
                  : null,
        ),
      ),
    );
  }

  Widget _buildOnilneArtworkCard(Uri imageUrl, BuildContext context) {
    return CachedNetworkImage(
      key: Key(imageUrl.toString()),
      imageUrl: imageUrl.toString(),
      height: widget.size,
      width: widget.size,
      fit: BoxFit.cover,
      placeholder: (context, url) => const Spinner(),
      errorWidget: (context, url, error) => _buildNoArtworkCard(context),
      color:
          widget.imageOverlayMask ? _theme.colorScheme.primaryContainer : null,
      colorBlendMode: widget.imageOverlayMask ? BlendMode.multiply : null,
    );
  }

  Widget _buildNoArtworkCard(BuildContext context) {
    return Stack(
      children: [
        if (widget.imageOverlayMask)
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: ClipRRect(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.8,
                ), // Translucent overlay
              ),
            ),
          ),
        Align(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            direction: Axis.vertical,
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

  Widget _buildLiked() {
    return ValueListenableBuilder(
      valueListenable: isLikedNotifier,
      builder: (context, value, child) {
        final liked =
            value ? FluentIcons.heart_12_filled : FluentIcons.heart_12_regular;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
          child: Align(
            alignment: Alignment.topRight,
            child: Stack(
              children: [
                Transform.translate(
                  offset: const Offset(5.5, 6.5),
                  child: Icon(
                    liked,
                    size: likeSize,
                    color: _theme.colorScheme.surface,
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleLike(context),
                  icon: Icon(liked, size: likeSize),
                  color: _theme.colorScheme.primary,
                  hoverColor: _theme.colorScheme.surface.withAlpha(128),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleLike(BuildContext context) async {
    final liked = await _updateLikeStatus();
    isLikedNotifier.value = liked;
  }

  Future<bool> _updateLikeStatus() async {
    switch (dataType) {
      case 'playlist':
        return updatePlaylistLikeStatus(
          widget.inputData,
          !isLikedNotifier.value,
        );
      case 'album':
      case 'single':
      case 'ep':
      case 'broadcast':
      case 'other':
        if (widget.inputData?['source'] == 'youtube')
          return updatePlaylistLikeStatus(
            widget.inputData,
            !isLikedNotifier.value,
          );
        else
          return updateAlbumLikeStatus(
            widget.inputData,
            !isLikedNotifier.value,
          );
      case 'artist':
        return updateArtistLikeStatus(widget.inputData, !isLikedNotifier.value);
      default:
        return false;
    }
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
          dataType == 'artist'
              ? ''
              : dataType == 'playlist'
              ? context.l10n!.playlist
              : [
                'album',
                'single',
                'ep',
                'broadcast',
                'other',
              ].contains(dataType)
              ? context.l10n!.album
              : dataType?.toTitleCase ?? 'Unknown',
          style: _theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
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
          '(${tryParseDate(widget.inputData?['first-release-date']).year}${tryParseDate(widget.inputData?['first-release-date']).isAfter(DateTime.now()) ? ' upcoming)' : ')'}';
    else
      title = '';
    return title;
  }
}
