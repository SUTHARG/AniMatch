// lib/core/constants/app_constants.dart
// App-wide constants: cache durations, limits, keys, etc.

import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ── Cache ────────────────────────────────────────────────────────────────────
  static const Duration jikanCacheTtl          = Duration(minutes: 5);
  static const Duration hiveCacheTtl           = Duration(minutes: 7);
  static const Duration streamingCacheDays     = Duration(days: 7);
  static const Duration anilistCacheTtl        = Duration(minutes: 5);

  // ── Hive ─────────────────────────────────────────────────────────────────────
  static const String hiveBoxName = 'animatch_cache';

  // ── SharedPreferences keys ───────────────────────────────────────────────────
  static const String prefSeenOnboarding = 'seen_onboarding';
  static const String prefAppMode        = 'app_mode';

  // ── API limits ───────────────────────────────────────────────────────────────
  static const int jikanThrottleMs    = 500;  // ms between Jikan requests
  static const int jikanRetryDelayS   = 2;    // seconds to wait on 429
  static const int defaultPageLimit   = 20;
  static const double minRecommendationScore = 6.5;

  // ── App ──────────────────────────────────────────────────────────────────────
  static const String appName = 'AniMatch';
  static const String appVersion = '1.0.0';
  static const Color seedColor = Color(0xFF6C5CE7);
}
