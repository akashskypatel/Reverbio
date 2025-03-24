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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongList extends StatefulWidget {
  const SongList({
    super.key,
    this.title = '',
    this.icon = FluentIcons.music_note_1_24_regular,
    this.future,
  });

  final IconData icon;
  final String title;
  final Future<dynamic>? future;
  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  dynamic inputData;
  bool isProcessing = true;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.future?.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionHeader(title: widget.title),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayActionButton(),
                _buildAddToQueueActionButton(),
              ],
            ),
          ],
        ),
        FutureBuilder(
          future: widget.future,
          builder: (context, snapshot) {
            if (snapshot.hasData) inputData = snapshot.data;
            return snapshot.hasError
                ? _buildErrorWidget(context)
                : (snapshot.hasData
                    ? _buildRecommendedForYouSection(context)
                    : _buildLoadingWidget());
          },
        ),
      ],
    );
  }

  Widget _buildAddToQueueActionButton() {
    return IconButton(
      //TODO: add "Add to queue" text to localization
      tooltip: context.l10n!.add,
      color: Theme.of(context).colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.add_circle_24_filled),
      iconSize: 30,
      onPressed: () {
        //TODO: add "add to queue" action
      },
    );
  }

  Widget _buildPlayActionButton() {
    return IconButton(
      //TODO: add "Play all" text to localization
      onPressed: () {
        setActivePlaylist({'title': widget.title, 'list': inputData});
      },
      icon: Icon(
        FluentIcons.play_circle_24_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 30,
      ),
    );
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

  Widget _buildRecommendedForYouSection(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: inputData.length,
      padding: commonListViewBottmomPadding,
      itemBuilder: (context, index) {
        final borderRadius = getItemBorderRadius(index, inputData.length);
        return SongBar(inputData[index], true, borderRadius: borderRadius);
      },
    );
  }
}
