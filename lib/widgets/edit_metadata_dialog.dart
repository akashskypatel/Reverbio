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

import 'dart:math';

import 'package:audiotags/audiotags.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/custom_bar.dart';
import 'package:reverbio/widgets/section_header.dart';

Future<void> showEditMetadataDialog(BuildContext context, dynamic song) async {
  final theme = Theme.of(context);
  final offlinePath = await getOfflinePath(song);
  if (offlinePath == null || !doesFileExist(offlinePath)) {
    return showToast(context: context, context.l10n!.cannotOpenFile);
  }
  Tag? tags;
  List<Picture> pictures = [];
  try {
    tags = await AudioTags.read(offlinePath);
    pictures = tags?.pictures ?? pictures;
  } catch (_) {
    return showToast(context: context, context.l10n!.cannotOpenFile);
  }
  final titleController = TextEditingController(text: tags?.title);
  final trackArtistController = TextEditingController(text: tags?.trackArtist);
  final albumController = TextEditingController(text: tags?.album);
  final albumArtistController = TextEditingController(text: tags?.albumArtist);
  final yearController = TextEditingController(text: tags?.year?.toString());
  final genreController = TextEditingController(text: tags?.genre);
  final trackNumberController = TextEditingController(
    text: tags?.trackNumber?.toString(),
  );
  final trackTotalController = TextEditingController(
    text: tags?.trackTotal?.toString(),
  );
  final discNumberController = TextEditingController(
    text: tags?.discNumber?.toString(),
  );
  final discTotalController = TextEditingController(
    text: tags?.discTotal?.toString(),
  );
  final lyricsController = TextEditingController(text: tags?.lyrics);
  final durationController = TextEditingController(
    text: tags?.duration?.toString(),
  );
  final bpmController = TextEditingController(text: tags?.bpm?.toString());

  bool showTitleError = false;
  bool showArtistError = false;
  return showDialog(
    context: context,
    builder: (context) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: StatefulBuilder(
          builder: (context, setState) {
            final maxWidth = MediaQuery.of(context).size.width;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => GoRouter.of(context).pop(),
              child: GestureDetector(
                onTap: () {},
                child: AlertDialog(
                  title: Text(context.l10n!.editTags),
                  content: SizedBox(
                    width: maxWidth,
                    child: ScaffoldMessenger(
                      child: Builder(
                        builder:
                            (context) => Scaffold(
                              persistentFooterButtons: [
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      final newTags = Tag(
                                        title: titleController.text.nullIfEmpty,
                                        trackArtist:
                                            trackArtistController
                                                .text
                                                .nullIfEmpty,
                                        album: albumController.text.nullIfEmpty,
                                        albumArtist:
                                            albumArtistController
                                                .text
                                                .nullIfEmpty,
                                        year: int.tryParse(yearController.text),
                                        genre: genreController.text.nullIfEmpty,
                                        trackNumber: int.tryParse(
                                          trackNumberController.text,
                                        ),
                                        trackTotal: int.tryParse(
                                          trackTotalController.text,
                                        ),
                                        discNumber: int.tryParse(
                                          discNumberController.text,
                                        ),
                                        discTotal: int.tryParse(
                                          discTotalController.text,
                                        ),
                                        lyrics:
                                            lyricsController.text.nullIfEmpty,
                                        duration: int.tryParse(
                                          durationController.text,
                                        ),
                                        bpm: double.tryParse(
                                          bpmController.text,
                                        ),
                                        pictures: pictures,
                                      );
                                      if (tags != newTags) {
                                        await AudioTags.write(
                                          offlinePath,
                                          newTags,
                                        );
                                        showToast(context.l10n!.tagsUpdated);
                                      } else {
                                        showToast(context.l10n!.tagsNoChanges);
                                      }
                                    } catch (e, stackTrace) {
                                      logger.log(
                                        'Error in ${stackTrace.getCurrentMethodName()}:',
                                        e,
                                        stackTrace,
                                      );
                                      showToast(context.l10n!.tagsError);
                                    }
                                    GoRouter.of(context).pop();
                                  },
                                  child: Text(
                                    context.l10n!.confirm.toUpperCase(),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => GoRouter.of(context).pop(),
                                  child: Text(
                                    context.l10n!.cancel.toUpperCase(),
                                  ),
                                ),
                              ],
                              appBar: AppBar(
                                surfaceTintColor:
                                    theme.colorScheme.surfaceContainerHigh,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHigh,
                                actions: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      final title =
                                          song['mbTitle'] ??
                                          song['title'] ??
                                          song['ytTitle'] ??
                                          tags?.title;
                                      final artist =
                                          song['mbArtist'] ??
                                          song['artist'] ??
                                          song['ytArtist'] ??
                                          tags?.trackArtist;
                                      if (title == null ||
                                          title.isEmpty ||
                                          title.toLowerCase() == 'null' ||
                                          title.toLowerCase() == 'unknown' ||
                                          artist == null ||
                                          artist.isEmpty ||
                                          artist.toLowerCase() == 'unknown' ||
                                          artist.toLowerCase() == 'null') {
                                        if (context.mounted)
                                          setState(() {
                                            showArtistError = true;
                                            showTitleError = true;
                                          });
                                        showToast(
                                          context.l10n!.enterTitleAndArtist,
                                        );
                                        return;
                                      }
                                      song['title'] =
                                          song['mbTitle'] ??
                                          song['title'] ??
                                          song['ytTitle'] ??
                                          tags?.title;
                                      song['artist'] =
                                          song['mbArtist'] ??
                                          song['artist'] ??
                                          song['ytArtist'] ??
                                          tags?.trackArtist;
                                      final future = queueSongInfoRequest(song);
                                      await future.completerFuture?.then((
                                        value,
                                      ) {
                                        showToast(
                                          context.l10n!.fetchedMetadata,
                                        );
                                        if (context.mounted)
                                          setState(() {
                                            song.addAll(value);
                                            titleController.text =
                                                song['mbTitle'] ??
                                                song['title'] ??
                                                song['ytTitle'] ??
                                                tags?.title ??
                                                '';
                                            trackArtistController.text =
                                                combineArtists(song) ??
                                                tags?.trackArtist ??
                                                '';
                                            yearController.text =
                                                DateTime.tryParse(
                                                  song['first-release-date'],
                                                )?.year.toString() ??
                                                tags?.year?.toString() ??
                                                '';
                                            durationController.text =
                                                int.tryParse(
                                                  song['duration']
                                                          ?.toString() ??
                                                      '',
                                                )?.toString() ??
                                                tags?.duration?.toString() ??
                                                '';
                                            genreController.text =
                                                (song['genres'] as List?)
                                                    ?.map((e) => e['name'])
                                                    .join(', ') ??
                                                tags?.genre ??
                                                '';
                                            final album = <String, dynamic>{};
                                            for (final release
                                                in (song['releases'] ?? [])) {
                                              if (album.isEmpty &&
                                                  release['release-group'] !=
                                                      null &&
                                                  release['country'] == 'XW') {
                                                album.addAll(
                                                  Map<String, dynamic>.from(
                                                    release['release-group'],
                                                  ),
                                                );
                                                break;
                                              }
                                            }
                                            if (album.isEmpty &&
                                                song['releases']?['release-group'] !=
                                                    null)
                                              album.addAll(
                                                Map<String, dynamic>.from(
                                                  song['releases'][0]['release-group'],
                                                ),
                                              );
                                            albumController.text =
                                                album['title'] ??
                                                tags?.album ??
                                                '';
                                            albumArtistController.text =
                                                combineArtists(album) ??
                                                tags?.album ??
                                                '';
                                          });
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.surfaceContainer,
                                    ),
                                    child: Row(
                                      spacing: 10,
                                      children: [
                                        const Icon(
                                          FluentIcons.database_search_24_filled,
                                        ),
                                        Text(context.l10n!.getMetadata),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHigh,
                              body: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // String title,
                                    _textInput(
                                      context,
                                      context.l10n!.title,
                                      FluentIcons.music_note_2_24_regular,
                                      titleController,
                                      borderRadius: commonCustomBarRadiusFirst,
                                      showErrorIcon: showTitleError,
                                    ),
                                    // String trackArtist,
                                    _textInput(
                                      context,
                                      context.l10n!.trackArtist,
                                      FluentIcons.person_24_regular,
                                      trackArtistController,
                                      showErrorIcon: showArtistError,
                                    ),
                                    // String album,
                                    _textInput(
                                      context,
                                      context.l10n!.album,
                                      FluentIcons.album_24_regular,
                                      albumController,
                                    ),
                                    // String albumArtist,
                                    _textInput(
                                      context,
                                      context.l10n!.albumArtist,
                                      FluentIcons.people_24_regular,
                                      albumArtistController,
                                    ),
                                    // int year,
                                    _textInput(
                                      context,
                                      context.l10n!.year,
                                      FluentIcons.calendar_24_regular,
                                      yearController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // String genre,
                                    _textInput(
                                      context,
                                      context.l10n!.genre,
                                      FluentIcons.tag_24_regular,
                                      genreController,
                                    ),
                                    // int trackNumber,
                                    _textInput(
                                      context,
                                      context.l10n!.trackNumber,
                                      FluentIcons.number_row_24_regular,
                                      trackNumberController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // int trackTotal,
                                    _textInput(
                                      context,
                                      context.l10n!.trackTotal,
                                      FluentIcons.number_symbol_24_regular,
                                      trackTotalController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // int discNumber,
                                    _textInput(
                                      context,
                                      context.l10n!.discNumber,
                                      FluentIcons.record_24_filled,
                                      discNumberController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // int discTotal,
                                    _textInput(
                                      context,
                                      context.l10n!.discTotal,
                                      FluentIcons.autosum_24_regular,
                                      discTotalController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // String lyrics,
                                    _textInput(
                                      context,
                                      context.l10n!.lyrics,
                                      FluentIcons.text_t_24_regular,
                                      lyricsController,
                                    ),
                                    // int duration,
                                    _textInput(
                                      context,
                                      context.l10n!.duration,
                                      FluentIcons.clock_24_regular,
                                      durationController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                    // double bpm
                                    _textInput(
                                      context,
                                      context.l10n!.bpm,
                                      FluentIcons
                                          .headphones_sound_wave_24_regular,
                                      bpmController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}'),
                                        ),
                                      ],
                                    ),
                                    // List<Picture> pictures,
                                    _imageInput(
                                      context,
                                      context.l10n!.pictures,
                                      FluentIcons.image_24_regular,
                                      pictures,
                                      borderRadius: commonCustomBarRadiusLast,
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
            );
          },
        ),
      );
    },
  );
}

Widget _textInput(
  BuildContext context,
  String label,
  IconData icon,
  TextEditingController controller, {
  List<TextInputFormatter>? inputFormatters,
  BorderRadius borderRadius = BorderRadius.zero,
  TextInputType keyboardType = TextInputType.text,
  bool showErrorIcon = false,
}) {
  Widget _getTextField() {
    final _theme = Theme.of(context).colorScheme;
    return Row(
      spacing: 10,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Align(
            alignment:
                isLargeScreen() ? Alignment.centerLeft : Alignment.centerRight,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration:
                  !isLargeScreen()
                      ? InputDecoration(
                        label: Text(label),
                        labelStyle: TextStyle(color: _theme.primary),
                      )
                      : const InputDecoration(),
            ),
          ),
        ),
        if (showErrorIcon) const Icon(FluentIcons.error_circle_24_filled),
      ],
    );
  }

  return CustomBar(
    tileName: isLargeScreen() ? label : null,
    tileIcon: isLargeScreen() ? icon : null,
    borderRadius: borderRadius,
    leading: !isLargeScreen() ? _getTextField() : null,
    trailing: isLargeScreen() ? _getTextField() : null,
  );
}

Widget _imageInput(
  BuildContext context,
  String label,
  IconData icon,
  List<Picture> initialValue, {
  BorderRadius borderRadius = BorderRadius.zero,
}) {
  final _theme = Theme.of(context).colorScheme;
  final dimension = min<double>(220, MediaQuery.of(context).size.width * .45);
  List<Widget> _imageList(void Function(void Function()) setState) {
    return List.generate(initialValue.length, (index) {
      return Stack(
        children: [
          BaseCard(
            size: dimension,
            showIconLabel: false,
            label: initialValue[index].pictureType.toString().replaceAll(
              'PictureType.',
              '',
            ),
            image: Image.memory(
              width: dimension,
              height: dimension,
              initialValue[index].bytes,
            ),
            customButton: IconButton(
              iconSize: 35,
              onPressed: () {
                if (context.mounted)
                  setState(() {
                    initialValue.removeAt(index);
                  });
              },
              icon: const Icon(FluentIcons.delete_24_filled),
              color: _theme.primary,
            ),
          ),
        ],
      );
    });
  }

  return Padding(
    padding: commonBarPadding,
    child: Card(
      margin: const EdgeInsets.only(bottom: 3),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
        child: StatefulBuilder(
          builder:
              (context, setState) => Column(
                children: [
                  SectionHeader(
                    icon: FluentIcons.image_24_regular,
                    title: context.l10n!.pictures,
                    expandedActions: [
                      IconButton(
                        onPressed: () async {
                          final newPicture = await showImagePickerDialog(
                            context,
                          );
                          if (newPicture != null && context.mounted)
                            setState(() {
                              initialValue.add(newPicture);
                            });
                        },
                        icon: const Icon(FluentIcons.add_24_filled),
                        color: _theme.primary,
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            initialValue.clear();
                          });
                        },
                        icon: const Icon(FluentIcons.delete_24_filled),
                        color: _theme.primary,
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 5,
                    runSpacing: 15,
                    children: _imageList(setState),
                  ),
                ],
              ),
        ),
      ),
    ),
  );
}

Future<Picture?> showImagePickerDialog(BuildContext context) async {
  final dimension = MediaQuery.of(context).size.shortestSide * .90;
  final theme = Theme.of(context).colorScheme;
  final activeButtonBackground = theme.secondaryContainer;
  final inactiveButtonBackground = theme.surfaceContainer;
  bool localMode = true;
  final imagePathController = TextEditingController();
  final imagePathFocus = FocusNode();
  final pictureTypeController = TextEditingController();
  Picture? picture;
  return showDialog<Picture?>(
    context: context,
    builder: (context) {
      return AlertDialog(
        constraints: BoxConstraints(minHeight: dimension, minWidth: dimension),
        content: StatefulBuilder(
          builder:
              (context, setState) => Column(
                spacing: 10,
                children: [
                  Row(
                    spacing: 10,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          if (context.mounted)
                            setState(() {
                              localMode = false;
                            });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              localMode
                                  ? inactiveButtonBackground
                                  : activeButtonBackground,
                        ),
                        child: const Icon(FluentIcons.globe_add_24_filled),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (context.mounted)
                            setState(() {
                              localMode = true;
                            });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              localMode
                                  ? activeButtonBackground
                                  : inactiveButtonBackground,
                        ),
                        child: const Icon(FluentIcons.image_add_24_filled),
                      ),
                    ],
                  ),
                  DropdownMenu<PictureType>(
                    controller: pictureTypeController,
                    initialSelection: PictureType.other,
                    label: Text(context.l10n!.pictureType),
                    dropdownMenuEntries: List.generate(
                      PictureType.values.length,
                      (index) => DropdownMenuEntry(
                        value: PictureType.values[index],
                        label: PictureType.values[index].toString().replaceAll(
                          'PictureType.',
                          '',
                        ),
                      ),
                    ),
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    menuStyle: MenuStyle(
                      alignment: Alignment.bottomCenter,
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    spacing: 10,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          focusNode: imagePathFocus,
                          onTapOutside: (_) async {
                            final imageFile = await getImageFileData(
                              path: imagePathController.text,
                            );
                            if (imageFile != null && context.mounted)
                              setState(() {
                                final imageData = imageFile.readAsBytesSync();
                                picture = Picture(
                                  pictureType: PictureType.other,
                                  bytes: imageData,
                                );
                              });
                          },
                          onFieldSubmitted: (newValue) async {
                            final imageFile = await getImageFileData(
                              path: newValue,
                            );
                            if (imageFile != null && context.mounted)
                              setState(() {
                                final imageData = imageFile.readAsBytesSync();
                                picture = Picture(
                                  pictureType: PictureType.other,
                                  bytes: imageData,
                                );
                              });
                          },
                          controller: imagePathController,
                          decoration: InputDecoration(
                            label: Text(context.l10n!.imagePath),
                            labelStyle: TextStyle(color: theme.primary),
                          ),
                        ),
                      ),
                      if (localMode)
                        IconButton(
                          onPressed: () async {
                            final imageFile = await getImageFileData();
                            if (imageFile != null && context.mounted)
                              setState(() {
                                final imageData = imageFile.readAsBytesSync();
                                imagePathController.text = imageFile.path;
                                picture = Picture(
                                  pictureType: PictureType.other,
                                  bytes: imageData,
                                );
                              });
                          },
                          icon: const Icon(FluentIcons.folder_open_24_filled),
                          color: theme.primary,
                        ),
                    ],
                  ),
                  if (picture == null)
                    const SizedBox.shrink()
                  else
                    Expanded(
                      child: Image.memory(picture!.bytes, fit: BoxFit.contain),
                    ),
                ],
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(picture),
            child: Text(context.l10n!.confirm.toUpperCase()),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: Text(context.l10n!.cancel.toUpperCase()),
          ),
        ],
      );
    },
  );
}
