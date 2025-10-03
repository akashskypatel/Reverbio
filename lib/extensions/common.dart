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
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reverbio/API/reverbio.dart';
import 'package:reverbio/main.dart';
import 'package:reverbio/utilities/common_variables.dart';

extension DoubleExtensions on double {
  /// Checks if the double is nearly zero within a given tolerance.
  ///
  /// [tolerance]: The maximum absolute value to consider as "nearly zero."
  /// Default is `1e-10`.
  bool isNearlyZero({double tolerance = 1e-10}) {
    return this.abs() < tolerance;
  }
}

extension ListOfMapsAddOrUpdate<T, K> on List<dynamic> {
  /// Adds or updates a key-value pair in the first map that contains the key.
  /// If no map contains the key, a new map is added to the list.
  void addOrUpdate(T keyName, K key, dynamic value) {
    // Find the first map that contains the key
    final mapWithKey = firstWhere(
      (map) => map[keyName] == key,
      orElse: () => {}, // Return an empty map if no map contains the key
    );

    if (mapWithKey.isNotEmpty) {
      // Update the value in the existing map
      for (final k in mapWithKey.keys) {
        mapWithKey[k] = value[k];
      }
    } else {
      // Add a new map with the key-value pair
      add(value);
    }
  }

  void addOrUpdateWhere(bool Function(Map, Map) predicate, dynamic value) {
    // Find the first map that contains the key
    final mapWithKey = firstWhere(
      (map) => predicate(map, value),
      // Return an empty map if no map contains the key
      orElse: () => <String, dynamic>{},
    );

    if (mapWithKey.isNotEmpty) {
      // Update the value in the existing map
      for (final k in mapWithKey.keys) {
        if (value[k] != null) mapWithKey[k] = value[k];
      }
    } else {
      // Add a new map with the key-value pair
      add(value);
    }
  }

  void addOrUpdateAllWhere(
    bool Function(Map, Map) predicate,
    List<dynamic> list,
  ) {
    for (final value in list) {
      addOrUpdateWhere(predicate, value);
    }
  }
}

extension ListOfStringsAddOrUpdate<T> on List<String> {
  void addOrUpdateWhere(bool Function(String, String) predicate, String value) {
    final index = indexWhere((s) => predicate(s, value));

    if (index >= 0) {
      this[index] = value;
    } else {
      add(value);
    }
  }
}

extension ShuffledPairExtension<T, U> on List<T> {
  /// Returns a shuffled version of this list and another list,
  /// both shuffled in the same order.
  void shuffledWith(List<U> other, {Random? random}) {
    assert(length == other.length, 'Lists must be same length');

    // Create indices and shuffle them
    final indices = List.generate(length, (i) => i)
      ..shuffle(random ?? Random());

    for (int i = 0; i < indices.length; i++) {
      this.rearrange(i, indices[i]);
      other.rearrange(i, indices[i]);
    }
  }
}

extension ListReordering<T> on List<T> {
  /// Moves an item from [oldIndex] to [newIndex] and shifts other elements accordingly
  void rearrange(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= this.length ||
        newIndex >= this.length) {
      logger.log(
        'Invalid indices: oldIndex=$oldIndex, newIndex=$newIndex',
        null,
        null,
      );
      return;
    }

    if (oldIndex == newIndex) return;

    final item = this.removeAt(oldIndex);
    this.insert(newIndex, item);
  }
}

extension StringCasingExtension on String {
  String get toCapitalized =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String get toTitleCase => replaceAll(
    RegExp(' +'),
    ' ',
  ).split(' ').map((str) => str.toCapitalized).join(' ');
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

extension StackTraceExtensions on StackTrace {
  String getCurrentMethodName() {
    final stackTraceString = toString();
    final lines = stackTraceString.split('\n');
    final currentLine = lines[0];
    final regex = RegExp(r'^#0\s+([\w<>]+)');
    final match = regex.firstMatch(currentLine);
    return match?.group(1) ?? 'Unknown';
  }
}

extension StringParenthesesExtension on String {
  String ensureBalancedParentheses() {
    final s = trim();
    if (s.isEmpty) return s;

    // Check for properly balanced () at end
    if (RegExp(r'\(\)$').hasMatch(s)) {
      return s;
    }

    // Handle single parenthesis cases
    if (RegExp(r'\($').hasMatch(s)) {
      return '$s)';
    }

    if (RegExp(r'\)$').hasMatch(s) && !RegExp(r'^\(.*\)$').hasMatch(s)) {
      return '$s()';
    }

    // Default case
    return '$s()';
  }

