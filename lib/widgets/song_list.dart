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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/notifiable_list.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongList extends StatefulWidget {
  SongList({
    super.key,
    required this.page,
    this.title = '',
    this.icon = FluentIcons.music_note_1_24_regular,
    required this.songBars,
    this.expandedActions,
    this.isEditable = false,
  });

  final IconData icon;
  final String title;
  final String page;
  final NotifiableList<SongBar> songBars;
  final bool isEditable;
  final List<Widget>? expandedActions;
  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> with TickerProviderStateMixin {
  //late NotifiableList<Map<String, dynamic>> notifiableArtistList = NotifiableList.fromAsync(_getArtists());
  //final int _tabCount = 1;
  //late final TabController _tabController;
  late ThemeData _theme;
  bool isProcessing = true;
  bool loopSongs = false;
  final Map<String, bool> _sortState = {
    'title': false,
    'artist': false,
    'downloaded': false,
  };

  @override
  void initState() {
    super.initState();
    //_tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    widget.songBars.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.songBars,
      builder: (context, child) {
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: commonSingleChildScrollViewPadding,
                child: ListenableBuilder(
                  listenable: PM.pluginsData,
                  builder: (context, __) {
                    return SectionHeader(
                      expandedActions: widget.expandedActions,
                      title: widget.title,
                      actions: [
                        if (widget.songBars.hasData) ...[
                          _buildSortSongActionButton(),
                          _buildShuffleSongActionButton(),
                          _buildPlayActionButton(),
                          if (widget.page != 'queue')
                            _buildAddToQueueActionButton(),
                          ...PM.getWidgetsByType(
                            _getSongListData,
                            'SongListHeader',
                            context,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            if (widget.songBars.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsGeometry.all(10),
                  child: Spinner(),
                ),
              ),
            if (widget.songBars.hasData) _buildSongList(context),
            if (!widget.songBars.hasData)
              SliverToBoxAdapter(
                child: Align(
                  child: Padding(
                    padding: const EdgeInsetsGeometry.all(10),
                    child: Text(
                      context.l10n!.noData,
                      style: TextStyle(color: _theme.colorScheme.primary),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /*
  Widget _buildArtistList() {
    return SliverMainAxisGroup(
      slivers: [
        SliverAppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          pinned: true,
          floating: true,
          snap: true,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.l10n!.artists.toUpperCase()),
              //Tab(text: context.l10n!.albums.toUpperCase()),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: IndexedStack(
            index: _tabController.index,
            children: [
              ArtistList(
                page: widget.page,
                notifiableArtistList: notifiableArtistList,
                child: SliverMainAxisGroup(
                  slivers: [
                    if (widget.songBars.isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(10),
                          child: Spinner(),
                        ),
                      ),
                    if (widget.songBars.hasData) _buildSongList(context),
                    if (!widget.songBars.hasData)
                      SliverToBoxAdapter(
                        child: Align(
                          child: Padding(
                            padding: const EdgeInsetsGeometry.all(10),
                            child: Text(
                              context.l10n!.noData,
                              style: TextStyle(
                                color: _theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Iterable<Map<String, dynamic>>> _getArtists() async {
    return widget.songBars.completer.future.then((value) async {
      final songs = value.map((e) => e.song).toList();
      return getArtistsFromSongs(songs);
    });
  }
*/
  dynamic _getSongListData() {
    final data =
        widget.songBars.map((e) {
          e.song['album'] = e.song['album'];
          e.song['song'] = e.song['title'];
          return e;
        }).toList();
    return data;
  }

  Widget _buildShuffleSongActionButton() {
    return IconButton(
      tooltip: context.l10n!.shuffle,
      color: _theme.colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_shuffle_16_filled),
      iconSize: listHeaderIconSize,
      onPressed: () {
        widget.songBars.shuffledWith(widget.songBars);
        if (widget.page == 'queue') updateMediaItemQueue(widget.songBars);
        if (mounted) setState(() {});
      },
    );
  }

  List<PopupMenuItem<String>> _buildSortMenuItems(BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'artist',
        child: Row(
          children: [
            Icon(
              FluentIcons.mic_sparkle_16_filled,
              color: _theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.artist),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'name',
        child: Row(
          children: [
            Icon(
              FluentIcons.music_note_2_16_filled,
              color: _theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.name),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'downloaded',
        child: Row(
          children: [
            Icon(
              FluentIcons.arrow_download_24_filled,
              color: _theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.download),
          ],
        ),
      ),
    ];
  }

  void _sortMenuItemAction(String value) {
    void sortBy(String key) {
      final reverse = _sortState[key] ?? false;
      widget.songBars.sort((a, b) {
        final valueA = a.song[key].toString().toLowerCase();
        final valueB = b.song[key].toString().toLowerCase();
        return reverse ? valueB.compareTo(valueA) : valueA.compareTo(valueB);
      });
      if (widget.page == 'queue') updateMediaItemQueue(widget.songBars);
      if (mounted)
        setState(() {
          _sortState[key] = !(_sortState[key] ?? false);
        });
    }

    void sortByDownloaded() {
      final reverse = _sortState['downloaded'] ?? false;
      widget.songBars.sort((a, b) {
        final valueA = isSongAlreadyOffline(a.song);
        final valueB = isSongAlreadyOffline(b.song);
        if (valueA && !valueB) return reverse ? 1 : -1;
        if (!valueA && valueB) return reverse ? -1 : 1;
        return 0;
      });
      if (widget.page == 'queue') updateMediaItemQueue(widget.songBars);
      if (mounted)
        setState(() {
          _sortState['downloaded'] = !(_sortState['downloaded'] ?? false);
        });
    }

    switch (value) {
      case 'name':
        sortBy('title');
        break;
      case 'artist':
        sortBy('artist');
        break;
      case 'downloaded':
        sortByDownloaded();
        break;
    }
  }

  Widget _buildSortSongActionButton() {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _theme.colorScheme.secondaryContainer,
      icon: Icon(
        FluentIcons.filter_16_filled,
        color: _theme.colorScheme.primary,
        size: listHeaderIconSize,
      ),
      onSelected: _sortMenuItemAction,
      itemBuilder: _buildSortMenuItems,
    );
  }

  Widget _buildAddToQueueActionButton() {
    return IconButton(
      tooltip: context.l10n!.addSongsToQueue,
      color: _theme.colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.add_circle_24_filled),
      iconSize: listHeaderIconSize,
      onPressed: () async {
        if (widget.page != 'queue') {
          addSongsToQueue(widget.songBars);
          showToast(context.l10n!.songAdded);
        }
        if (audioHandler.queueSongBars.isNotEmpty &&
            audioHandler.songValueNotifier.value == null &&
            widget.songBars.isNotEmpty) {
          await audioHandler.prepare(
            songBar: widget.songBars.first,
            skipOnError: true,
          );
        }
      },
    );
  }

  Widget _buildPlayActionButton() {
    return IconButton(
      tooltip: context.l10n!.play,
      onPressed: () async {
        if (widget.page != 'queue') {
          await PM.triggerHook(widget.songBars, 'onPlaylistPlay');
          setQueueToPlaylist({
            'title': widget.title,
            'list': widget.songBars,
          }, widget.songBars);
          showToast(
            '${context.l10n!.queueReplacedByPlaylist}: ${widget.title}',
          );
        }
        await audioHandler.prepare(
          songBar: widget.songBars.first,
          play: true,
          skipOnError: true,
        );
      },
      icon: Icon(
        FluentIcons.play_circle_24_filled,
        color: _theme.colorScheme.primary,
        size: listHeaderIconSize,
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const SliverToBoxAdapter(
      child: Center(
        child: Padding(padding: EdgeInsets.all(35), child: Spinner()),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final errorText =
        !widget.songBars.hasError
            ? (widget.songBars.isEmpty
                ? context.l10n!.noSongsInQueue
                : context.l10n!.error)
            : context.l10n!.error;
    return SliverToBoxAdapter(
      child: Center(
        child: Text(
          errorText,
          style: TextStyle(color: _theme.colorScheme.primary, fontSize: 18),
        ),
      ),
    );
  }

  void moveSongBar(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= widget.songBars.length ||
        newIndex >= widget.songBars.length) {
      logger.log(
        'Invalid indices: oldIndex=$oldIndex, newIndex=$newIndex',
        null,
        null,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final songBar = widget.songBars.removeAt(oldIndex);

    widget.songBars.insert(newIndex, songBar);
    songBar.setBorder(
      borderRadius: getItemBorderRadius(newIndex, widget.songBars.length),
    );

    setState(() {});
  }

  Widget _buildSongList(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.songBars,
      builder: (context, _) {
        return SliverReorderableList(
          itemCount: widget.songBars.length,
          itemBuilder: (context, index) {
            final borderRadius = getItemBorderRadius(
              index,
              widget.songBars.length,
            );
            final songBar =
                widget.songBars[index]..setBorder(borderRadius: borderRadius);
            final key = Key(
              songBar.song['id'] ??
                  '${songBar.song['artist']} - ${songBar.song['title']}',
            );
            // TODO: possible use value notifier
            return ReorderableDragStartListener(
              key: key,
              enabled: widget.isEditable,
              index: index,
              child: Padding(padding: commonBarPadding, child: songBar),
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (mounted)
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                widget.songBars.rearrange(oldIndex, newIndex);
                if (widget.page == 'queue')
                  updateMediaItemQueue(widget.songBars);
              });
          },
        );
      },
    );
  }
}
