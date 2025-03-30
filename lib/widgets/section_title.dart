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
import 'package:reverbio/widgets/marque.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.primaryColor, {super.key});
  final Color primaryColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MarqueeWidget(
          manualScrollEnabled: false,
          child: Text(
            overflow: TextOverflow.ellipsis,
            title,
            style: TextStyle(
              color: primaryColor,
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize ?? 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
