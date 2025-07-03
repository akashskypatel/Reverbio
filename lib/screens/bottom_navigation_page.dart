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

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({super.key, required this.child});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  final _selectedIndex = ValueNotifier<int>(0);
  late final _theme = Theme.of(context);
  bool showMiniPlayer = false;
  @override
  void initState() {
    super.initState();
    audioHandler.audioPlayer.playerStateStream.listen((state) {
      if (mounted)
        setState(() {
          switch (state) {
            case AudioPlayerState.playing:
            case AudioPlayerState.paused:
              showMiniPlayer = true;
              break;
            case AudioPlayerState.stopped:
            case AudioPlayerState.uninitialized:
            case AudioPlayerState.initialized:
              showMiniPlayer = false;
              break;
          }
        });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<String, NavigationDestination> _getNavigationDestinations(
    BuildContext context,
  ) {
    return !offlineMode.value
        ? {
          'home': NavigationDestination(
            key: const Key('/home'),
            icon: const Icon(FluentIcons.home_24_regular),
            selectedIcon: const Icon(FluentIcons.home_24_filled),
            label: context.l10n?.home ?? 'Home',
          ),
          'search': NavigationDestination(
            key: const Key('/search'),
            icon: const Icon(FluentIcons.search_24_regular),
            selectedIcon: const Icon(FluentIcons.search_24_filled),
            label: context.l10n?.search ?? 'Search',
          ),
          'library': NavigationDestination(
            key: const Key('/library'),
            icon: const Icon(FluentIcons.book_24_regular),
            selectedIcon: const Icon(FluentIcons.book_24_filled),
            label: context.l10n?.library ?? 'Library',
          ),
          'queue': NavigationDestination(
            key: const Key('/queue'),
            icon: const Icon(Icons.queue_music),
            selectedIcon: const Icon(Icons.queue_music),
            label: context.l10n?.queue ?? 'Queue',
          ),
          'settings': NavigationDestination(
            key: const Key('/settings'),
            icon: const Icon(FluentIcons.settings_24_regular),
            selectedIcon: const Icon(FluentIcons.settings_24_filled),
            label: context.l10n?.settings ?? 'Settings',
          ),
        }
        : {
          'home': NavigationDestination(
            key: const Key('/home'),
            icon: const Icon(FluentIcons.home_24_regular),
            selectedIcon: const Icon(FluentIcons.home_24_filled),
            label: context.l10n?.home ?? 'Home',
          ),
          'queue': NavigationDestination(
            key: const Key('/queue'),
            icon: const Icon(Icons.queue_music),
            selectedIcon: const Icon(Icons.queue_music),
            label: context.l10n?.queue ?? 'Queue',
          ),
          'settings': NavigationDestination(
            key: const Key('/settings'),
            icon: const Icon(FluentIcons.settings_24_regular),
            selectedIcon: const Icon(FluentIcons.settings_24_filled),
            label: context.l10n?.settings ?? 'Settings',
          ),
        };
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  @override
  Widget build(BuildContext context) {
    try {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = _isLargeScreen(context);
          return Scaffold(
            body: Row(
              children: [
                if (isLargeScreen)
                  NavigationRail(
                    labelType: NavigationRailLabelType.selected,
                    destinations:
                        _getNavigationDestinations(context).values
                            .map(
                              (destination) => NavigationRailDestination(
                                icon: destination.icon,
                                selectedIcon: destination.selectedIcon,
                                label: Text(destination.label),
                              ),
                            )
                            .toList(),
                    selectedIndex: _selectedIndex.value,
                    onDestinationSelected: (index) {
                      /* widget.child.goBranch(
                      index,
                      initialLocation: index == widget.child.currentIndex,
                    ); */
                      _onDestinationSelected(index, context);
                      if (mounted)
                        setState(() {
                          _selectedIndex.value = index;
                        });
                    },
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: widget.child),
                      if (showMiniPlayer)
                        StreamBuilder<MediaItem?>(
                          stream: audioHandler.mediaItem,
                          builder:
                              (context, snapshot) =>
                                  snapshot.hasData &&
                                          !snapshot.hasError &&
                                          snapshot.data != null
                                      ? MiniPlayer(
                                        metadata: snapshot.data!,
                                        closeButton:
                                            _buildMiniPlayerCloseButton(
                                              context,
                                            ),
                                      )
                                      : const SizedBox.shrink(),
                          /*
                        {
                          final metadata = snapshot.data;
                          if (metadata == null) {
                            return const SizedBox.shrink();
                          } else {
                            return MiniPlayer(
                              metadata: metadata,
                              closeButton: _buildMiniPlayerCloseButton(context),
                              navigatorObserver: widget.navigatorObserver,
                            );
                          }
                        },
                        */
                        ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                !isLargeScreen
                    ? NavigationBar(
                      selectedIndex: _selectedIndex.value,
                      labelBehavior:
                          languageSetting == const Locale('en', '')
                              ? NavigationDestinationLabelBehavior
                                  .onlyShowSelected
                              : NavigationDestinationLabelBehavior.alwaysHide,
                      onDestinationSelected: (index) {
                        /* widget.child.goBranch(
                        index,
                        initialLocation: index == widget.child.currentIndex,
                      ); */
                        _onDestinationSelected(index, context);
                        if (mounted)
                          setState(() {
                            _selectedIndex.value = index;
                          });
                      },
                      destinations:
                          _getNavigationDestinations(context).values.toList(),
                    )
                    : null,
          );
        },
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error in ${stackTrace.getCurrentMethodName()}:',
        e,
        stackTrace,
      );
      throw ErrorDescription('There was an error');
    }
  }

  void _onDestinationSelected(int index, BuildContext context) {
    GoRouter.of(
      context,
    ).go('/${_getNavigationDestinations(context).keys.elementAt(index)}');
  }

  Widget _buildMiniPlayerCloseButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        audioHandler.stop();
        if (mounted)
          setState(() {
            showMiniPlayer = false;
          });
      },
      icon: Icon(
        FluentIcons.dismiss_24_filled,
        color: _theme.colorScheme.primary,
        size: 30,
      ),
      disabledColor: _theme.colorScheme.secondaryContainer,
    );
  }
}