  bool checkAllBrackets() {
    final stack = <String>[];
    final pairs = {')': '(', ']': '[', '}': '{'};

    for (int i = 0; i < this.length; i++) {
      final char = this[i];
      if (pairs.containsValue(char)) {
        stack.add(char);
      } else if (pairs.containsKey(char)) {
        if (stack.isEmpty || stack.last != pairs[char]) {
          return false;
        }
        stack.removeLast();
      }
    }
    return stack.isEmpty;
  }
}

extension MapAddIfNotExistExtension on Map {
  void putAllIfAbsent(Map other) {
    other.forEach((key, value) {
      putIfAbsent(key, () => value);
    });
  }
}

extension MapToIdExtension on Map<String, String> {
  /// Return url encoded composite Id from a map of ids
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String get toId {
    final ids = <String, String>{};
    for (final key in this.keys) {
      if (['mb', 'dc', 'uc', 'is', 'yt'].contains(key) &&
          this[key] != null &&
          this[key]!.isNotEmpty)
        ids[key] = this[key]!;
    }
    return Uri(
      host: '',
      queryParameters: ids,
    ).toString().replaceAll('?', '').replaceAll('//', '');
  }

  /// Replace ids in this map with all ids in given map [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergeReplaceIds(Map<String, String> replaceWith) {
    if (this.isEmpty) return Map<String, String>.from(replaceWith);
    for (final key in replaceWith.keys) {
      if (['mb', 'dc', 'uc', 'is', 'yt'].contains(key) &&
          replaceWith[key] != null &&
          replaceWith[key]!.isNotEmpty)
        this[key] = replaceWith[key]!;
    }
    return this;
  }

  /// Return url encoded composite id after replacing ids in this map with all ids in given map [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedReplacedId(Map<String, String> replaceWith) {
    return this.mergeReplaceIds(replaceWith).toId;
  }

  /// Return url encoded composite id after replacing ids in this map with all ids in given url encoded id string [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedReplacedIdFrom(String replaceWith) {
    return this.mergedReplacedId(replaceWith.toIds);
  }

  /// Return ids as Map after replacing ids in this map with all ids in given url encoded id string [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedReplacedIdsFrom(String replaceWith) {
    return this.mergedReplacedId(replaceWith.toIds).toIds;
  }

  /// Add any ids that exist in [addFrom] but do not exist in this map
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergeAbsentIds(Map<String, String> addFrom) {
    if (this.isEmpty) return Map<String, String>.from(addFrom);
    for (final key in addFrom.keys) {
      if (['mb', 'dc', 'uc', 'is', 'yt'].contains(key) &&
          !this.containsKey(key) &&
          addFrom[key] != null &&
          addFrom[key]!.isNotEmpty)
        this[key] = addFrom[key]!;
    }
    return this;
  }

  /// Return url encoded composite id after adding any ids that exist in given map [addFrom] but do not exist in this map
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedAbsentId(Map<String, String> addFrom) {
    return this.mergeAbsentIds(addFrom).toId;
  }

  /// Return url encoded composite id after adding any ids that exist in given url encoded id string [addFrom] but do not exist in this map
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedAbsentIdFrom(String addFrom) {
    return this.mergedAbsentId(addFrom.toIds);
  }

  /// Return ids as Map after adding any ids that exist in given url encoded id string [addFrom] but do not exist in this map
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedAbsentIdsFrom(String addFrom) {
    return this.mergedAbsentId(addFrom.toIds).toIds;
  }
}

