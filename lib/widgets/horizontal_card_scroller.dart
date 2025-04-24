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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/playlist_page.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class HorizontalCardScroller extends StatefulWidget {
  const HorizontalCardScroller({
    super.key,
    this.title = '',
    this.icon = FluentIcons.music_note_1_24_regular,
    this.future,
    required this.navigatorObserver,
  });

  final IconData icon;
  final String title;
  final Future<dynamic>? future;
  final RouteObserver<PageRoute> navigatorObserver;

  @override
  State<HorizontalCardScroller> createState() => _HorizontalCardScrollerState();
}

class _HorizontalCardScrollerState extends State<HorizontalCardScroller> {
  dynamic inputData;
  bool isProcessing = true;
  final borderRadius = 13.0;
  late final double playlistHeight =
      MediaQuery.sizeOf(context).height * 0.25 / 1.1;
  late final isLargeScreen = MediaQuery.of(context).size.width > 480;
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
    return Column(
      children: [
        SectionHeader(title: widget.title),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: playlistHeight + (isLargeScreen ? 44 : 60),
          ),
          child: FutureBuilder(
            future: widget.future,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                itemsNumber =
                    snapshot.data.length > recommendedCardsNumber
                        ? recommendedCardsNumber
                        : snapshot.data.length;
                inputData = snapshot.data;
              }
              return snapshot.hasError
                  ? _buildErrorWidget(context)
                  : (snapshot.hasData
                      ? (isLargeScreen
                          ? _buildLargeScreenScroller(context)
                          : _buildSmallScreenScroller(context))
                      : _buildLoadingWidget());
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
      ),
    );
  }

  void _buildCards(BuildContext context) {
    for (final data in inputData) {
      final dataType = _parseDataType(data);
      final isArtist = data['isArtist'] = dataType == 'artist';
      data['isPlaylist'] = dataType == 'playlist';
      if ((data['id'] ?? data['ytid']) != null)
        cards[data['id'] ?? data['ytid']] = BaseCard(
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
                        return ArtistPage(
                          artistData: data,
                          navigatorObserver: widget.navigatorObserver,
                        );
                      default:
                        return PlaylistPage(
                          playlistData: data,
                          navigatorObserver: widget.navigatorObserver,
                        );
                    }
                  },
                ),
              ),
        );
    }
  }

  Widget _buildLargeScreenScroller(BuildContext context) {
    cards.clear();
    _buildCards(context);
    return ScrollConfiguration(
      behavior: CustomScrollBehavior(),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: cards.values.toList(),
      ),
    );
  }

  Widget _buildSmallScreenScroller(BuildContext context) {
    final itemsNumber =
        inputData.length > recommendedCardsNumber
            ? recommendedCardsNumber
            : inputData.length;
    return CarouselView.weighted(
      flexWeights: const <int>[3, 2, 1],
      itemSnapping: true,
      children: List.generate(itemsNumber, (index) {
        final dataType = _parseDataType(inputData[index]);
        final isArtist = inputData[index]['isArtist'] = dataType == 'artist';
        inputData[index]['isPlaylist'] = dataType == 'playlist';
        return BaseCard(
          inputData: inputData[index],
          icon: widget.icon,
          size: playlistHeight,
          showLabel: !isArtist,
          showLike: true,
          showOverflowLabel: true,
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: RouteSettings(
                    name:
                        '$dataType?${inputData[index]['id'] ?? 'yt=${inputData[index]['ytid']}'}',
                  ),
                  builder: (context) {
                    final dataType = _parseDataType(inputData[index]);
                    switch (dataType) {
                      case 'artist':
                        return ArtistPage(
                          artistData: inputData[index],
                          navigatorObserver: widget.navigatorObserver,
                        );
                      default:
                        return PlaylistPage(
                          playlistData: inputData[index],
                          navigatorObserver: widget.navigatorObserver,
                        );
                    }
                  },
                ),
              ),
        );
      }),
    );
  }
}
