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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class HorizontalCardScroller extends StatefulWidget {
  const HorizontalCardScroller({
    super.key,
    this.title = '',
    this.icon = FluentIcons.music_note_1_24_regular,
    this.future,
    this.headerActions,
    this.actionsExpanded = true,
  });

  final IconData icon;
  final String title;
  final Future<dynamic>? future;
  final List<Widget>? headerActions;
  final bool actionsExpanded;
  @override
  State<HorizontalCardScroller> createState() => _HorizontalCardScrollerState();
}

class _HorizontalCardScrollerState extends State<HorizontalCardScroller> {
  dynamic inputData;
  bool isProcessing = true;
  final borderRadius = 13.0;
  late double playlistHeight = MediaQuery.sizeOf(context).height;
  late ThemeData _theme;
  int itemsNumber = recommendedCardsNumber;
  final Map<String, BaseCard> cards = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.future?.ignore();
    cards.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;
    return Column(
      children: [
        SectionHeader(
          title: widget.title,
          actions: widget.headerActions,
          actionsExpanded: widget.actionsExpanded,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: playlistHeight + (isLargeScreen() ? 44 : 60),
          ),
          child: FutureBuilder(
            future: widget.future,
            builder: (context, snapshot) {
              try {
                final dataLength = snapshot.hasData ? snapshot.data.length : 0;
                itemsNumber =
                    dataLength > recommendedCardsNumber
                        ? recommendedCardsNumber
                        : dataLength;
                inputData = snapshot.data;
                return snapshot.hasError
                    ? _buildErrorWidget(context)
                    : snapshot.connectionState == ConnectionState.waiting
                    ? _buildLoadingWidget()
                    : isLargeScreen()
                    ? _buildLargeScreenScroller(context)
                    : _buildSmallScreenScroller(context);
              } catch (e, stackTrace) {
                logger.log('Error in horizontal card scroller', e, stackTrace);
                return _buildErrorWidget(context);
              }
            },
          ),
        ),
      ],
    );
  }

  String? _parseDataType(dynamic data) {
    if (data == null) return null;
    if (data['primary-type'] != null)
      return data['primary-type'].toString().toLowerCase();
    return null;
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Text(
        '${context.l10n!.error}!',
        style: TextStyle(color: _theme.colorScheme.primary, fontSize: 18),
      ),
    );
  }

  BaseCard _buildCard(dynamic data) {
    final dataType = _parseDataType(data);
    final isArtist = data['isArtist'] = dataType == 'artist';
    data['isPlaylist'] = dataType == 'playlist';
    return BaseCard(
      inputData: data,
      icon: widget.icon,
      size: playlistHeight,
      showLabel: !isArtist,
      showOverflowLabel: true,
      showLike: true,
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: RouteSettings(
                name: '$dataType?${data['id'] ?? 'yt=${data['ytid']}'}',
              ),
              builder: (context) {
                switch (dataType) {
                  case 'artist':
                    return ArtistPage(page: 'artist', artistData: data);
                  default:
                    return PlaylistPage(
                      page: dataType ?? '',
                      playlistData: data,
                    );
                }
              },
            ),
          ),
    );
  }

  List<BaseCard> _buildCards(BuildContext context) {
    cards.clear();
    for (final data in inputData) {
      if ((data['id'] ?? data['ytid']) != null)
        cards[data['id'] ?? data['ytid']] = _buildCard(data);
    }
    final cardValues =
        cards.values.toList()..sort((a, b) {
          if (a.inputData != null && b.inputData != null)
            if (_parseDataType(a.inputData) == 'album' &&
                _parseDataType(b.inputData) == 'album')
              return (tryParseDate(
                    a.inputData?['first-release-date'],
                  ).millisecondsSinceEpoch) -
                  (tryParseDate(
                    b.inputData?['first-release-date'],
                  ).millisecondsSinceEpoch);
          return 0;
        });
    return cardValues;
  }

  Widget _buildLargeScreenScroller(BuildContext context) {
    final cardValues = _buildCards(context);
    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            scrollDirection: Axis.horizontal,
            children: cardValues,
          );
        },
      ),
    );
  }

  Widget _buildSmallScreenScroller(BuildContext context) {
    final cardValues = _buildCards(context);
    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: CarouselView.weighted(
        flexWeights: const <int>[3, 2, 1],
        itemSnapping: true,
        onTap: (value) => cardValues[value].onPressed?.call(),
        children: cardValues,
      ),
    );
  }
}
