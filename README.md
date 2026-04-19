# 🎌 AniMatch: Total Discovery & Tracking

> A high-performance, premium Anime & Manga companion app built with **Flutter** & **Firebase**.

AniMatch is designed to provide a "no-compromise" experience for fans. It combines a **Glassmorphic UI** with a sophisticated **Hybrid API Architecture** to deliver instant data, real-time schedules, and seamless cloud synchronization across all devices.

---

## 📐 Architecture & Data Flow

AniMatch is structured in 5 clean layers, each with a single responsibility.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                         │
│   Home │ Quiz │ Search │ Detail │ Watchlist │ Profile           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AppState                                │
│          Anime / Manga mode toggle — synced to Firebase         │
└──────────┬──────────────────┬──────────────────┬───────────────┘
           │                  │                  │
           ▼                  ▼                  ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────────────┐
│  JikanService    │ │ AniListService │ │    FirebaseService      │
│  400ms throttle  │ │ GraphQL trends │ │ Auth + Firestore +      │
│  5min mem cache  │ │ spotlight data │ │ Crashlytics helpers     │
└────────┬─────────┘ └───────┬────────┘ └───────────┬────────────┘
         │                   │                       │
         ▼                   ▼                       ▼
┌────────────────┐  ┌────────────────┐    ┌──────────────────────┐
│  Jikan REST v4 │  │ AniList GraphQL│    │       Firebase       │
│  MyAnimeList   │  │  Trending &    │    │  Auth + Firestore    │
│  Free, no key  │  │  Seasonal data │    │  Crashlytics         │
└────────────────┘  └────────────────┘    └──────────────────────┘
```

### Firestore Data Structure

Every user's data is fully private and isolated:

```
users/
└── {uid}/
    ├── displayName
    ├── appMode              ← "anime" or "manga"
    ├── watchlist/
    │   └── {malId}/
    │       ├── title
    │       ├── imageUrl
    │       ├── status       ← watching / completed / on-hold / dropped / plan-to-watch
    │       ├── episodeProgress
    │       ├── rating
    │       └── review
    ├── manga_watchlist/
    │   └── {malId}/
    │       └── (same fields as watchlist + chapter progress)
    ├── streamingCache/
    │   └── {malId}/
    │       ├── links        ← [{ name, url }]
    │       └── cachedAt     ← expires after 7 days
    ├── metadata/
    │   └── search/
    │       └── recentTerms  ← last few search queries
    └── preferences/
        └── appMode, displayName
```

### On-Device Storage

| Storage | What it holds |
|---------|--------------|
| `SharedPreferences` | Onboarding seen flag (one boolean) |
| `cached_network_image` | Anime/manga cover images cached locally |
| Firestore offline SDK | Previously fetched documents available offline |

### App Boot Sequence

```
main() 
  → WidgetsFlutterBinding.ensureInitialized()
  → Firebase.initializeApp()
  → Crashlytics setup (disabled in debug mode)
  → SharedPreferences.getBool('seen_onboarding')
  → AppState.init()  ← listens to auth state changes
  → runZonedGuarded(runApp(AniMatchApp))
```

### API Strategy

| Feature | Provider | Reason |
|---------|----------|--------|
| Trending / Spotlight | AniList GraphQL | Superior speed, curated banners |
| Airing schedule | Jikan REST v4 | Accurate air-time data |
| Manga search | Jikan REST v4 | Full MyAnimeList catalogue |
| Streaming links | Jikan REST v4 `/anime/{id}/streaming` | Free, no key required |
| Recommendations | Jikan REST v4 | Genre + mood mapping |

### Caching Strategy

| Cache | Location | TTL |
|-------|----------|-----|
| API responses | In-memory `Map` in service classes | 5 minutes |
| Streaming links | Cloud Firestore per user | 7 days |
| Cover images | Device storage via `cached_network_image` | Until evicted |
| Offline Firestore docs | Device via Firestore SDK | Until sync |

---

## 🚀 Detailed Setup Guide

If you are building this project from scratch, follow these exact steps to ensure everything functions perfectly.

### 1. Prerequisites
- **Flutter SDK**: `^3.11.0` (Stable channel)
- **Dart SDK**: `^3.0.0`
- **Firebase Account**: Access to the [Firebase Console](https://console.firebase.google.com/)

### 2. Firebase Configuration (CRITICAL)
AniMatch relies heavily on Firebase. You **must** enable the following services:

#### A. Authentication
1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password**
3. Enable **Google Sign-In**
   - For Android: generate an **SHA-1 fingerprint** and add it to Firebase project settings

#### B. Cloud Firestore
1. Initialize Firestore in **Production Mode**
2. Apply these security rules:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

#### C. Crashlytics
1. Go to **Crashlytics** in the Firebase Console
2. Click **Enable Crashlytics**
3. Crashlytics is disabled in debug builds automatically — only activates in release builds

### 3. Android Setup

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>

<queries>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="crunchyroll"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="netflix"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="funimation"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="disneyplus"/></intent>
  <intent><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="aiv"/></intent>
</queries>
```

