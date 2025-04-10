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
  bool showMiniPlayer = false;
  @override
  void initState() {
    super.initState();
    audioHandler.audioPlayer.playerStateStream.listen((state) {
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

  List<NavigationDestination> _getNavigationDestinations(BuildContext context) {
    return !offlineMode.value
        ? [
          NavigationDestination(
            icon: const Icon(FluentIcons.home_24_regular),
            selectedIcon: const Icon(FluentIcons.home_24_filled),
            label: context.l10n?.home ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(FluentIcons.search_24_regular),
            selectedIcon: const Icon(FluentIcons.search_24_filled),
            label: context.l10n?.search ?? 'Search',
          ),
          NavigationDestination(
            icon: const Icon(FluentIcons.book_24_regular),
            selectedIcon: const Icon(FluentIcons.book_24_filled),
            label: context.l10n?.library ?? 'Library',
          ),
          NavigationDestination(
            icon: const Icon(FluentIcons.settings_24_regular),
            selectedIcon: const Icon(FluentIcons.settings_24_filled),
            label: context.l10n?.settings ?? 'Settings',
          ),
        ]
        : [
          NavigationDestination(
            icon: const Icon(FluentIcons.home_24_regular),
            selectedIcon: const Icon(FluentIcons.home_24_filled),
            label: context.l10n?.home ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(FluentIcons.settings_24_regular),
            selectedIcon: const Icon(FluentIcons.settings_24_filled),
            label: context.l10n?.settings ?? 'Settings',
          ),
        ];
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  @override
  Widget build(BuildContext context) {
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
                      _getNavigationDestinations(context)
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
                    widget.child.goBranch(
                      index,
                      initialLocation: index == widget.child.currentIndex,
                    );
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
                        builder: (context, snapshot) {
                          final metadata = snapshot.data;
                          if (metadata == null) {
                            return const SizedBox.shrink();
                          } else {
                            return MiniPlayer(
                              metadata: metadata,
                              closeButton: _buildMiniPlayerCloseButton(context),
                            );
                          }
                        },
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
                      widget.child.goBranch(
                        index,
                        initialLocation: index == widget.child.currentIndex,
                      );
                      setState(() {
                        _selectedIndex.value = index;
                      });
                    },
                    destinations: _getNavigationDestinations(context),
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildMiniPlayerCloseButton(BuildContext context) {
    return IconButton(
      onPressed: () {
        audioHandler.stop();
        setState(() {
          showMiniPlayer = false;
        });
      },
      icon: Icon(
        FluentIcons.dismiss_24_filled,
        color: Theme.of(context).colorScheme.primary,
        size: 30,
      ),
      disabledColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}
