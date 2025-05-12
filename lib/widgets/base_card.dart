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
  });
  final IconData icon;
  final double? iconSize;
  final double size;
  final bool showLabel;
  final bool showOverflowLabel;
  final bool showLike;
  final CachedNetworkImage? image;
  final Map<dynamic, dynamic>? inputData;
  final ValueNotifier<bool> hideNotifier = ValueNotifier(true);
  final VoidCallback? onPressed;
  final double paddingValue;
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
  String? dataType;
  final borderRadius = 13.0;
  late final likeSize =
      widget.iconSize == null ? (widget.size * 0.20) : widget.iconSize;
  late final double artistHeight =
      MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  @override
  void initState() {
    super.initState();
    dataType = _parseDataType();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isLikedNotifier.value = _getLikeStatus();
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.hideNotifier,
      builder:
          (_, value, __) => Visibility(
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
                              borderRadius: BorderRadius.circular(10),
                              color: colorScheme.secondary,
                            ),
                            child: Stack(
                              children: [
                                _buildImage(context),
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

  String _parseImageLink() {
    String link = '';
    if (widget.inputData == null) return link;
    try {
      if (widget.inputData?['image'] != null) link = widget.inputData?['image'];
      if (widget.inputData?['images'] != null && link.isEmpty) {
        final front =
            widget.inputData!['images']
                .where((e) => e['front'] == true)
                .toList();
        if (front.isNotEmpty && link.isEmpty) {
          widget.inputData?['image'] = front.first['image'];
          link = front.first['image'];
        }
        widget.inputData?['image'] = widget.inputData?['images'][0]['image'];
        link = widget.inputData?['images'][0]['image'];
      }
      if (dataType == 'artist' && link.isEmpty) {
        widget.inputData?['image'] = _getPrimaryImageUrl(widget.inputData);
        link = widget.inputData?['image'];
      }
      return link;
    } catch (e, stackTrace) {
      logger.log('error in _parseImageLink', e, stackTrace);
      return '';
    }
  }

  String _getPrimaryImageUrl(dynamic artistData) {
    if (artistData == null ||
        artistData['discogs'] == null ||
        artistData['discogs']['images'] == null)
      return '';
    try {
      final images = List<Map<dynamic, dynamic>>.from(
        artistData['discogs']['images'],
      );
      final primaryImage = images.where((e) => e['type'] == 'primary');
      if (primaryImage.isEmpty) return '';
      return primaryImage.first['uri'] ?? '';
    } catch (e, stackTrace) {
      logger.log('error in _parseImageLink', e, stackTrace);
      return '';
    }
  }

  Widget _buildImage(BuildContext context) {
    final imageLink = _parseImageLink();
    if (widget.inputData != null && imageLink.isNotEmpty) {
      return FutureBuilder(
        future: checkUrl(imageLink),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data! >= 400)
            return _buildNoArtworkCard();
          return _buildArtworkCard(imageLink);
        },
      );
    } else
      return _buildNoArtworkCard();
  }

  Widget _buildArtworkCard(String imageUrl) {
    return CachedNetworkImage(
      key: Key(imageUrl),
      imageUrl: imageUrl,
      height: widget.size,
      width: widget.size,
      fit: BoxFit.cover,
      errorWidget:
          (context, url, error) => BaseCard(
            icon: widget.icon,
            iconSize: likeSize,
            size: widget.size,
          ),
    );
  }

  Widget _buildNoArtworkCard() {
    return Align(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            widget.icon,
            size: likeSize,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
          if (widget.inputData != null)
            Padding(
              padding: EdgeInsets.all(widget.paddingValue),
              child: Text(
                widget.inputData?['artist'] ??
                    widget.inputData?['title'] ??
                    widget.inputData?['name'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiked() {
    return ValueListenableBuilder(
      valueListenable: isLikedNotifier,
      builder: (context, value, child) {
        final liked =
            value
                ? FluentIcons.heart_12_filled
                : FluentIcons.heart_12_regular;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => _toggleLike(context),
              icon: Icon(liked, size: likeSize),
              color: Theme.of(context).colorScheme.primary,
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
        liked = isPlaylistAlreadyLiked(widget.inputData?['id']);
      case 'album':
        if (widget.inputData?['source'] == 'youtube')
          liked = isPlaylistAlreadyLiked(widget.inputData?['id']);
        else
          liked = isAlbumAlreadyLiked(widget.inputData?['id']);
      case 'artist':
        liked = isArtistAlreadyLiked(widget.inputData?['id']);
      default:
        liked = false;
    }
    return liked;
  }

  Widget _buildLabel() {
    const double paddingValue = 4;
    const double typeLabelOffset = 10;
    final colorScheme = Theme.of(context).colorScheme;
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
              : dataType == 'album'
              ? context.l10n!.album
              : dataType?.toTitleCase ?? 'Unknown',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        child: Text(
          widget.inputData == null
              ? ''
              : widget.inputData?['title'] ??
                  widget.inputData?['artist'] ??
                  widget.inputData?['name'],
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 13,
            fontFamily: 'montserrat',
            fontVariations: [const FontVariation('wght', 300)],
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          softWrap: true,
        ),
      ),
    );
  }
}