### 4. iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>crunchyroll</string>
  <string>netflix</string>
  <string>funimation</string>
  <string>disneyplus</string>
  <string>aiv</string>
</array>
```

### 5. Install Dependencies

```bash
flutter pub get
```

### 6. Run the App

```bash
# Debug (any connected device)
flutter run

# Release build (Android APK)
flutter build apk --release

# Web
flutter run -d chrome --web-renderer html

# Windows desktop
flutter run -d windows
```

---

## ✨ Features

### 🏠 Home
- **Anime of the Day** — deterministically selected daily from top-rated list (`dayOfYear % topAnime.length`)
- **Currently Airing** — horizontal scroll list from AniList seasonal data
- **Top Rated All Time** — highest-ranked from MyAnimeList via Jikan
- **Manga Mode** — toggle switches the entire home feed to manga content

### 🎯 Mood-Based Quiz
A 4-step animated quiz that recommends anime tailored to your taste:

| Step | Options |
|------|---------|
| 1 — Mood | Dark & Intense, Fun & Lighthearted, Romantic, Action-packed, Relaxing, Epic Adventure |
| 2 — Genres | Action, Adventure, Comedy, Drama, Fantasy, Romance, Sci-Fi, Slice of Life, Thriller, Mystery, Horror, Sports |
| 3 — Length | Short (< 13 eps), Medium (13–50), Long (50+), Any |
| 4 — Status | Completed, Ongoing, Either |

### 🎬 Where to Watch
- Live streaming availability fetched from Jikan v4 per anime
- Platform tiles with favicons (Crunchyroll, Netflix, Funimation, Disney+, HIDIVE)
- One tap opens the **native streaming app** or falls back to browser
- Deep-link URI schemes: `crunchyroll://`, `netflix://`, `funimation://`, `disneyplus://`, `aiv://`
- Cached in Firestore for 7 days per user

### 📋 Watchlist
- Status: **Watching · Completed · On Hold · Dropped · Plan to Watch**
- Episode-by-episode progress tracking
- Personal ratings (0–10) and text reviews
- Filter tabs by status
- Synced to Cloud Firestore in real time

### 🔎 Search
- Real-time search with 600ms debounce
- Recent search history stored in Firestore
- Sorted by MAL score

### 📊 Stats
- Total anime tracked, episodes watched, estimated watch time
- Average personal rating
- Top 3 genres from your watchlist

### 👤 Profile
- Email/Password authentication
- Google Sign-In (one-tap)
- Display name management

### 🧭 Onboarding
- First-launch screen shown once via `SharedPreferences`

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ≥ 3.0) |
| State management | AppState (ChangeNotifier) + setState |
| Authentication | Firebase Auth — Email/Password + Google |
| Database | Cloud Firestore |
| Crash reporting | Firebase Crashlytics |
| Anime data | Jikan REST API v4 — free, no key |
| Trending data | AniList GraphQL API — free, no key |
| Image caching | cached_network_image |
| Local storage | shared_preferences |
| URL launching | url_launcher |
| Loading UI | shimmer |
| Design system | Material You (Material 3), ThemeMode.system |
| Seed color | `#6C5CE7` (purple) |

---

