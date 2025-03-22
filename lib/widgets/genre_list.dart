import 'package:flutter/material.dart';
import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/widgets/section_header.dart';

class GenreList extends StatelessWidget {
  const GenreList({super.key, required this.genres, this.showCount = false});
  final bool showCount;
  final List<dynamic> genres;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Column(
      children: [
        const SectionHeader(title: 'Genres'),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: screenWidth, maxHeight: 42),
          child: ScrollConfiguration(
            behavior: CustomScrollBehavior(),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: genres.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return GenreBubble(genre: genres[index], showCount: showCount);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class GenreBubble extends StatelessWidget {
  const GenreBubble({super.key, required this.genre, this.showCount = false});
  final bool showCount;
  final dynamic genre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilledButton(
        onPressed: () => {},
        child: Text(
          genre['name'] + (showCount ? ' (${genre['count'] ?? 0})' : ''),
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
    );
  }
}
