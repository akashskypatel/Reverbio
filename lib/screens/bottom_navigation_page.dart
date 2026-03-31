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
import 'package:go_router/go_router.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/services/settings_manager.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({super.key, required this.child});

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {
  // R2 fix: Remove _selectedIndex - use widget.child.currentIndex instead
  // R8 fix: Remove ValueNotifier that was never disposed
  // R6 fix: Removed _theme - use Theme.of(context) directly
  // R5 fix: Cache navigation destinations to avoid recomputing
  Map<String, NavigationDestination>? _cachedDestinations;

  @override
  void initState() {
    super.initState();
    // R4 fix: Remove redundant _songListener - ValueListenableBuilder handles this
  }

  @override
  void dispose() {
    // R4 fix: _songListener removed - nothing to remove
    // R8 fix: _selectedIndex removed - nothing to dispose
    super.dispose();
  }

  // R4 fix: _songListener removed - ValueListenableBuilder handles updates

  // R5 fix: Cache navigation destinations to avoid recomputing on every build
  Map<String, NavigationDestination> _getNavigationDestinations(
    BuildContext context,
  ) {
    if (_cachedDestinations != null) return _cachedDestinations!;
    _cachedDestinations = !offlineMode.value
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
        };
    return _cachedDestinations!;
  }

  @override
  Widget build(BuildContext context) {
    // R2/R3 fix: Use widget.child.currentIndex instead of _selectedIndex
    final currentIndex = widget.child.currentIndex;
    final destinations =
        _getNavigationDestinations(context).values
            .map(
              (destination) => NavigationRailDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
                label: Text(destination.label),
              ),
            )
            .toList();
    // R3 fix: Clamp index to valid range
    final selectedIndex =
        currentIndex >= destinations.length || currentIndex < 0
            ? 0
            : currentIndex;
    try {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Scaffold(
            body: Row(
              children: [
                if (isLargeScreen())
                  NavigationRail(
                    minExtendedWidth: navigationRailWidth,
                    minWidth: navigationRailWidth,
                    labelType: NavigationRailLabelType.selected,
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      // R1 fix: Use widget.child.goBranch instead of GoRouter.go
                      widget.child.goBranch(index);
                    },
                  ),
                Flexible(
                  fit: FlexFit.tight,
                  child: ValueListenableBuilder(
                    valueListenable: audioHandler.songValueNotifier,
                    builder: (context, value, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(fit: FlexFit.tight, child: widget.child),
                          if (value != null && value.mediaItem != null)
                            MiniPlayer(
                              closeButton: _buildMiniPlayerCloseButton(context),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            bottomNavigationBar:
                !isLargeScreen()
                    ? NavigationBar(
                      selectedIndex: selectedIndex,
                      labelBehavior:
                          languageSetting.value ==
                                  const Locale('en', '').toLanguageTag()
                              ? NavigationDestinationLabelBehavior
                                  .onlyShowSelected
                              : NavigationDestinationLabelBehavior.alwaysHide,
                      onDestinationSelected: (index) {
                        // R1 fix: Use widget.child.goBranch instead of GoRouter.go
                        widget.child.goBranch(index);
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
      // R7 fix: Return ErrorWidget instead of throwing ErrorDescription
      return ErrorWidget.builder(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
        ),
      );
    }
  }

  // R1 fix: _onDestinationRemoved - use widget.child.goBranch directly in onDestinationSelected

  Widget _buildMiniPlayerCloseButton(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: () {
        audioHandler.close();
      },
      icon: Icon(
        FluentIcons.dismiss_24_filled,
        color: theme.colorScheme.primary,
        size: 30,
      ),
      disabledColor: theme.colorScheme.secondaryContainer,
    );
  }
}
