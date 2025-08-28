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

import 'package:flutter/material.dart';

const recommendedCardsNumber = 8;
const pageHeaderIconSize = 30.0;
const listHeaderIconSize = 26.0;
const commonSingleChildScrollViewPadding = EdgeInsets.symmetric(horizontal: 10);
const commonBarPadding = EdgeInsets.symmetric(horizontal: 8);
var commonBarRadius = BorderRadius.circular(18);
var commonBarTitleStyle = const TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
);

const commonCustomBarRadius = BorderRadius.all(Radius.circular(18));
const commonCustomBarRadiusFirst = BorderRadius.vertical(
  top: Radius.circular(18),
);
const commonCustomBarRadiusLast = BorderRadius.vertical(
  bottom: Radius.circular(18),
);

const commonListViewBottomPadding = EdgeInsets.only(bottom: 8);

const commonBarContentPadding = EdgeInsets.symmetric(
  vertical: 12,
  horizontal: 10,
);

final replacementCharacters = {
  '  ': ' - ',
  '[': '',
  ']': '',
  '(': '',
  ')': '',
  '{': '',
  '}': '',
  '<': '',
  '>': '',
  '_': ' ',
  '|': '-',
  '\\': '-',
  '/': '-',
  '&amp;': '&',
  '&#039;': "'",
  '&quot;': '"',
  '“': '"',
  '”': '"',
  '‘': "'",
  '’': "'",
  '`': "'",
  '—': '-',
  '–': '-',
  '+': '-',
  ':': '-',
  ';': '-',
  '@': ' at ',
  '·': '-',
  '.': ' ',
};

final symbolsRegex = RegExp('[~!¡#%^*=?¿؟]', caseSensitive: false);

final allSymbolsRegex = RegExp(r'''[`@$&(){}\[\]<>,./\\|+-:";'~!¡#%^*=?¿؟]''', caseSensitive: false);

final separatorRegex = RegExp('-,', caseSensitive: false);

final boundExtrasRegex = RegExp(
  r'''[\(\[\{\<]+(?:[^)\]\}\>]*\b(official|\bm\W?v\b|special|session|song|music|video|clip|music|lyrics?|video|audio|vi[sz]uali[sz]er?|\bhd\b|4k|\bhq\b|high|quality|version|stripped|acoustic|instrumental|solo|a\s?capella|demo|vocals|reverb|slowed|sped\s*up|speed|remix(?:|es|ed)\b|re(?:\s?|-|)mix(?:|es|ed)\b|cover(?:|s|ed)\b|perform(?:ance|ed)\b|mash(?:\s?|-|)up|parod(?:y|ies|ied)\b|edit(?:|s|ed)\b|live\s*(?:|at|\@|from|in|on|perform(?:ance|ed)\b)|stage|show|concert|tour|cover|perform(?:ance|ed)\b)\b[^(\[\{\<]*)[\)\]\}\>]+''',
  caseSensitive: false,
);

final unboundExtrasRegex = RegExp(
  r'\b(?:official|m\W?v|special|session|music|video|clip|music|lyrics?|video|audio|vi[sz]uali[sz]er?|hd|hq|4k|high|quality|version|stripped|acoustic|instrumental|a\s?capella|demo|vocals|reverb|slowed|sped\s*up|speed|remix(?:|es|ed)|re(?:\s?|-)mix(?:|es|ed)|cover(?:|s|ed)|parod(?:y|ies|ied)|mash(?:\s?|-|)up|edit(?:|s|ed)|perform(?:ance|ed)|(live\s*(?:at|\@|from|in|on|perform(?:ance|ed)|))|(?:stage|show|concert|tour|cover|perform(?:ance|ed)))\b',
  caseSensitive: false,
);

final liveRegex = RegExp(
  r'\b(live\s*(?:at|\@|from|in|on|perform(?:ance|ed)|))|(stage|show|concert|tour|perform(?:ance|ed))\b',
  caseSensitive: false,
);

final derivativeRegex = RegExp(
  r'\b(version|a\s?capella|live|demo|vocals|reverb|slowed|sped\s*up|speed|acoustic|stripped|instrumental|solo|re(?:\s?|-|)mix(?:|es|ed)|cover(?:|s|ed)|parod(?:y|ies|ied)|mash(?:\s?|-|)up|edit(?:|s|ed))\b',
  caseSensitive: false,
);

final artistSplitRegex = RegExp(
  r'(?:\s*(?:,\s*|\s+&\s+|\s+(?:and|with|ft(?:\.)|feat(?:\.|uring)?)\s+|\s*\/\s*|\s*\\\s*|\s*\+\s*|\s*;\s*|\s*[|]\s*|\s* vs(?:\.)?\s*|\s* x\s*|\s*,\s*(?:and|&)\s*)(?![^()]*\)))',
  caseSensitive: false,
);

final singleQuotedRegEx = RegExp(
  r"(?<!\w)'(?<value>(?:\\'|''|(?<=\w)'(?=\w)|[^'])*)'(?!\w)",
  caseSensitive: false,
);

final doubleQuotedRegEx = RegExp('"(?<value>[^"]*)"');

const navigationRailWidth = 80.0;
