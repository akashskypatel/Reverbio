import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:reverbio/API/entities/song.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/audio_tags.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/utilities/file_tagger.dart';
import 'package:reverbio/utilities/flutter_toast.dart';
import 'package:reverbio/utilities/utils.dart';
import 'package:reverbio/widgets/base_card.dart';
import 'package:reverbio/widgets/confirmation_dialog.dart';
import 'package:reverbio/widgets/section_header.dart';
import 'package:reverbio/widgets/spinner.dart';

class EditMetadataPage extends StatefulWidget {
  const EditMetadataPage({
    super.key,
    required this.context,
    required this.song,
  });
  final dynamic song;
  final BuildContext context;
  @override
  _EditMetadataPageState createState() => _EditMetadataPageState();
}

class _EditMetadataPageState extends State<EditMetadataPage> {
  // Standard field controllers
  TextEditingController titleController = TextEditingController();
  TextEditingController artistController = TextEditingController();
  TextEditingController albumController = TextEditingController();
  TextEditingController albumArtistController = TextEditingController();
  TextEditingController yearController = TextEditingController();
  TextEditingController commentController = TextEditingController();
  TextEditingController genreController = TextEditingController();
  TextEditingController trackNumberController = TextEditingController();
  TextEditingController trackTotalController = TextEditingController();
  TextEditingController discNumberController = TextEditingController();
  TextEditingController discTotalController = TextEditingController();
  TextEditingController bpmController = TextEditingController();
  TextEditingController composerController = TextEditingController();
  TextEditingController copyrightController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController synopsisController = TextEditingController();
  TextEditingController groupingController = TextEditingController();
  TextEditingController ytController = TextEditingController();
  TextEditingController mbController = TextEditingController();
  TextEditingController lyricsController = TextEditingController();
  TextEditingController durationController = TextEditingController();
  final isInitialized = ValueNotifier(false);
  dynamic song;
  String offlinePath = '';
  final fileTagger = FileTagger();
  Tag? tags;
  final pictures = <Picture>[];
  final customTags = <String, String>{};

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void initialize() async {
    song = widget.song;
    offlinePath = await getOfflinePath(song) ?? '';
    if (offlinePath.isNotEmpty) {
      if (offlinePath.isEmpty || !doesFileExist(offlinePath)) {
        return showToast(context: widget.context, L10n.current.cannotOpenFile);
      }
      try {
        tags = await fileTagger.getTagFromOfflineFile(widget.song);
        if (tags == null)
          showToast(context: widget.context, L10n.current.cannotOpenFile);
        pictures.addAll(tags?.pictures ?? []);
        customTags.addAll(tags?.customTags ?? {});
      } catch (_) {
        return showToast(context: widget.context, L10n.current.cannotOpenFile);
      }
      titleController.text =          tags?.title ?? basenameWithoutExtension(offlinePath);
      artistController.text = tags?.artist ?? '';
      albumController.text = tags?.album ?? '';
      albumArtistController.text = tags?.albumArtist ?? '';
      yearController.text = tags?.year?.toString() ?? '';
      commentController.text = tags?.comment ?? '';
      genreController.text = tags?.genre ?? '';
      trackNumberController.text = tags?.track?.toString() ?? '';
      trackTotalController.text = tags?.trackTotal?.toString() ?? '';
      discNumberController.text = tags?.disc?.toString() ?? '';
      discTotalController.text = tags?.discTotal?.toString() ?? '';
      lyricsController.text = tags?.lyrics ?? '';
      durationController.text = tags?.duration?.toString() ?? '';
      bpmController.text = tags?.bpm?.toString() ?? '';
      composerController.text = tags?.composer ?? '';
      copyrightController.text = tags?.copyright ?? '';
      descriptionController.text = tags?.description ?? '';
      synopsisController.text = tags?.synopsis ?? '';
      groupingController.text = tags?.grouping ?? '';
      ytController.text = tags?.youtube ?? '';
      mbController.text = tags?.musicbrainz ?? '';
    } else {
      showToast(context: widget.context, L10n.current.cannotOpenFile);
    }
    isInitialized.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool metaLoading = false;
    bool showTitleError = false;
    bool showArtistError = false;
    bool isSaving = false;
    return StatefulBuilder(
      builder:
          (context, setState) => Scaffold(
            persistentFooterButtons: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(L10n.current.cancel.toUpperCase()),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    if (isSaving) return;
                    setState(() {
                      isSaving = true;
                    });
                    final newTag = Tag(
                      title: titleController.text.nullIfEmpty,
                      artist: artistController.text.nullIfEmpty,
                      album: albumController.text.nullIfEmpty,
                      albumArtist: albumArtistController.text.nullIfEmpty,
                      year: int.tryParse(yearController.text),
                      comment: commentController.text.nullIfEmpty,
                      genre: genreController.text.nullIfEmpty,
                      track: int.tryParse(trackNumberController.text),
                      trackTotal: int.tryParse(trackTotalController.text),
                      disc: int.tryParse(discNumberController.text),
                      discTotal: int.tryParse(discTotalController.text),
                      lyrics: lyricsController.text.nullIfEmpty,
                      duration: int.tryParse(durationController.text),
                      bpm: double.tryParse(bpmController.text),
                      composer: composerController.text.nullIfEmpty,
                      copyright: copyrightController.text.nullIfEmpty,
                      description: descriptionController.text.nullIfEmpty,
                      synopsis: synopsisController.text.nullIfEmpty,
                      grouping: groupingController.text.nullIfEmpty,
                      youtube: ytController.text.nullIfEmpty,
                      musicbrainz: mbController.text.nullIfEmpty,
                      pictures: pictures,
                      customTags: customTags,
                    );

                    if (await checkAllPermissions()) {
                      final success = await fileTagger.tagOfflineFile(
                        song,
                        filePath: offlinePath,
                        tag: newTag,
                        rename: false,
                      );
                      if (success) {
                        showToast(L10n.current.tagsUpdated);
                      } else {
                        showToast(L10n.current.tagsError);
                      }
                    }
                  } catch (e, stackTrace) {
                    logger.log(
                      'Error in ${stackTrace.getCurrentMethodName()}:',
                      e,
                      stackTrace,
                    );
                    showToast(L10n.current.tagsError);
                  }
                  Navigator.of(context).pop();
                },
                child:
                    isSaving
                        ? ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 62,
                            minHeight: 20,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(dimension: 18, child: Spinner()),
                            ],
                          ),
                        )
                        : Text(L10n.current.confirm.toUpperCase()),
              ),
            ],
            appBar: AppBar(
              title: Text(context.l10n!.editTags),
              actions: [
                IconButton(
                  iconSize: pageHeaderIconSize,
                  onPressed: () async {
                    await AudioTags.clear(offlinePath);
                    if (context.mounted) Navigator.of(context).pop();
                    showToast(L10n.current.tagsCleared);
                  },
                  icon: Icon(
                    FluentIcons.delete_24_filled,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  iconSize: pageHeaderIconSize,
                  onPressed: () async {
                    setState(() => metaLoading = true);
                    final title =
                        songTitle(song).nullIfEmpty ?? tags?.title?.nullIfEmpty;
                    final artist =
                        songArtist(song).nullIfEmpty ??
                        tags?.artist?.nullIfEmpty;
                    if (title == null || artist == null) {
                      setState(() {
                        showArtistError = artist == null;
                        showTitleError = title == null;
                        metaLoading = false;
                      });
                      showToast(L10n.current.enterTitleAndArtist);
                      return;
                    }
                    song['title'] = title;
                    song['artist'] = artist;
                    final value =
                        await queueSongInfoRequest(song).completerFuture;
                    final metaTag = await FileTagger.getTagFromMetadata(value);
                    setState(() {
                      song.addAll(value);
                      pictures
                        ..clear()
                        ..addAll(metaTag?.pictures ?? []);
                      titleController.text = metaTag?.title ?? tags?.title ?? basenameWithoutExtension(offlinePath);
                      artistController.text = metaTag?.artist ?? tags?.artist ?? '';
                      albumController.text = metaTag?.album ?? tags?.album ?? '';
                      albumArtistController.text = metaTag?.albumArtist ?? tags?.albumArtist ?? '';
                      yearController.text = metaTag?.year?.toString() ?? tags?.year?.toString() ?? '';
                      commentController.text = metaTag?.comment ?? tags?.comment ?? '';
                      genreController.text = metaTag?.genre ?? tags?.genre ?? '';
                      trackNumberController.text = metaTag?.track?.toString() ?? tags?.track?.toString() ?? '';
                      trackTotalController.text = metaTag?.trackTotal?.toString() ?? tags?.trackTotal?.toString() ?? '';
                      discNumberController.text = metaTag?.disc?.toString() ?? tags?.disc?.toString() ?? '';
                      discTotalController.text = metaTag?.discTotal?.toString() ?? tags?.discTotal?.toString() ?? '';
                      lyricsController.text = metaTag?.lyrics ?? tags?.lyrics ?? '';
                      durationController.text = metaTag?.duration?.toString() ?? tags?.duration?.toString() ?? '';
                      bpmController.text = metaTag?.bpm?.toString() ?? tags?.bpm?.toString() ?? '';
                      composerController.text = metaTag?.composer ?? tags?.composer ?? '';
                      copyrightController.text = metaTag?.copyright ?? tags?.copyright ?? '';
                      descriptionController.text = metaTag?.description ?? tags?.description ?? '';
                      synopsisController.text = metaTag?.synopsis ?? tags?.synopsis ?? '';
                      groupingController.text = metaTag?.grouping ?? tags?.grouping ?? '';
                      ytController.text = metaTag?.youtube ?? tags?.youtube ?? '';
                      mbController.text = metaTag?.musicbrainz ?? tags?.musicbrainz ?? '';
                      metaLoading = false;
                      showToast(L10n.current.fetchedMetadata);
                    });
                  },
                  icon:
                      metaLoading
                          ? const SizedBox.square(
                            dimension: 18,
                            child: Spinner(),
                          )
                          : Icon(
                            FluentIcons.globe_search_24_filled,
                            color: theme.colorScheme.primary,
                          ),
                ),
              ],
            ),
            body: ValueListenableBuilder(
              valueListenable: isInitialized,
              builder:
                  (context, value, child) =>
                      !value
                          ? const Spinner()
                          : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Standard Fields
                                _textInput(
                                  context,
                                  L10n.current.title,
                                  FluentIcons.music_note_2_24_regular,
                                  titleController,
                                  showErrorIcon: showTitleError,
                                  borderRadius: commonCustomBarRadiusFirst,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.artist,
                                  FluentIcons.person_24_regular,
                                  artistController,
                                  showErrorIcon: showArtistError,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.album,
                                  FluentIcons.album_24_regular,
                                  albumController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.albumArtist,
                                  FluentIcons.people_24_regular,
                                  albumArtistController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.composer,
                                  FluentIcons.person_voice_24_regular,
                                  composerController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.year,
                                  FluentIcons.calendar_24_regular,
                                  yearController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.comment,
                                  FluentIcons.comment_24_filled,
                                  commentController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.genre,
                                  FluentIcons.tag_24_regular,
                                  genreController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.trackNumber,
                                  FluentIcons.number_row_24_regular,
                                  trackNumberController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.trackTotal,
                                  FluentIcons.number_symbol_24_regular,
                                  trackTotalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.discNumber,
                                  FluentIcons.record_24_filled,
                                  discNumberController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.discTotal,
                                  FluentIcons.autosum_24_regular,
                                  discTotalController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.duration,
                                  FluentIcons.clock_24_regular,
                                  durationController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                _textInput(
                                  context,
                                  L10n.current.bpm,
                                  FluentIcons.headphones_sound_wave_24_regular,
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
                                _textInput(
                                  context,
                                  L10n.current.copyright,
                                  Icons.copyright_rounded,
                                  copyrightController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.description,
                                  FluentIcons.text_description_24_regular,
                                  descriptionController,
                                  multiLine: true,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.synopsis,
                                  FluentIcons.text_paragraph_24_regular,
                                  synopsisController,
                                  multiLine: true,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.grouping,
                                  FluentIcons.group_24_regular,
                                  groupingController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.youtubeLink,
                                  FluentIcons.video_clip_24_regular,
                                  ytController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.musicbrainzLink,
                                  FluentIcons.music_note_1_24_regular,
                                  mbController,
                                ),
                                _textInput(
                                  context,
                                  L10n.current.lyrics,
                                  FluentIcons.text_t_24_filled,
                                  lyricsController,
                                  multiLine: true,
                                  keyboardType: TextInputType.multiline,
                                ),
                                // Custom Tags Section
                                _customTagsInput(
                                  context,
                                  L10n.current.customTags,
                                  FluentIcons.tag_multiple_24_regular,
                                  customTags,
                                  setState,
                                ),
                                // Pictures Section
                                _imageInput(
                                  context,
                                  L10n.current.pictures,
                                  FluentIcons.image_24_regular,
                                  pictures,
                                  borderRadius: commonCustomBarRadiusLast,
                                ),
                              ],
                            ),
                          ),
            ),
          ),
    );
  }
}

