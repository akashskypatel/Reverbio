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

import 'package:reverbio/services/audio_service_mk.dart';
import 'package:reverbio/services/hive_service.dart';
import 'package:reverbio/services/logger_service.dart';

/// ServiceLocator provides a central seam for dependency injection.
/// All global services are accessed through this class.
class ServiceLocator {
  ServiceLocator._();

  static late ReverbioAudioHandler audioHandler;
  static late HiveService hiveService;
  static late Logger logger;

  /// Initialize all services. Must be called before accessing any service.
  static Future<void> initialize() async {
    hiveService = HiveService();
    await HiveService.ensureInitialize();
    logger = Logger();
  }

  /// Set the audio handler after it has been initialized.
  static void setAudioHandler(ReverbioAudioHandler handler) {
    audioHandler = handler;
  }

  /// Dispose all services.
  static Future<void> dispose() async {
    try {
      await audioHandler.dispose();
      await HiveService.close();
    } catch (e, stackTrace) {
      logger.log('Error in ServiceLocator.dispose:', e, stackTrace);
    }
  }
}