extension StringToIdsExtension on String {
  /// Return ids as Map from url encoded string containing Ids
  Map<String, String> get toIds {
    if (this.isEmpty) return {};
    final id = parseEntityId(this);
    final ids = Map<String, String>.from(Uri.parse('?$id').queryParameters);
    return ids;
  }

  /// Extract Musicbrainz id from a string
  ///
  /// Valid format XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
  String get mbid {
    if (this.isEmpty) return '';
    final mbRx = RegExp(
      '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
      caseSensitive: false,
    );
    return mbRx.firstMatch(this)?.group(1) ?? '';
  }

  /// Extract ISRC from a string
  ///
  /// Valid formats: XX-000-00-00000 (with or without -)
  String get isrc {
    if (this.isEmpty) return '';
    final isRx = RegExp(
      r'([A-Z]{2}-?[A-Z0-9]{3}-?\d{2}-?\d{5})',
      caseSensitive: false,
    );
    return isRx.firstMatch(this)?.group(1) ?? '';
  }

  /// Extract Discogs id from a string
  ///
  /// Valid format is an integer
  String get dcid {
    if (this.isEmpty) return '';
    final id = int.tryParse(this);
    return id != null ? id.toString() : '';
  }

  /// Extract user-created playlist id from a string
  ///
  /// Valid format starts with "UC-"
  String get ucid {
    if (this.isEmpty) return '';
    return this.startsWith('UC-') ? this : '';
  }

  /// Extract YouTube id from a string
  ///
  /// Valid format is anything that doesn't match mbid, isrc, dcid, and ucid
  String get ytid {
    if (this.isEmpty) return '';
    if (this.contains(RegExp(r'=|(\%3d)', caseSensitive: false))) {
      final ids = Map<String, String>.from(
        Uri.parse('?${parseEntityId(this)}').queryParameters,
      );
      return ids['yt'] ?? '';
    } else if (this.mbid.isEmpty &&
        this.isrc.isEmpty &&
        this.dcid.isEmpty &&
        this.ucid.isEmpty) {
      final ids = Map<String, String>.from(
        Uri.parse('?${parseEntityId(this)}').queryParameters,
      );
      return ids['yt'] ?? '';
    }
    return '';
  }

  /// Return url encoded composite id after replacing ids in this map with all ids in given url encoded id string [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedReplacedId(String replaceWith) {
    if (this.isEmpty) return replaceWith;
    final ids = this.toIds;
    final otherIds = replaceWith.toIds;
    return ids.mergedReplacedId(otherIds);
  }

  /// Return ids as Map after replacing ids in this map with all ids in given url encoded id string [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedReplacedIds(String replaceWith) {
    final ids = this.toIds;
    final otherIds = replaceWith.toIds;
    return ids.mergeReplaceIds(otherIds);
  }

  /// Return url encoded composite id after replacing ids in this map with all ids in given Map of ids [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedReplacedIdFrom(Map<String, String> replaceWith) {
    final ids = this.toIds;
    return ids.mergedReplacedId(replaceWith);
  }

  /// Return ids as Map after replacing ids in this map with all ids in given Map of ids [replaceWith]
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedReplacedIdsFrom(Map<String, String> replaceWith) {
    final ids = this.toIds;
    return ids.mergeReplaceIds(replaceWith);
  }

  /// Return url encoded composite id after adding any ids that exist in given url encoded id string [addFrom] but do not exist in this id
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedAbsentId(String addFrom) {
    if (this.isEmpty) return addFrom;
    final ids = this.toIds;
    final otherIds = addFrom.toIds;
    return ids.mergedAbsentId(otherIds);
  }

  /// Return ids as Map after adding any ids that exist in given url encoded id string [addFrom] but do not exist in this id
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedAbsentIds(String addFrom) {
    final ids = this.toIds;
    final otherIds = addFrom.toIds;
    return ids.mergeAbsentIds(otherIds);
  }

  /// Return url encoded composite id after adding any ids that exist in given ids as Map [addFrom] but do not exist in this id
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  String mergedAbsentIdFrom(Map<String, String> addFrom) {
    final ids = this.toIds;
    return ids.mergedAbsentId(addFrom);
  }

  /// Return ids as Map after adding any ids that exist in given ids as Map [addFrom] but do not exist in this id
  ///
  /// Valid id keys: ['mb', 'dc', 'uc', 'is', 'yt']
  Map<String, String> mergedAbsentIdsFrom(Map<String, String> addFrom) {
    final ids = this.toIds;
    return ids.mergeAbsentIds(addFrom);
  }
}

