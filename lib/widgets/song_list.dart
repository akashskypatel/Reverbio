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
import 'dart:math';

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
    this.future,
    this.inputData,
    this.expandedActions,
    this.isEditable = false,
  });

  final IconData icon;
  final String title;
  final String page;
  final Future<dynamic>? future;
  final List<dynamic>? inputData;
  late final List<SongBar> songBars =
      page == 'queue' ? audioHandler.queueSongBars : <SongBar>[];
  final bool isEditable;
  final List<Widget>? expandedActions;
  @override
  State<SongList> createState() => _SongListState();
}

class _SongListState extends State<SongList> {
  late ThemeData _theme;
  List<dynamic> _songsList = [];
  bool isProcessing = true;
  bool loopSongs = false;
  dynamic _playlist;
  var _currentPage = 0;
  var _currentLastLoadedId = 0;
  final int _itemsPerPage = 35;
  late final ValueNotifier<int> _songBarsLength;
  @override
  void initState() {
    super.initState();
    _songBarsLength = ValueNotifier(widget.songBars.length);
  }

  @override
  void dispose() {
    widget.future?.ignore();
    widget.songBars.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    _songsList = widget.inputData ?? activeQueue['list'] ?? _songsList;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: commonSingleChildScrollViewPadding,
            child: ValueListenableBuilder(
              valueListenable: PM.pluginsDataNotifier,
              builder: (context, value, __) {
                return SectionHeader(
                  expandedActions: widget.expandedActions,
                  title: widget.title,
                  actions: [
                    _buildSortSongActionButton(),
                    _buildShuffleSongActionButton(),
                    _buildPlayActionButton(),
                    if (widget.page != 'queue') _buildAddToQueueActionButton(),
                    ...PM.getWidgetsByType(
                      _getSongListData,
                      'SongListHeader',
                      context,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (widget.future != null)
          FutureBuilder(
            future: widget.future,
            builder: (context, snapshot) {
              if (snapshot.hasData) _songsList = snapshot.data;
              return snapshot.hasError
                  ? _buildErrorWidget()
                  : (snapshot.hasData
                      ? _buildSongList()
                      : _buildLoadingWidget());
            },
          )
        else if (widget.inputData != null)
          _buildSongList()
        else
          ValueListenableBuilder(
            valueListenable: activeQueueLength,
            builder: (context, value, __) {
              if (value != 0) {
                return _buildSongList();
              } else
                return _buildErrorWidget();
            },
          ),
      ],
    );
  }

  dynamic _getSongListData() {
    final data =
        _songsList.map((e) {
          e['album'] = e['album'];
          e['song'] = e['title'];
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
        _songsList.shuffledWith(widget.songBars);
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
    ];
  }

  void _sortMenuItemAction(String value) {
    void sortBy(String key) {
      _songsList.sort((a, b) {
        final valueA = a[key].toString().toLowerCase();
        final valueB = b[key].toString().toLowerCase();
        return valueA.compareTo(valueB);
      });
      widget.songBars.sort((a, b) {
        final valueA = a.song[key].toString().toLowerCase();
        final valueB = b.song[key].toString().toLowerCase();
        return valueA.compareTo(valueB);
      });
      if (widget.page == 'queue') updateMediaItemQueue(widget.songBars);
      if (mounted) setState(() {});
    }

    switch (value) {
      case 'name':
        sortBy('title');
        break;
      case 'artist':
        sortBy('artist');
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

  Future<List<dynamic>> fetch() async {
    final list = <dynamic>[];
    final _count = _playlist['list'].length as int;
    final n = min(_itemsPerPage, _count - _currentPage * _itemsPerPage);
    for (var i = 0; i < n; i++) {
      list.add(_playlist['list'][_currentLastLoadedId]);
      _currentLastLoadedId++;
    }

    _currentPage++;
    return list;
  }

  Widget _buildAddToQueueActionButton() {
    return IconButton(
      tooltip: context.l10n!.addSongsToQueue,
      color: _theme.colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.add_circle_24_filled),
      iconSize: listHeaderIconSize,
      onPressed: () {
        if (widget.page != 'queue') {
          addSongsToQueue(widget.songBars);
          showToast(context.l10n!.songAdded);
        }
        if (audioHandler.queueSongBars.isNotEmpty &&
            audioHandler.songValueNotifier.value == null &&
            widget.songBars.isNotEmpty) {
          audioHandler.queueSong(play: true, skipOnError: true);
        }
      },
    );
  }

  Widget _buildPlayActionButton() {
    return IconButton(
      tooltip: context.l10n!.play,
      onPressed: () {
        if (widget.page != 'queue') {
          setQueueToPlaylist({
            'title': widget.title,
            'list': _songsList,
          }, widget.songBars);
          showToast(
            '${context.l10n!.queueReplacedByPlaylist}: ${widget.title}',
          );
        }
        audioHandler.queueSong(play: true, skipOnError: true);
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
        widget.future == null
            ? (widget.inputData == null
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

  void _buildSongBars() {
    if (widget.page != 'queue') {
      widget.songBars.clear();
      for (var i = 0; i < _songsList.length; i++) {
        final borderRadius = getItemBorderRadius(i, _songsList.length);
        widget.songBars.add(
          SongBar(
            _songsList[i],
            borderRadius: borderRadius,
            showMusicDuration: true,
          ),
        );
      }
      _songBarsLength.value = widget.songBars.length;
    }
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
    final song = _songsList.removeAt(oldIndex);

    widget.songBars.insert(newIndex, songBar);
    songBar.setBorder(
      borderRadius: getItemBorderRadius(newIndex, widget.songBars.length),
    );
    _songsList.insert(newIndex, song);

    setState(() {});
  }

  Widget _buildSongList() {
    _buildSongBars();
    return ValueListenableBuilder(
      valueListenable:
          widget.page == 'queue' ? activeQueueLength : _songBarsLength,
      builder: (context, value, _) {
        return SliverReorderableList(
          itemCount: value,
          itemBuilder: (context, index) {
            final song = widget.songBars[index].song;
            final songBar =
                widget.songBars[index]..setBorder(
                  borderRadius: getItemBorderRadius(
                    index,
                    widget.songBars.length,
                  ),
                );
            final key = Key(
              song['id'] ?? '${song['artist']} - ${song['title']}',
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
                widget.songBars.rearrange(oldIndex, newIndex);
                _songsList.rearrange(oldIndex, newIndex);
                if (widget.page == 'queue')
                  updateMediaItemQueue(widget.songBars);
              });
          },
        );
      },
    );
  }
}
