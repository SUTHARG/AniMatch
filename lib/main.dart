import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      // TODO: Replace with your actual Firebase API Key from the Firebase Console if this one is invalid.
      // Your console shows: "API key not valid"
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDD6YmXs3wOYQCpg--_317GUXvsPG4CK9E",
          authDomain: "aimatch-d3a1b.firebaseapp.com",
          projectId: "aimatch-d3a1b",
          storageBucket: "aimatch-d3a1b.firebasestorage.app",
          messagingSenderId: "630393329450",
          appId: "1:630393329450:web:0489418c58593522187053",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  // Check if onboarding has been shown before
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(AniMatchApp(showOnboarding: !onboardingDone));
}

class AniMatchApp extends StatelessWidget {
  final bool showOnboarding;
  const AniMatchApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniMatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}