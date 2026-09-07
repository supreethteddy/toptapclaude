import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// App logger. `developer.log` only reaches DevTools, so in debug builds the
/// message is also mirrored to logcat / the console via [debugPrint].
class Loggers {
  static void _out(String name, String msg) {
    developer.log(msg, name: name);
    if (kDebugMode) debugPrint('[$name] $msg');
  }

  static void info(Object? msg) => _out('INFO', '$msg');

  static void success(Object? msg) => _out('SUCCESS', '✅✅✅: $msg');

  static void warning(Object? msg) => _out('WARNING', '⚠️⚠️⚠️: $msg');

  static void error(Object? msg) => _out('ERROR', '🔴🔴🔴: $msg');
}