Widget _customTagsInput(
  BuildContext context,
  String label,
  IconData icon,
  Map<String, String> customTags,
  void Function(void Function()) setState,
) {
  final theme = Theme.of(context).colorScheme;
  final customTagControllers = {
    for (final k in customTags.keys)
      k: TextEditingController(text: customTags[k]),
  };

  return Padding(
    padding: commonBarPadding,
    child: Card(
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.only(bottom: 3),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
        child: Column(
          children: [
            SectionHeader(
              icon: icon,
              title: label,
              expandedActions: [
                IconButton(
                  onPressed: () async {
                    final result = await _showAddCustomTagDialog(context);
                    if (result != null && result.key.isNotEmpty) {
                      setState(() {
                        customTags[result.key] = result.value;
                      });
                    }
                  },
                  icon: const Icon(FluentIcons.add_24_filled),
                  color: theme.primary,
                ),
                IconButton(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder:
                          (context) => ConfirmationDialog(
                            title: L10n.current.deleteCustomTags,
                            confirmText: L10n.current.confirm,
                            cancelText: L10n.current.cancel,
                            onCancel: () {
                              Navigator.of(context).pop(context);
                            },
                            onSubmit: () {
                              setState(() {
                                customTags.clear();
                                customTagControllers.clear();
                              });
                              Navigator.of(context).pop(context);
                            },
                          ),
                    );
                  },
                  icon: const Icon(FluentIcons.delete_24_filled),
                  color: theme.primary,
                ),
              ],
            ),
            if (customTags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  L10n.current.noCustomTags,
                  style: TextStyle(color: theme.secondary),
                ),
              )
            else
              ...customTags.entries.map((entry) {
                final multiLine =
                    customTagControllers[entry.key]?.text.contains('\n') ??
                    false;
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (isLargeScreen())
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.primary,
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 8,
                        child: TextFormField(
                          maxLines: multiLine ? null : 1,
                          minLines: 1,
                          controller: customTagControllers[entry.key],
                          onChanged:
                              (newValue) => customTags[entry.key] = newValue,
                          decoration:
                              !isLargeScreen()
                                  ? InputDecoration(
                                    label: Text(entry.key),
                                    labelStyle: TextStyle(color: theme.primary),
                                  )
                                  : const InputDecoration(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          FluentIcons.dismiss_24_filled,
                          size: 20,
                        ),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder:
                                (context) => ConfirmationDialog(
                                  title: L10n.current.deleteCustomTag,
                                  confirmText: L10n.current.confirm,
                                  cancelText: L10n.current.cancel,
                                  onCancel: () {
                                    Navigator.of(context).pop(context);
                                  },
                                  onSubmit: () {
                                    setState(() {
                                      customTags.remove(entry.key);
                                      customTagControllers.remove(entry.key);
                                    });
                                    Navigator.of(context).pop(context);
                                  },
                                ),
                          );
                        },
                        color: theme.primary,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

Future<MapEntry<String, String>?> _showAddCustomTagDialog(
  BuildContext context,
) async {
  final keyController = TextEditingController();
  final valueController = TextEditingController();
  return showDialog<MapEntry<String, String>?>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(L10n.current.addCustomTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: keyController,
                decoration: InputDecoration(labelText: L10n.current.key),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: valueController,
                decoration: InputDecoration(labelText: L10n.current.value),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.current.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pop(MapEntry(keyController.text, valueController.text));
            },
            child: Text(L10n.current.add.toUpperCase()),
          ),
        ],
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
  bool multiLine = false,
}) {
  final _theme = Theme.of(context).colorScheme;
  Widget _getTextField() {
    return Row(
      spacing: 10,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Align(
            alignment:
                isLargeScreen() ? Alignment.centerLeft : Alignment.centerRight,
            child: TextFormField(
              maxLines: multiLine ? null : 1,
              minLines: 1,
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

  return CustomInputBar(
    context: context,
    icon: Icon(icon, color: _theme.primary),
    label: Text(label, style: TextStyle(color: _theme.primary)),
    borderRadius: borderRadius,
    child: _getTextField(),
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
            onPressed: () async {
              initialValue[index] =
                  await showImagePickerDialog(
                    context,
                    initialValue: initialValue[index],
                  ) ??
                  initialValue[index];
            },
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
              cacheHeight: (dimension * 1.1).toInt(),
              cacheWidth: (dimension * 1.1).toInt(),
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
                    title: L10n.current.pictures,
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

Future<Picture?> showImagePickerDialog(
  BuildContext context, {
  Picture? initialValue,
}) async {
  final dimension = MediaQuery.of(context).size.shortestSide * .90;
  final theme = Theme.of(context).colorScheme;
  final activeButtonBackground = theme.secondaryContainer;
  final inactiveButtonBackground = theme.surfaceContainer;
  bool localMode = true;
  final imagePathController = TextEditingController();
  final imagePathFocus = FocusNode();
  Picture? picture =
      initialValue != null
          ? Picture(
            pictureType: initialValue.pictureType,
            bytes: initialValue.bytes,
          )
          : null;
  PictureType picTypeValue = picture?.pictureType ?? PictureType.coverFront;
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
                    initialSelection: picture?.pictureType ?? PictureType.other,
                    onSelected: (value) {
                      if (value != null && context.mounted) {
                        setState(() {
                          picTypeValue = value;
                          if (picture != null)
                            picture = Picture(
                              bytes: picture!.bytes,
                              pictureType: picTypeValue,
                            );
                        });
                      }
                    },
                    label: Text(L10n.current.pictureType),
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
                            final imageFile = await getImageProvider(
                              path: imagePathController.text,
                            );
                            if (imageFile != null && context.mounted) {
                              final imageData = await getCachedImageBytes(
                                imageFile,
                              );
                              if (imageData != null)
                                setState(() {
                                  picture = Picture(
                                    pictureType: picTypeValue,
                                    bytes: imageData,
                                  );
                                });
                            }
                          },
                          onFieldSubmitted: (newValue) async {
                            final imageFile = await getImageProvider(
                              path: newValue,
                            );
                            if (imageFile != null && context.mounted) {
                              final imageData = await getCachedImageBytes(
                                imageFile,
                              );
                              if (imageData != null)
                                setState(() {
                                  picture = Picture(
                                    pictureType: picTypeValue,
                                    bytes: imageData,
                                  );
                                });
                            }
                          },
                          controller: imagePathController,
                          decoration: InputDecoration(
                            label: Text(L10n.current.imagePath),
                            labelStyle: TextStyle(color: theme.primary),
                          ),
                        ),
                      ),
                      if (localMode)
                        IconButton(
                          onPressed: () async {
                            final imageFile = await getImageFile();
                            if (imageFile != null && context.mounted)
                              setState(() {
                                final imageData = imageFile.readAsBytesSync();
                                imagePathController.text = imageFile.path;
                                picture = Picture(
                                  pictureType: picTypeValue,
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
            onPressed: () => Navigator.of(context).pop(initialValue),
            child: Text(L10n.current.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(picture),
            child: Text(L10n.current.confirm.toUpperCase()),
          ),
        ],
      );
    },
  );
}

class CustomInputBar extends StatelessWidget {
  const CustomInputBar({
    super.key,
    required this.context,
    required this.child,
    required this.label,
    required this.icon,
    this.borderRadius = BorderRadius.zero,
  });
  final BuildContext context;
  final Widget child;
  final Widget label;
  final Widget icon;
  final BorderRadius borderRadius;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: commonBarPadding,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        margin: const EdgeInsets.only(bottom: 3),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 20) +
              EdgeInsets.only(top: borderRadius.topLeft.y),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 10,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLargeScreen()) Expanded(child: icon),
                  if (isLargeScreen()) Expanded(flex: 2, child: label),
                  Expanded(flex: 8, child: child),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