## 📁 Project Structure

```
lib/
├── main.dart               ← Firebase init, Crashlytics, onboarding gate
├── app_state.dart          ← Global anime/manga mode, auth listener
├── anime.dart              ← Anime, Manga, StreamingLink data models
├── media_base.dart         ← Abstract base for Anime/Manga polymorphism
├── jikan_service.dart      ← Jikan API (throttled, cached, auto-retry)
├── anilist_service.dart    ← AniList GraphQL (trending, spotlight)
├── firebase_service.dart   ← Auth, Firestore CRUD, Crashlytics helpers
├── streaming_utils.dart    ← Platform deep-link URI resolver
├── web_image.dart          ← Conditional import router (CORS fix for web)
├── web_image_stub.dart     ← Non-web image implementation
├── web_image_web.dart      ← Web image via HtmlElementView
├── utils/
│   └── snackbar_utils.dart ← showError() and showSuccess() helpers
├── home_screen.dart        ← Bottom-nav shell, AotD, seasonal, top
├── quiz_screen.dart        ← 4-step animated quiz
├── results_screen.dart     ← Quiz results grid
├── detail_screen.dart      ← Full detail (synopsis, trailer, streaming)
├── search_screen.dart      ← Debounced search + history chips
├── watchlist_screen.dart   ← Status-filter tabs
├── watch_status_sheet.dart ← Change status & episode progress
├── rating_sheet.dart       ← Star rating + review
├── stats_screen.dart       ← Personal stats dashboard
├── profile_screen.dart     ← Auth UI + Google Sign-In
└── onboarding_screen.dart  ← First-launch onboarding
```

---

## 📦 Key Dependencies

```yaml
dependencies:
  firebase_core: ^3.6.0
  cloud_firestore: ^5.4.4
  firebase_auth: ^5.3.1
  firebase_crashlytics: ^4.1.0
  google_sign_in: ^6.2.1
  http: ^1.2.0
  cached_network_image: ^3.4.0
  shared_preferences: ^2.3.0
  url_launcher: ^6.3.0
  shimmer: ^3.0.0
  flutter_native_splash: ^2.4.0
  flutter_launcher_icons: ^0.14.0
```

---

## 🌐 Supported Platforms

| Platform | Status |
|----------|--------|
| Android | ✅ Supported |
| iOS | ✅ Supported |
| Web (Chrome / Edge) | ✅ Supported |
| Windows | ✅ Supported |
| macOS | ✅ Supported |
| Linux | ✅ Supported |

---

## 🔧 Troubleshooting

**Jikan 429 rate limit errors**
Built-in 400ms throttle between requests + automatic single retry on 429.

**Images not loading on web**
Run with `--web-renderer html`. The `web_image_web.dart` CORS fix uses `HtmlElementView` to inject native `<img>` tags.

**Google Sign-In fails on Android release build**
Add your release SHA-1 fingerprint to Firebase Console → Project Settings → Your Android app.

**Crashlytics not showing data**
Crashlytics is disabled in debug mode (`kDebugMode = true`). Run a release build: `flutter run --release`. Data appears in Firebase Console within 5 minutes of first crash.

---

## 💡 Implementation Notes

| Topic | Detail |
|-------|--------|
| Jikan rate limiting | 400ms delay between requests, single retry on HTTP 429 |
| In-memory cache | 5-minute TTL per endpoint, invalidated on app restart |
| Streaming cache TTL | 7 days in Firestore, auto-refreshed on expiry |
| Recommendation algorithm | Mood → genre ID mapping + Jikan search + client-side episode filter |
| Anime of the Day | `dayOfYear % topAnime.length` — deterministic, changes at midnight |
| Offline support | Firestore SDK offline persistence for previously fetched docs |
| Crashlytics scope | Fatal + non-fatal errors, custom keys (appMode), user ID (uid only) |
| Deep-link fallback | Native app → web URL → MyAnimeList page |

---

## 📄 License

Created for personal/educational use. All anime data belongs to MyAnimeList via the unofficial [Jikan API](https://jikan.moe/). Manga and trending data from [AniList](https://anilist.co/). Review their terms before deploying publicly.
