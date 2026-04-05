/*
 * Test setup helpers.
 * Initialize global singletons like L10n and logger for unit tests.
 */

import 'package:reverbio/extensions/l10n.dart';
import 'package:reverbio/localization/app_localizations_en.dart';
import 'package:reverbio/services/logger_service.dart';
import 'package:reverbio/services/service_locator.dart';

/// Initialize L10n for tests.
/// Call this in setUp() or setUpAll() before tests that use L10n.current.
void setUpL10n() {
  L10n.setInstanceForTesting(AppLocalizationsEn());
}

/// Reset L10n after tests.
void tearDownL10n() {
  L10n.resetForTesting();
}

/// Initialize logger for tests.
/// Call this in setUp() or setUpAll() before tests that use logger.
void setUpLogger() {
  // Initialize logger without full service locator
  try {
    ServiceLocator.logger = Logger();
  } catch (_) {
    // Already initialized or not available
  }
}

/// Reset logger after tests.
void tearDownLogger() {
  try {
    ServiceLocator.logger = Logger();
  } catch (_) {
    // Not initialized
  }
}

/// Complete test setup with all services.
/// Call this in setUpAll() for comprehensive test initialization.
void setUpAllServices() {
  setUpL10n();
  setUpLogger();
}

/// Complete test teardown with all services.
/// Call this in tearDownAll() for comprehensive test cleanup.
void tearDownAllServices() {
  tearDownL10n();
  tearDownLogger();
}