extension StringSanitizeExtension on String {
  /// Remove extra white spaces
  String get collapsed => this.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Replace special characters and remove extra white spaces
  String get sanitized {
    final pattern = RegExp(
      replacementCharacters.keys.map(RegExp.escape).join('|'),
    );
    return this
        .replaceAllMapped(
          pattern,
          (match) => replacementCharacters[match.group(0)] ?? '',
        )
        .replaceAll(symbolsRegex, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Remove special characters
  String get cleansed =>
      this
          .replaceAllMapped(
            RegExp(replacementCharacters.keys.map(RegExp.escape).join('|')),
            (match) => replacementCharacters[match.group(0)] ?? '',
          )
          .replaceAll(symbolsRegex, ' ')
          .replaceAll(allSymbolsRegex, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
}

extension StringReplaceFromList on String {
  /// Replace multiple strings from a list
  String replaceMultiple(
    List<String> toReplace, {
    String replaceWith = '',
    bool caseSensitive = false,
  }) {
    String fStr = this;
    for (final str in toReplace)
      fStr = fStr.replaceAll(
        RegExp(str, caseSensitive: caseSensitive),
        replaceWith,
      );
    return fStr;
  }
}

extension SmartStringReplacement on String {
  /// Replace all occurrences of longest subsequence
  String replaceAllSubsequence(
    String other, {
    String replacement = '',
    bool caseSensitive = true,
  }) {
    if (other.isEmpty) return this;

    // Find the longest common contiguous substring
    final match = _findSubsequence(this, other, caseSensitive: caseSensitive);
    if (match.isEmpty) return this; // No match found

    return replaceAll(
      RegExp(RegExp.escape(match), caseSensitive: caseSensitive),
      replacement,
    );
  }

  /// Replaces first instance of longest subsequence
  String replaceFirstSubsequence(
    String other, {
    String replacement = '',
    bool caseSensitive = true,
  }) {
    if (other.isEmpty) return this;

    // Find the longest common contiguous substring
    final match = _findSubsequence(this, other, caseSensitive: caseSensitive);
    if (match.isEmpty) return this; // No match found

    // Replace in the original string
    return replaceFirst(
      RegExp(RegExp.escape(match), caseSensitive: caseSensitive),
      replacement,
    );
  }

  /// Replace all longest subsequences from a list
  (String, List<String>) replaceSubsequenceList(
    List<String> list, {
    String replacement = '',
    bool caseSensitive = true,
  }) {
    var result = this;
    final matched = <String>[];
    if (list.isEmpty) return (this, matched);
    for (final other in list) {
      final match = findSubsequence(other, caseSensitive: caseSensitive);
      if (match.isNotEmpty) {
        result = result.replaceAll(
          RegExp(match, caseSensitive: caseSensitive),
          replacement,
        );
        matched.add(match);
      }
    }
    return (result, matched);
  }

  /// Find the longest subsequence
  String findSubsequence(String other, {bool caseSensitive = false}) {
    return _findSubsequence(this, other, caseSensitive: caseSensitive);
  }

  /// Optimized O(n + m) solution using sliding window + hashing
  String _findSubsequence(String a, String b, {bool caseSensitive = false}) {
    final wordsA = a.split(' ');
    final wordsB = b.split(' ');
    if (wordsA.isEmpty || wordsB.isEmpty) return '';

    // Precompute word hashes for faster comparison
    final hashA =
        wordsA
            .map(
              (word) => hashCodeCased(word.cleansed.collapsed, caseSensitive),
            )
            .toList();
    final hashB =
        wordsB
            .map(
              (word) => hashCodeCased(word.cleansed.collapsed, caseSensitive),
            )
            .toList();

    String longestMatch = '';
    final matchMap = <int, List<int>>{};

    // Build a map of word hashes to positions in B
    for (int i = 0; i < hashB.length; i++) {
      matchMap.putIfAbsent(hashB[i], () => []).add(i);
    }

    // Sliding window to find the longest match
    int start = 0;
    while (start < hashA.length) {
      final currentHash = hashA[start];
      if (matchMap.containsKey(currentHash)) {
        for (final bPos in matchMap[currentHash]!) {
          int aPos = start;
          int bIndex = bPos;
          int matchLength = 0;

          // Expand the match as far as possible
          while (aPos < hashA.length &&
              bIndex < hashB.length &&
              hashA[aPos] == hashB[bIndex]) {
            aPos++;
            bIndex++;
            matchLength++;
          }

          // Update longest match if needed
          if (matchLength > 0) {
            final matchedWords = wordsA
                .sublist(start, start + matchLength)
                .join(' ');

            if (matchedWords.length > longestMatch.length) {
              longestMatch = matchedWords;
            }
          }
        }
      }
      start++;
    }

    return longestMatch;
  }

  /// Simple hash function for case-sensitive/insensitive comparison
  int hashCodeCased(String word, bool caseSensitive) {
    return caseSensitive ? word.hashCode : word.toLowerCase().hashCode;
  }
}

extension MapMinimize on Map<String, dynamic> {
  Map<String, dynamic> keepKeys(List<String> keysToKeep) {
    if (keysToKeep.isEmpty) return this;
    if (keysToKeep.isNotEmpty) {
      if (keysToKeep.length > this.keys.length) {
        this.removeWhere((key, _) => !keysToKeep.contains(key));
      } else {
        final newMap = <String, dynamic>{};
        for (final key in keysToKeep) {
          newMap[key] = this[key];
        }
        this.clear();
        this.addAll(newMap);
      }
    }
    return this;
  }

  Map<String, dynamic> removeKeys(List<String> keysToRemove) {
    if (keysToRemove.isEmpty) return this;
    if (keysToRemove.isNotEmpty) {
      if (keysToRemove.length < this.keys.length) {
        for (final key in keysToRemove) {
          this.remove(key);
        }
      } else {
        this.removeWhere((key, _) => keysToRemove.contains(key));
      }
    }
    return this;
  }
}

extension StringNullEmptyExtension on String {
  String? get nullIfEmpty => this.isEmpty ? null : this;
}

extension ImageCopyWith on Image {
  Image copyWith({
    Key? key,
    Widget Function(BuildContext, Widget, int?, bool)? frameBuilder,
    Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    String? semanticLabel,
    bool? excludeFromSemantics,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry? alignment,
    ImageRepeat? repeat,
    Rect? centerSlice,
    bool? matchTextDirection,
    bool? gaplessPlayback,
    bool? isAntiAlias,
    FilterQuality? filterQuality,
  }) {
    return Image(
      key: key ?? this.key,
      image: this.image,
      frameBuilder: frameBuilder ?? this.frameBuilder,
      loadingBuilder: loadingBuilder ?? this.loadingBuilder,
      errorBuilder: errorBuilder ?? this.errorBuilder,
      semanticLabel: semanticLabel ?? this.semanticLabel,
      excludeFromSemantics: excludeFromSemantics ?? this.excludeFromSemantics,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      colorBlendMode: colorBlendMode ?? this.colorBlendMode,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      repeat: repeat ?? this.repeat,
      centerSlice: centerSlice ?? this.centerSlice,
      matchTextDirection: matchTextDirection ?? this.matchTextDirection,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
      filterQuality: filterQuality ?? this.filterQuality,
    );
  }
}
