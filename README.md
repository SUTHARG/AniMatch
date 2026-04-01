# 🎌 AniMatch

A cross-platform anime discovery and tracking app built with Flutter & Firebase. AniMatch helps you find the perfect anime to watch through a personalized mood-based quiz, browse trending titles, track your watchlist, and log your viewing progress — all in a sleek Material You interface.

---

## ✨ Features

### 🔍 Discover
- **Anime of the Day** — A daily curated pick from the top-rated list, changes every 24 hours
- **Currently Airing** — Scroll through anime that are currently airing this season
- **Top Rated All Time** — Browse the highest-ranked anime from MyAnimeList

### 🎯 Mood-Based Quiz
- 4-step interactive quiz with animated transitions
- Choose your **mood** (Dark & Intense, Romantic, Action-packed, Chill…)
- Select **genres** (Action, Comedy, Drama, Sci-Fi, Horror, Sports, and more)
- Filter by **episode length** (Short < 13ep, Medium 13–50ep, Long 50+ep)
- Filter by **airing status** (Completed, Ongoing, or Either)
- Powered by the [Jikan API v4](https://jikan.moe/) with smart client-side filtering and rate-limit handling

### 📋 Watchlist
- Add any anime to your personal watchlist with Firebase Firestore sync
- Track watch status: **Watching**, **Completed**, **On Hold**, **Dropped**, **Plan to Watch**
- Log episode-by-episode progress
- Rate (0–10 stars) and write personal reviews
- Filter watchlist by status category

### 🔎 Search
- Search the entire MyAnimeList catalog in real time (sorted by score)

### 📊 Stats
- Total anime tracked, episodes watched, and estimated watch time
- Average personal rating and number of ratings given
- Top 3 favourite genres based on your watchlist

### 👤 Profile
- Firebase Email/Password authentication (Sign up & Sign in)
- View and manage your account
- Sign out

### 🧭 Onboarding
- First-launch onboarding flow (shown once per device via `SharedPreferences`)

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev/) (Dart) |
| Backend / Auth | [Firebase Auth](https://firebase.google.com/products/auth) |
| Database | [Cloud Firestore](https://firebase.google.com/products/firestore) |
| Anime Data API | [Jikan REST API v4](https://docs.api.jikan.moe/) (unofficial MAL API) |
| Image Caching | [`cached_network_image`](https://pub.dev/packages/cached_network_image) |
| Local Storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| Design System | Material You (Material 3) |

---

## 📁 Project Structure

```
lib/
├── main.dart              # App entry point, Firebase init, onboarding gate
├── anime.dart             # Anime & QuizAnswers data models
├── jikan_service.dart     # Jikan API client (throttled, with retry on 429)
├── firebase_service.dart  # Firebase Auth + Firestore CRUD, stats, history
├── home_screen.dart       # Bottom nav shell + Home tab (AotD, Seasonal, Top)
├── quiz_screen.dart       # 4-step animated recommendation quiz
├── results_screen.dart    # Quiz results grid
├── detail_screen.dart     # Full anime detail page (synopsis, trailer, similar)
├── search_screen.dart     # Real-time anime search
├── watchlist_screen.dart  # Watchlist with status filter tabs
├── watch_status_sheet.dart# Bottom sheet to change watch status & progress
├── rating_sheet.dart      # Star rating + review bottom sheet
├── stats_screen.dart      # Personal stats dashboard
├── profile_screen.dart    # Auth UI and profile management
└── onboarding_screen.dart # First-launch onboarding
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.11
- A Firebase project with **Authentication** (Email/Password) and **Firestore** enabled
- An active internet connection (Jikan API is public, no key required)

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd untitled1
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

For **Android / iOS / macOS**:
- Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS/macOS) from your Firebase project and place it in the appropriate platform directory.

For **Web**:
- Update the `FirebaseOptions` in `lib/main.dart` with your own project credentials.

> ⚠️ The web credentials currently in `main.dart` are project-specific. Replace them before deploying.

### 4. Run the app

```bash
# Mobile/Desktop
flutter run

# Web
flutter run -d chrome
```

---

## 🌐 Supported Platforms

| Platform | Status |
|---|---|
| Android | ✅ |
| iOS | ✅ |
| Web (Chrome / Edge) | ✅ |
| Windows | ✅ |
| macOS | ✅ |
| Linux | ✅ |

---

## 🔑 Key Dependencies

```yaml
dependencies:
  firebase_core: ^3.6.0
  cloud_firestore: ^5.4.4
  firebase_auth: ^5.3.1
  http: ^1.2.0
  cached_network_image: ^3.3.1
  shared_preferences: ^2.2.3
```

---

## 📖 Notes

- **Jikan API rate limiting**: The `JikanService` enforces a 400 ms delay between requests and retries automatically on HTTP 429 responses.
- **Offline behaviour**: Firestore is used with default SDK settings; data is available offline for previously fetched documents.
- **Theme**: The app follows the system theme (light/dark) using Material 3's `ThemeMode.system` with a purple seed colour (`#6C5CE7`).
