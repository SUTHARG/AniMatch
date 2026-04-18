import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

enum AppMode { anime, manga }

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final FirebaseService _firebase = FirebaseService();
  final ValueNotifier<AppMode> modeNotifier = ValueNotifier(AppMode.anime);
  
  static const String _modeKey = 'app_mode_pref';

  AppMode get currentMode => modeNotifier.value;

  Future<void> init() async {
    // 1. Initial load from local SharedPreferences (instant UI)
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_modeKey);
    if (savedMode == AppMode.manga.name) {
      modeNotifier.value = AppMode.manga;
    }

    // 2. Setup Auth Listener for Cloud Sync
    _firebase.authStateChanges.listen((user) async {
      if (user != null) {
        // Logged in: Sync with Cloud
        final cloudPrefs = await _firebase.getUserPreferences();
        if (cloudPrefs != null && cloudPrefs['appMode'] != null) {
          final cloudMode = cloudPrefs['appMode'] == 'manga' ? AppMode.manga : AppMode.anime;
          if (modeNotifier.value != cloudMode) {
            modeNotifier.value = cloudMode;
            // Update local cache as well
            final p = await SharedPreferences.getInstance();
            await p.setString(_modeKey, cloudMode.name);
          }
        } else {
          // New user or no cloud prefs: Push local to Cloud
          await _firebase.updateUserPreferences({'appMode': currentMode.name});
        }
      }
    });
  }

  Future<void> setMode(AppMode mode) async {
    if (modeNotifier.value == mode) return;
    modeNotifier.value = mode;
    
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);

    // Sync to Cloud if logged in
    if (_firebase.isLoggedIn) {
      await _firebase.updateUserPreferences({'appMode': mode.name});
    }
  }

  Future<void> toggleMode() async {
    final newMode = currentMode == AppMode.anime ? AppMode.manga : AppMode.anime;
    await setMode(newMode);
  }
}

// Global accessor for convenience
final appState = AppState();
