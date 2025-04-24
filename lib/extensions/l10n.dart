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

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reverbio/localization/app_localizations.dart';
import 'package:reverbio/main.dart';

extension ContextX on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
}

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
  // Override behavior to enable dragging with the mouse
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse, // Enable mouse dragging
  };

  // Optionally, you can customize the scrollbar appearance or behavior
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Use the default scrollbar provided by MaterialScrollBehavior
    return super.buildScrollbar(context, child, details);
  }

  // Optionally, you can customize the scroll physics or behavior
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(); // Example: Use BouncingScrollPhysics
  }
}

extension StackTraceExtensions on StackTrace {
  /// Returns the name of the current method from the stack trace.
  String getCurrentMethodName() {
    // Convert the stack trace to a string
    final stackTraceString = toString();
    // Split the stack trace into lines
    final lines = stackTraceString.split('\n');
    // The first line contains the current method
    final currentLine = lines[0];
    // Extract the method name using a regular expression
    final regex = RegExp(r'^#0\s+([\w<>]+)');
    final match = regex.firstMatch(currentLine);
    // Return the method name if found
    return match?.group(1) ?? 'Unknown';
  }
}
