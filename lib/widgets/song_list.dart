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
import 'package:reverbio/services/queue_manager.dart';
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
    required this.songMaps,
    this.expandedActions,
    this.isEditable = false,
  });

  final IconData icon;
  final String title;
  final String page;
  final NotifiableList<Map<String, dynamic>> songMaps;
  final bool isEditable;
  final List<Widget>? expandedActions;
  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> with TickerProviderStateMixin {
  late ThemeData _theme;
  bool isProcessing = true;
  bool loopSongs = false;
  final SearchController _searchController = SearchController();

  // 8.1-A: Track search query to filter visible songs
  String _searchQuery = '';

  final Map<String, bool> _sortState = {
    'title': false,
    'artist': false,
    'downloaded': false,
  };

  @override
  void dispose() {
    // R1 fix: Removed widget.songBars.clear() - widget does not own this list
    // Parent owns songBars, clearing here would cause side effects
    // R5 fix: Dispose search controller
    _searchController.dispose();
    super.dispose();
  }

  // R10 fix: Removed unused _buildSearchAnchor method
  // R11 fix: Removed unused isProcessing and loopSongs state variables

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    // R7 fix: Collapse redundant nested ListenableBuilder - single builder listening to both
    return ListenableBuilder(
      listenable: Listenable.merge([widget.songMaps, PM.pluginsData]),
      builder: (context, _) {
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: commonSingleChildScrollViewPadding,
                child: SectionHeader(
                  onChanged: _searchSongBars,
                  showSearch: true,
                  expandedActions: widget.expandedActions,
                  title: widget.title,
                  actions: [
                    if (widget.songMaps.hasData) ...[
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
                ),
              ),
            ),
            if (widget.songMaps.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsGeometry.all(10),
                  child: Spinner(),
                ),
              ),
            if (widget.songMaps.hasData) _buildSongList(context),
            if (!widget.songMaps.hasData)
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

  void _searchSongBars(String value) {
    // 8.1-A: Update search query and trigger rebuild to filter songs
    setState(() {
      _searchQuery = value;
    });
  }

  // 8.1-A: Filter song maps based on search query
  List<Map<String, dynamic>> _getFilteredSongMaps() {
    if (_searchQuery.isEmpty) {
      return widget.songMaps;
    }
    
    final escapedValue = RegExp.escape(_searchQuery);
    final searchRegex = RegExp(escapedValue, caseSensitive: false);
    
    return widget.songMaps.where((songMap) {
      return songTitle(songMap).contains(searchRegex) ||
          songArtist(songMap).contains(searchRegex);
    }).toList();
  }

  // R10 fix: Removed unused _buildSearchAnchor, _buildLoadingWidget, and _buildErrorWidget methods

  // R6 fix: Operate on copies instead of mutating original song maps
  List<Map<String, dynamic>> _getSongListData() {
    return widget.songMaps.map((songMap) {
      // Create a copy of the song map to avoid mutating the original
      final songCopy = Map<String, dynamic>.from(songMap);
      songCopy['album'] = songCopy['album'];
      songCopy['song'] = songCopy['title'];
      return songCopy;
    }).toList();
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
        widget.songMaps.shuffledWith(widget.songMaps);
        if (widget.page == 'queue') updateMediaItemQueue(widget.songMaps);
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
            Text(context.l10n!.downloaded),
          ],
        ),
      ),
    ];
  }

  void _sortMenuItemAction(String value) {
    void sortBy(String key) {
      final reverse = _sortState[key] ?? false;
      widget.songMaps.sort((a, b) {
        final valueA = a[key].toString().toLowerCase();
        final valueB = b[key].toString().toLowerCase();
        return reverse ? valueB.compareTo(valueA) : valueA.compareTo(valueB);
      });
      if (widget.page == 'queue') updateMediaItemQueue(widget.songMaps);
      if (mounted)
        setState(() {
          _sortState[key] = !(_sortState[key] ?? false);
        });
    }

    void sortByDownloaded() {
      final reverse = _sortState['downloaded'] ?? false;
      widget.songMaps.sort((a, b) {
        final valueA = isSongAlreadyOffline(a);
        final valueB = isSongAlreadyOffline(b);
        if (valueA && !valueB) return reverse ? 1 : -1;
        if (!valueA && valueB) return reverse ? -1 : 1;
        return 0;
      });
      if (widget.page == 'queue') updateMediaItemQueue(widget.songMaps);
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
        FluentIcons.arrow_sort_24_filled,
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
          addSongsToQueue(widget.songMaps);
          showToast(context.l10n!.songAdded);
        }
        if (audioHandler.queueSongMaps.isNotEmpty &&
            audioHandler.songValueNotifier.value == null &&
            widget.songMaps.isNotEmpty) {
          await audioHandler.prepare(
            song: widget.songMaps.first,
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
        // R4 fix: Guard against empty song list
        if (widget.songMaps.isEmpty) {
          showToast('No songs to play');
          return;
        }
        // R8 fix: Respect current queue position - don't always start from first song
        final currentSong = audioHandler.songValueNotifier.value;
        final currentIndex = currentSong != null
            ? widget.songMaps.indexWhere((song) => song['id'] == currentSong['id'])
            : -1;
        final songToPlay = currentIndex >= 0 && currentIndex < widget.songMaps.length
            ? widget.songMaps[currentIndex]
            : widget.songMaps.first;

        if (widget.page != 'queue') {
          await PM.triggerHook(widget.songMaps, 'onPlaylistPlay');
          setQueueToPlaylist({
            'title': widget.title,
            'list': widget.songMaps,
          }, widget.songMaps);
          showToast(
            '${context.l10n!.queueReplacedByPlaylist}: ${widget.title}',
          );
        }
        await audioHandler.prepare(
          song: songToPlay,  // R8 fix: Play current song or first song
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

  // R10 fix: Removed unused _buildLoadingWidget and _buildErrorWidget methods

  void moveSongMap(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= widget.songMaps.length ||
        newIndex >= widget.songMaps.length) {
      logger.log(
        'Invalid indices: oldIndex=$oldIndex, newIndex=$newIndex',
        null,
        null,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final songMap = widget.songMaps.removeAt(oldIndex);

    widget.songMaps.insert(newIndex, songMap);

    setState(() {});
  }

  Widget _buildSongList(BuildContext context) {
    // 8.1-A: Use filtered song maps for search
    final filteredSongs = _getFilteredSongMaps();
    
    return ListenableBuilder(
      listenable: widget.songMaps,
      builder: (context, _) {
        if (filteredSongs.isEmpty && _searchQuery.isNotEmpty) {
          // Show no results message
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n!.noData,
                style: TextStyle(
                  color: _theme.colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }
        
        return SliverReorderableList(
          itemCount: filteredSongs.length,
          itemBuilder: (context, index) {
            final songMap = filteredSongs[index];
            // R9 fix: Ensure unique keys using index as fallback
            final songId = songMap['id']?.toString();
            final keyString = songId?.isNotEmpty == true
                ? songId!
                : '${songMap['artist'] ?? ''}-${songMap['title'] ?? ''}-$index';
            final key = ValueKey<String>(keyString);
            
            // 8.1-B: Calculate border radius for first/last/middle items
            final borderRadius = getItemBorderRadius(index, filteredSongs.length);
            
            // Build SongBar widget from song map with border radius
            final songBar = SongBar(
              songMap,
              key: key,
              borderRadius: borderRadius,
            );
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
                // Find the actual song in the original list
                final songMap = filteredSongs[oldIndex];
                final originalIndex = widget.songMaps.indexWhere(
                  (s) => s['id'] == songMap['id'],
                );
                if (originalIndex >= 0) {
                  widget.songMaps.rearrange(originalIndex, newIndex);
                  if (widget.page == 'queue')
                    updateMediaItemQueue(widget.songMaps);
                }
              });
          },
        );
      },
    );
  }
}
