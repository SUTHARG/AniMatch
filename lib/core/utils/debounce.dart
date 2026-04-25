// lib/core/utils/debounce.dart
// Simple debounce utility to delay actions until input settles.

import 'dart:async';

class Debounce {
  final Duration delay;
  Timer? _timer;

  Debounce({this.delay = const Duration(milliseconds: 600)});

  /// Runs [action] after [delay] has elapsed since the last call.
  /// Cancels any previously scheduled action.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose — same as cancel.
  void dispose() => cancel();
}
