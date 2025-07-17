import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:reverbio/extensions/common.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/utilities/common_variables.dart';
import 'package:reverbio/widgets/section_header.dart';

class GenreList extends StatefulWidget {
  GenreList({
    super.key,
    required this.genres,
    this.showCount = false,
    this.callback,
  });
  final bool showCount;
  final List<dynamic> genres;
  final ValueNotifier<String> searchQueryNotifier = ValueNotifier('');
  final Function? callback;
  @override
  _GenreListState createState() => _GenreListState();

  void searchGenres(String value) {
    searchQueryNotifier.value = value;
  }
}

class _GenreListState extends State<GenreList> {
  late ThemeData _theme;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  final sortDefault = 'name';
  bool sortAsc = true;
  late String sortCurrent = sortDefault;

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        SectionHeader(
          title: 'Genres',
          actions: [_buildSortSongActionButton(context)],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth, maxHeight: 42),
          child: ScrollConfiguration(
            behavior: CustomScrollBehavior(),
            child: ValueListenableBuilder(
              valueListenable: widget.searchQueryNotifier,
              builder: (context, value, __) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.genres.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final bubble = GenreBubble(
                      genre: widget.genres[index],
                      showCount: widget.showCount,
                      callback: widget.callback,
                    );
                    if (value.isNotEmpty)
                      bubble.setVisibility(
                        widget.genres[index]['name']
                            .toString()
                            .toLowerCase()
                            .contains(value.toLowerCase()),
                      );
                    return bubble;
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildSortMenuItems(BuildContext context) {
    return [
      PopupMenuItem<String>(
        value: 'name',
        child: Row(
          children: [
            Icon(
              sortAsc
                  ? FluentIcons.text_sort_ascending_16_filled
                  : FluentIcons.text_sort_descending_16_filled,
              color: _theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.name),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'count',
        child: Row(
          children: [
            Icon(
              sortAsc
                  ? FluentIcons.chevron_up_16_filled
                  : FluentIcons.chevron_down_16_filled,
              color: _theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n!.count),
          ],
        ),
      ),
    ];
  }

  void _sortAction(String value) {
    void sortBy(String key) {
      widget.genres.sort((a, b) {
        final valueA = a[key].toString().toLowerCase();
        final valueB = b[key].toString().toLowerCase();

        if (sortAsc)
          return valueA.compareTo(valueB);
        else
          return valueB.compareTo(valueA);
      });
    }

    if (value == sortCurrent)
      sortAsc = !sortAsc;
    else
      sortAsc = true;
    sortCurrent = value;
    switch (value) {
      case 'name':
        sortBy('name');
        break;
      case 'count':
        sortBy('count');
        break;
    }
  }

  Widget _buildSortSongActionButton(BuildContext context) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _theme.colorScheme.secondaryContainer,
      icon: Icon(
        FluentIcons.filter_16_filled,
        color: _theme.colorScheme.primary,
      ),
      iconSize: listHeaderIconSize,
      onSelected: _sortAction,
      itemBuilder: _buildSortMenuItems,
    );
  }
}

class GenreBubble extends StatelessWidget {
  GenreBubble({
    super.key,
    required this.genre,
    this.showCount = false,
    this.callback,
  });
  final bool showCount;
  final dynamic genre;
  final Function? callback;
  final ValueNotifier<bool> hideNotifier = ValueNotifier(true);

  void setVisibility(bool value) {
    hideNotifier.value = value;
  }

  void hide() {
    setVisibility(false);
  }

  void show() {
    setVisibility(true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hideNotifier,
      builder:
          (context, value, __) => Visibility(
            visible: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton(
                onPressed: () {
                  if (callback != null) callback!(genre['name']);
                },
                child: Text(
                  genre['name'] +
                      (showCount ? ' (${genre['count'] ?? 0})' : ''),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontSize: 14,
                    fontFamily: 'montserrat',
                    fontVariations: [const FontVariation('wght', 700)],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ),
    );
  }
}
