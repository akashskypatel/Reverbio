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

import 'package:background_downloader/background_downloader.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/API/entities/artist.dart';
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/models/paginated_list.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_bottom_sheet.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/announcement_box.dart';
import 'package:reverbio/widgets/bottom_sheet_bar.dart';
import 'package:reverbio/widgets/horizontal_card_scroller.dart';
import 'package:reverbio/widgets/song_list.dart';
import 'package:reverbio/widgets/spinner.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ThemeData _theme;
  final _dbPlaylists = PaginatedList(
    dbPlaylists,
    pageSize: recommendedCardsNumber,
    randomSeed: DateTime.now().millisecond,
  );
  final PaginatedList _dbSongs = PaginatedList.fromAsync(getRecommendedSongs());
  late final PaginatedList _dbArtists = PaginatedList.fromAsync(
    _dbSongs.initializationFuture!.then((v) async {
      return getRecommendedArtists();
    }),
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reverbio'),
        actions: [
          _buildAlertButton(context),
          _buildSyncButton(),
          if (kDebugMode) const SizedBox(width: 24, height: 24),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ValueListenableBuilder<String?>(
                valueListenable: announcementURL,
                builder: (context, _url, __) {
                  if (_url == null) return const SizedBox.shrink();
                  return AnnouncementBox(
                    message: context.l10n!.newAnnouncement,
                    backgroundColor: _theme.colorScheme.secondaryContainer,
                    textColor: _theme.colorScheme.onSecondaryContainer,
                    url: _url,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ValueListenableBuilder<int>(
                valueListenable: currentLikedPlaylistsLength,
                builder: (context, value, __) {
                  return ListenableBuilder(
                    listenable: _dbPlaylists,
                    builder:
                        (context, child) => HorizontalCardScroller(
                          title: context.l10n!.suggestedPlaylists,
                          future: Future.value(_dbPlaylists.getCurrentPage()),
                          headerActions: _buildPrevNextButtons(
                            _dbPlaylists.hasPreviousPage
                                ? _dbPlaylists.getPreviousPage
                                : null,
                            _dbPlaylists.hasNextPage
                                ? _dbPlaylists.getNextPage
                                : null,
                          ),
                        ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: commonBarPadding,
              child: ListenableBuilder(
                listenable: _dbArtists,
                builder:
                    (context, child) => HorizontalCardScroller(
                      title: context.l10n!.suggestedArtists,
                      future: _dbArtists.getCurrentPageAsync(),
                      icon: FluentIcons.mic_sparkle_24_filled,
                      headerActions: _buildPrevNextButtons(
                        (!_dbArtists.isLoading && _dbArtists.hasPreviousPage)
                            ? _dbArtists.getPreviousPage
                            : null,
                        (_dbArtists.hasNextPage)
                            ? _dbArtists.getNextPage
                            : null,
                      ),
                    ),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _dbSongs,
            builder:
                (context, child) => SongList(
                  page: 'recommended',
                  title: context.l10n!.recommendedForYou,
                  future: _dbSongs.getCurrentPageAsync(),
                  expandedActions: _buildPrevNextButtons(
                    (!_dbSongs.isLoading && _dbSongs.hasPreviousPage)
                        ? _dbSongs.getPreviousPage
                        : null,
                    (_dbSongs.hasNextPage) ? _dbSongs.getNextPage : null,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPrevNextButtons(Function? previous, Function? next) {
    return [
      IconButton(
        onPressed:
            previous != null
                ? () {
                  previous();
                }
                : null,
        icon: Icon(
          FluentIcons.chevron_left_24_filled,
          color:
              previous != null
                  ? _theme.colorScheme.primary
                  : _theme.colorScheme.inversePrimary,
        ),
      ),
      IconButton(
        onPressed:
            next != null
                ? () {
                  next();
                }
                : null,
        icon: Icon(
          FluentIcons.chevron_right_24_filled,
          color:
              next != null
                  ? _theme.colorScheme.primary
                  : _theme.colorScheme.inversePrimary,
        ),
      ),
    ];
  }

  Widget _buildSyncButton() {
    return IconButton(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: const Icon(FluentIcons.arrow_sync_24_filled),
      iconSize: pageHeaderIconSize,
      onPressed: () {
        if (mounted)
          setState(() {
            _dbSongs.reset();
            _dbArtists.reset();
          });
      },
    );
  }

  Widget _buildAlertButton(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notificationLogLength,
      builder:
          (context, value, child) => IconButton(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            icon:
                notificationLog.isNotEmpty ||
                        FileDownloader().taskQueues.isNotEmpty
                    ? const Icon(FluentIcons.alert_badge_24_filled)
                    : const Icon(FluentIcons.alert_24_regular),
            iconSize: pageHeaderIconSize,
            onPressed:
                notificationLog.isNotEmpty
                    ? () async {
                      await _showNotificationLog(context);
                    }
                    : null,
          ),
    );
  }

  Future<void> _showNotificationLog(BuildContext context) async {
    final inactivatedColor = _theme.colorScheme.surfaceContainerHigh;
    showCustomBottomSheet(
      context,
      StatefulBuilder(
        builder: (context, setState) {
          final _logList =
              notificationLog.entries.map((entry) {
                  return {'index': entry.value['index'], 'id': entry.key};
                }).toList()
                ..sort((a, b) => a['index'].compareTo(b['index']));
          final _logKeys = _logList.map((e) => e['id']).toList();
          return ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: commonListViewBottomPadding,
            itemCount: _logKeys.length,
            itemBuilder: (context, index) {
              final notification = notificationLog[_logKeys[index]];
              final borderRadius = getItemBorderRadius(index, _logKeys.length);
              final progress = notificationLog[notification['id']]?['data'];
              final message = notification['message'];
              final dateTime = notification['dateTime'];
              if (progress is ValueNotifier<int>) {
                return ValueListenableBuilder(
                  valueListenable: progress,
                  builder: (context, value, child) {
                    final action = Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 35,
                          child: Spinner(value: value / 100),
                        ),
                        Text('$value%'),
                      ],
                    );
                    return BottomSheetBar(
                      '$message · ${dateTime != null ? formatRelativeTime(dateTime) : ''}',
                      inactivatedColor,
                      borderRadius: borderRadius,
                      actions: [action],
                    );
                  },
                );
              } else {
                final action = IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_filled),
                  onPressed: () {
                    notificationLog.remove(_logKeys[index]);
                    if (context.mounted)
                      setState(() {
                        notificationLogLength.value = notificationLog.length;
                      });
                  },
                );
                return BottomSheetBar(
                  '$message · ${dateTime != null ? formatRelativeTime(dateTime) : ''}',
                  inactivatedColor,
                  borderRadius: borderRadius,
                  actions: [action],
                );
              }
            },
          );
        },
      ),
    );
  }
}
