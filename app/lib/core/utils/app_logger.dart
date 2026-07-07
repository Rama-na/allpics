import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Central logging setup. In debug, logs go to the console; in release the
/// root level is raised and Crashlytics forwarding is attached in Phase 7.
abstract final class AppLogger {
  static void init() {
    Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  static Logger get(String name) => Logger(name);
}
