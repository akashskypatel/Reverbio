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
import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/song_bar.dart';
import 'package:reverbio/widgets/spinner.dart';

class SongList extends StatefulWidget {
  SongList({
    super.key,
    this.title = '',
    this.icon = FluentIcons.music_note_1_24_regular,
    this.future,
    this.inputData,
    this.isEditable = false,
  });

  final IconData icon;
  final String title;
  final Future<dynamic>? future;
  final List<dynamic>? inputData;
  final _songBars = <SongBar>[];
  final bool isEditable;
  @override
  State<SongList> createState() => _SongListState();

  Future<bool> queueSong({
    int index = 0,
    bool play = false,
    bool skipOnError = false,
  }) async {
    if (_songBars.isEmpty) return false;
    final isError = !(await _songBars[index++].queueSong(play: play));
    if (play && isError && skipOnError && index < _songBars.length)
      return queueSong(index: index, play: play, skipOnError: skipOnError);
    return !isError;
  }
}

class _SongListState extends State<SongList> {
  List<dynamic> _songsList = [];
  bool isProcessing = true;
  dynamic _playlist;
  bool _isLoading = true;
  bool _hasMore = true;
  var _currentPage = 0;
  var _currentLastLoadedId = 0;
  final int _itemsPerPage = 35;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.future?.ignore();
    widget._songBars.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _songsList = widget.inputData ?? activeQueue['list'] ?? _songsList;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  overflow: TextOverflow.ellipsis,
                  widget.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize:
                        Theme.of(context).textTheme.titleMedium?.fontSize ?? 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSortSongActionButton(),
                  _buildShuffleSongActionButton(),
                  _buildPlayActionButton(),
                  if (widget.future != null) _buildAddToQueueActionButton(),
                ],
              ),
            ],
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
            builder: (_, value, __) {
              if (value != 0) {
                _songsList = activeQueue['list'];
                return _buildSongList();
              } else
                return _buildErrorWidget();
            },
          ),
      ],
    );
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong) {
    final dynamic songToRemove = _songsList.elementAt(indexOfRemovedSong);
    showToastWithButton(
      context,
      context.l10n!.songRemoved,
      context.l10n!.undo.toUpperCase(),
      () {
        addSongInCustomPlaylist(
          context,
          _playlist['title'],
          songToRemove,
          indexToInsert: indexOfRemovedSong,
        );
        _songsList.insert(indexOfRemovedSong, songToRemove);
        if (mounted) setState(() {});
      },
    );
    if (mounted)
      setState(() {
        _songsList.removeAt(indexOfRemovedSong);
      });
  }

  Widget _buildShuffleSongActionButton() {
    return IconButton(
      tooltip: context.l10n!.shuffle,
      color: Theme.of(context).colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_shuffle_16_filled),
      iconSize: 30,
      onPressed: () {
        _songsList.shuffle();
        setState(() {});
      },
    );
  }

  List<PopupMenuItem<String>> _buildPopupMenuItems(BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'artist',
        child: Row(
          children: [
            Icon(
              FluentIcons.mic_sparkle_16_filled,
              color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.name),
          ],
        ),
      ),
    ];
  }

  void _popupMenuItemAction(String value) {
    void sortBy(String key) {
      _songsList.sort((a, b) {
        final valueA = a[key].toString().toLowerCase();
        final valueB = b[key].toString().toLowerCase();
        return valueA.compareTo(valueB);
      });
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
      color: Theme.of(context).colorScheme.secondaryContainer,
      icon: Icon(
        FluentIcons.filter_16_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 30,
      ),
      onSelected: _popupMenuItemAction,
      itemBuilder: _buildPopupMenuItems,
    );
  }

  void _loadMore() {
    _isLoading = true;
    fetch().then((List<dynamic> fetchedList) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (fetchedList.isEmpty) {
            _hasMore = false;
          } else {
            _songsList.addAll(fetchedList);
          }
        });
      }
    });
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
      color: Theme.of(context).colorScheme.primary,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.add_circle_24_filled),
      iconSize: 30,
      onPressed: () {
        addSongsToQueue(_songsList);
        //todo: localize
        showToast(context, 'Added ${_songsList.length} songs to queue!');
        if (activeQueue['list'].isNotEmpty &&
            !audioHandler.audioPlayer.playing &&
            widget._songBars.isNotEmpty) {
          widget.queueSong(play: true, skipOnError: true);
        }
      },
    );
  }

  Widget _buildPlayActionButton() {
    return IconButton(
      tooltip: context.l10n!.play,
      onPressed: () {
        if (widget.future != null)
          setQueueToPlaylist({'title': widget.title, 'list': _songsList});
        else
          widget.queueSong(play: true, skipOnError: true);
      },
      icon: Icon(
        FluentIcons.play_circle_24_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 30,
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
    return SliverToBoxAdapter(
      child: Center(
        child: Text(
          '${context.l10n!.error}!',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  void _buildSongBars() {
    widget._songBars.clear();
    for (var i = 0; i < _songsList.length; i++) {
      final borderRadius = getItemBorderRadius(i, _songsList.length);
      widget._songBars.add(
        SongBar(
          _songsList[i],
          borderRadius: borderRadius,
          showMusicDuration: true,
        ),
      );
    }
  }

  void moveSongBar(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= widget._songBars.length ||
        newIndex >= widget._songBars.length) {
      logger.log(
        'Invalid indices: oldIndex=$oldIndex, newIndex=$newIndex',
        null,
        null,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final songBar = widget._songBars.removeAt(oldIndex);
    final song = _songsList.removeAt(oldIndex);

    widget._songBars.insert(newIndex, songBar);
    _songsList.insert(newIndex, song);

    setState(() {});
  }

  Widget _buildSongList() {
    _buildSongBars();
    return SliverReorderableList(
      itemCount: widget._songBars.length,
      itemBuilder: (context, index) {
        final song = widget._songBars[index].song;
        final key = Key(song['id'] ?? '${song['artist']} - ${song['title']}');
        return ReorderableDragStartListener(
          key: key,
          enabled: widget.isEditable,
          index: index,
          child: widget._songBars[index],
        );
      },
      onReorder: (oldIndex, newIndex) {
        if (mounted)
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            moveSongBar(oldIndex, newIndex);
          });
      },
    );
  }
}
