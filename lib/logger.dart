import 'package:flutter/foundation.dart';

abstract class Logger {
  void logOk(String path, String contentType);
  void logNotFound(String path, String contentType);
}

// Pass an instance of DebugLogger to view logs only in dev builds
class DebugLogger implements Logger {
  const DebugLogger();
  _log(String path, String contentType, int code) {
    if (!kReleaseMode) {
      debugPrint('GET $path – $code; mime: $contentType');
    }
  }

  @override
  logOk(String path, String contentType) {
    _log(path, contentType, 200);
  }

  @override
  logNotFound(String path, String contentType) {
    _log(path, contentType, 404);
  }
}

// Default logger which does nothing. Use DebugLogger if you want to view access logs in console
class SilentLogger implements Logger {
  const SilentLogger();

  @override
  logNotFound(String path, String contentType) {}

  @override
  logOk(String path, String contentType) {}
}
