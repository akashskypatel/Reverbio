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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/version.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/screens/about_page.dart';
import 'package:reverbio/screens/artist_page.dart';
import 'package:reverbio/screens/bottom_navigation_page.dart';
import 'package:reverbio/screens/home_page.dart';
import 'package:reverbio/screens/library_page.dart';
import 'package:reverbio/screens/liked_entities_page.dart';
import 'package:reverbio/screens/now_playing_page.dart';
import 'package:reverbio/screens/search_page.dart';
import 'package:reverbio/screens/settings_page.dart';
import 'package:reverbio/screens/user_songs_page.dart';
import 'package:reverbio/services/settings_manager.dart';

class NavigationManager {
  factory NavigationManager() {
    return _instance;
  }

  NavigationManager._internal() {
    final routes = [
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: _getBranches(),
        pageBuilder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return getPage(
            child: BottomNavigationPage(child: navigationShell),
            state: state,
          );
        },
      ),
    ];

    router = GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: homePath,
      routes: routes,
      observers: [navigatorObserver],
    );
  }

  static final NavigationManager _instance = NavigationManager._internal();

  static NavigationManager get instance => _instance;

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> parentNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> searchTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> libraryTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> queueTabNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> settingsTabNavigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext get context =>
      router.routerDelegate.navigatorKey.currentContext!;

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static RouteObserver<PageRoute> navigatorObserver =
      RouteObserver<PageRoute>();

  static const String homePath = '/home';
  static const String settingsPath = '/settings';
  static const String searchPath = '/search';
  static const String libraryPath = '/library';
  static const String queuePath = '/queue';

  static HomePage homePage = HomePage(); //key: homeTabNavigatorKey);
  static LibraryPage libraryPage =
      const LibraryPage(); //key: libraryTabNavigatorKey);
  static SearchPage searchPage =
      const SearchPage(); //key: searchTabNavigatorKey);
  static UserSongsPage queuePage = const UserSongsPage(
    page: 'queue',
  ); //key: queueTabNavigatorKey,page: 'queue',);
  static SettingsPage settingsPage =
      const SettingsPage(); //key: settingsTabNavigatorKey);

  List<StatefulShellBranch> _getBranches() {
    return [
      if (!offlineMode.value) ...[
        StatefulShellBranch(
          navigatorKey: homeTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'home',
              path: '/',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: homePage, state: state);
              },
            ),
            GoRoute(
              name: 'homePage',
              path: '/home',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: homePage, state: state);
              },
            ),
            GoRoute(
              name: 'artist',
              path: '/artist',
              pageBuilder: (context, GoRouterState state) {
                // Extract passed data (if any)
                final artistData = state.extra as dynamic;
                return getPage(
                  child: ArtistPage(page: 'artist', artistData: artistData),
                  state: state,
                );
              },
            ),
            GoRoute(
              name: 'nowPlaying',
              path: '/nowPlaying',
              pageBuilder: (context, GoRouterState state) {
                // Extract passed data (if any)
                return getPage(child: const NowPlayingPage(), state: state);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: searchTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'search',
              path: '/search',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: searchPage, state: state);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: libraryTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'library',
              path: '/library',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: libraryPage, state: state);
              },
              routes: [
                GoRoute(
                  name: 'userSongs',
                  path: '/userSongs/:page',
                  builder: (context, state) {
                    switch (state.pathParameters['page']) {
                      case 'recents':
                      case 'liked':
                      case 'offline':
                        return UserSongsPage(
                          page: state.pathParameters['page'] ?? '',
                        );
                      case 'artists':
                        return LikedCardsPage(
                          title: context.l10n!.likedArtists,
                          page: state.pathParameters['page'] ?? 'artists',
                          key: ValueKey(DateTime.now()),
                        );
                      case 'albums':
                        return LikedCardsPage(
                          title: context.l10n!.likedAlbums,
                          page: state.pathParameters['page'] ?? 'albums',
                          key: ValueKey(DateTime.now()),
                        );
                      default:
                        return homePage;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: queueTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'queue',
              path: '/queue',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: queuePage, state: state);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: settingsTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'settings',
              path: '/settings',
              pageBuilder: (context, state) {
                return getPage(child: settingsPage, state: state);
              },
              routes: [
                GoRoute(
                  name: 'license',
                  path: '/license',
                  builder:
                      (context, state) => const LicensePage(
                        applicationName: 'Reverbio',
                        applicationVersion: appVersion,
                      ),
                ),
                GoRoute(
                  name: 'about',
                  path: '/about',
                  builder: (context, state) => const AboutPage(),
                ),
              ],
            ),
          ],
        ),
      ] else ...[
        StatefulShellBranch(
          navigatorKey: homeTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'home',
              path: '/',
              builder: (context, state) => const UserSongsPage(page: 'offline'),
            ),
            GoRoute(
              name: 'homePage',
              path: '/home',
              builder: (context, state) => const UserSongsPage(page: 'offline'),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: libraryTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'library',
              path: '/library',
              builder: (context, state) => const UserSongsPage(page: 'offline'),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: queueTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'queue',
              path: '/queue',
              pageBuilder: (context, GoRouterState state) {
                return getPage(child: queuePage, state: state);
              },
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: settingsTabNavigatorKey,
          routes: [
            GoRoute(
              name: 'settings',
              path: '/settings',
              pageBuilder: (context, state) {
                return getPage(child: settingsPage, state: state);
              },
              routes: [
                GoRoute(
                  name: 'license',
                  path: '/license',
                  builder:
                      (context, state) => const LicensePage(
                        applicationName: 'Reverbio',
                        applicationVersion: appVersion,
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    ];
  }

  List<StatefulShellBranch> _onlineRoutes() {
    return [
      StatefulShellBranch(
        navigatorKey: homeTabNavigatorKey,
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: homePage, state: state);
            },
          ),
          GoRoute(
            path: homePath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: homePage, state: state);
            },
          ),
          GoRoute(
            path: '/artist',
            pageBuilder: (context, GoRouterState state) {
              // Extract passed data (if any)
              final artistData = state.extra as dynamic;
              return getPage(
                child: ArtistPage(page: 'artist', artistData: artistData),
                state: state,
              );
            },
          ),
          GoRoute(
            path: '/nowPlaying',
            pageBuilder: (context, GoRouterState state) {
              // Extract passed data (if any)
              return getPage(child: const NowPlayingPage(), state: state);
            },
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: searchTabNavigatorKey,
        routes: [
          GoRoute(
            path: searchPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: searchPage, state: state);
            },
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: libraryTabNavigatorKey,
        routes: [
          GoRoute(
            path: libraryPath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: libraryPage, state: state);
            },
            routes: [
              GoRoute(
                path: 'userSongs/:page',
                builder: (context, state) {
                  switch (state.pathParameters['page']) {
                    case 'recents':
                    case 'liked':
                    case 'offline':
                      return UserSongsPage(
                        page: state.pathParameters['page'] ?? '',
                      );
                    case 'artists':
                      return LikedCardsPage(
                        title: context.l10n!.likedArtists,
                        page: state.pathParameters['page'] ?? 'artists',
                        key: ValueKey(DateTime.now()),
                      );
                    case 'albums':
                      return LikedCardsPage(
                        title: context.l10n!.likedAlbums,
                        page: state.pathParameters['page'] ?? 'albums',
                        key: ValueKey(DateTime.now()),
                      );
                    default:
                      return homePage;
                  }
                },
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: queueTabNavigatorKey,
        routes: [
          GoRoute(
            path: queuePath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(child: queuePage, state: state);
            },
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: settingsTabNavigatorKey,
        routes: [
          GoRoute(
            path: settingsPath,
            pageBuilder: (context, state) {
              return getPage(child: settingsPage, state: state);
            },
            routes: [
              GoRoute(
                path: 'license',
                builder:
                    (context, state) => const LicensePage(
                      applicationName: 'Reverbio',
                      applicationVersion: appVersion,
                    ),
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutPage(),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<StatefulShellBranch> _offlineRoutes() {
    return [
      StatefulShellBranch(
        navigatorKey: homeTabNavigatorKey,
        routes: [
          GoRoute(
            path: homePath,
            pageBuilder: (context, GoRouterState state) {
              return getPage(
                child: const UserSongsPage(page: 'offline'),
                state: state,
              );
            },
          ),
        ],
      ),
      StatefulShellBranch(
        navigatorKey: settingsTabNavigatorKey,
        routes: [
          GoRoute(
            path: settingsPath,
            pageBuilder: (context, state) {
              return getPage(child: settingsPage, state: state);
            },
            routes: [
              GoRoute(
                path: 'license',
                builder:
                    (context, state) => const LicensePage(
                      applicationName: 'Reverbio',
                      applicationVersion: appVersion,
                    ),
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutPage(),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  static Page getPage({required Widget child, required GoRouterState state}) {
    return MaterialPage(key: state.pageKey, child: child);
  }
}
