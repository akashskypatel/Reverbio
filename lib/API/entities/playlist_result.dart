/*
 * Playlist operation result types for decoupling entity functions from UI.
 * Replaces BuildContext-dependent error messages with structured results.
 */

/// Result of a playlist operation (create, add, update, etc.)
enum PlaylistOperationStatus {
  success,
  alreadyExists,
  notFound,
  invalidInput,
  error,
}

/// Structured result for playlist operations.
/// Replaces BuildContext-dependent string returns.
class PlaylistOperationResult {
  PlaylistOperationResult({
    required this.status,
    this.message,
    this.data,
  });

  final PlaylistOperationStatus status;
  final String? message;
  final dynamic data;

  bool get isSuccess => status == PlaylistOperationStatus.success;
  bool get isAlreadyExists => status == PlaylistOperationStatus.alreadyExists;
  bool get isNotFound => status == PlaylistOperationStatus.notFound;
  bool get isInvalidInput => status == PlaylistOperationStatus.invalidInput;
  bool get isError => status == PlaylistOperationStatus.error;

  /// Convert result to localized string for display.
  /// Use this at the UI layer (screens) not in entity functions.
  String toLocalizedString() {
    switch (status) {
      case PlaylistOperationStatus.success:
        return message ?? 'Operation successful';
      case PlaylistOperationStatus.alreadyExists:
        return message ?? 'Already exists';
      case PlaylistOperationStatus.notFound:
        return message ?? 'Not found';
      case PlaylistOperationStatus.invalidInput:
        return message ?? 'Invalid input';
      case PlaylistOperationStatus.error:
        return message ?? 'Operation failed';
    }
  }

  /// Create a success result
  static PlaylistOperationResult success([String? message, dynamic data]) {
    return PlaylistOperationResult(
      status: PlaylistOperationStatus.success,
      message: message,
      data: data,
    );
  }

  /// Create an already exists result
  static PlaylistOperationResult alreadyExists([String? message]) {
    return PlaylistOperationResult(
      status: PlaylistOperationStatus.alreadyExists,
      message: message,
    );
  }

  /// Create a not found result
  static PlaylistOperationResult notFound([String? message]) {
    return PlaylistOperationResult(
      status: PlaylistOperationStatus.notFound,
      message: message,
    );
  }

  /// Create an invalid input result
  static PlaylistOperationResult invalidInput([String? message]) {
    return PlaylistOperationResult(
      status: PlaylistOperationStatus.invalidInput,
      message: message,
    );
  }

  /// Create an error result
  static PlaylistOperationResult error([String? message]) {
    return PlaylistOperationResult(
      status: PlaylistOperationStatus.error,
      message: message,
    );
  }
}
