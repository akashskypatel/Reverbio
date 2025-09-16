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
import 'package:reverbio/localization/app_localizations.dart';
import 'package:reverbio/services/settings_manager.dart';

extension ContextX on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
}


// Global localization service
class L10n {
  static AppLocalizations? _instance;

  static void initialize() {
    languageSetting.addListener(() {
      _instance = lookupAppLocalizations(languageSetting.value);
    });
    _instance = lookupAppLocalizations(languageSetting.value);
  }

  static AppLocalizations get current {
    return _instance!;
  }
}