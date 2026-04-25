// lib/app_state.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';

enum AppMode { anime, manga }

class AppState extends ChangeNotifier {
  AppMode _mode = AppMode.anime;
  User? _user;
  
  static const String _modeKey = 'app_mode';

  AppMode get mode => _mode;
  User? get user => _user;
  bool get isAnimeMode => _mode == AppMode.anime;
  bool get isMangaMode => _mode == AppMode.manga;
  AppMode get currentMode => _mode;

  final FirebaseService _firebaseService = FirebaseService();

  Future<void> init() async {
    // Load local choice first
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_modeKey);
    if (local != null) {
      _mode = local == 'manga' ? AppMode.manga : AppMode.anime;
      notifyListeners();
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        final savedMode = await _firebaseService.getAppMode(user.uid);
        if (savedMode != null) {
          final newMode = savedMode == 'manga' ? AppMode.manga : AppMode.anime;
          if (_mode != newMode) {
            _mode = newMode;
            notifyListeners();
          }
        }
      }
      notifyListeners();
    });
  }

  Future<void> setMode(AppMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    
    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);

    // Sync to Cloud if logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _firebaseService.saveAppMode(uid, mode.name);
    }
  }

  Future<void> toggleMode() async {
    final newMode = _mode == AppMode.anime ? AppMode.manga : AppMode.anime;
    await setMode(newMode);
  }
}

// Global accessor for convenience
final appState = AppState();
