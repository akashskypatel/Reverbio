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
import 'package:reverbio/API/entities/playlist.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/url_launcher.dart';
import 'package:reverbio/widgets/custom_bar.dart';

void showPlaylistImporter(BuildContext context) => showDialog(
  context: context,
  builder:
      (context) => ScaffoldMessenger(
        child: Builder(
          builder:
              (context) => Scaffold(
                backgroundColor: Colors.transparent,
                body: StatefulBuilder(
                  builder:
                      (context, setState) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => GoRouter.of(context).pop(),
                        child: GestureDetector(
                          onTap: () {},
                          child: AlertDialog(
                            actions: [
                              TextButton(
                                onPressed: () => GoRouter.of(context).pop(),
                                child: Text(
                                  context.l10n!.confirm.toUpperCase(),
                                ),
                              ),
                            ],
                            title: Text(context.l10n!.importPlaylists),
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: commonBarPadding,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                          borderRadius: commonBarRadius,
                                        ),
                                        child: Padding(
                                          padding: commonBarContentPadding,
                                          child: Text(
                                            softWrap: true,
                                            context.l10n!.importNotice,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    CustomBar(
                                      tileName: 'Chosic',
                                      tileIcon: FluentIcons.globe_24_filled,
                                      borderRadius: commonCustomBarRadiusFirst,
                                      onTap:
                                          () => launchURL(
                                            Uri.parse(
                                              'https://www.chosic.com/spotify-playlist-exporter/',
                                            ),
                                          ),
                                    ),
                                    CustomBar(
                                      tileName: 'Spotlistr',
                                      tileIcon: FluentIcons.globe_24_filled,
                                      borderRadius: commonCustomBarRadiusLast,
                                      onTap:
                                          () => launchURL(
                                            Uri.parse(
                                              'https://www.spotlistr.com/export/spotify-playlist/',
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    CustomBar(
                                      tileName: context.l10n!.importPlaylistCsv,
                                      tileIcon:
                                          FluentIcons.folder_open_24_filled,
                                      borderRadius: commonBarRadius,
                                      onTap: () async {
                                        await uploadCsvPlaylist(context);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ),
        ),
      ),
);
