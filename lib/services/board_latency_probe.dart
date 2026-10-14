import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Explicitly enabled only in a local performance-measurement build.
class BoardLatencyProbe {
  static const enabled = bool.fromEnvironment('BOARD_LATENCY_PROBE');
  static const sampleLimit = 34; // First connection, 3 warmups, 30 samples.
  static int _queryId = 0;

  static int nextQueryId() => enabled ? ++_queryId : 0;

  static void emit(String event, Map<String, Object?> values) {
    if (!enabled) return;
    debugPrint('BOARD_LATENCY ${jsonEncode({'event': event, ...values})}');
  }
}
