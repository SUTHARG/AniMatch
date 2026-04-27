# 🎌 AniMatch — The Anime Decision Engine

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.x-00B4D8)](https://riverpod.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![flutter analyze](https://img.shields.io/badge/flutter%20analyze-passing-brightgreen)](https://dart.dev/tools/linter-rules)

**A high-performance, premium Anime & Manga companion app built with Flutter, Riverpod & Firebase.**

AniMatch is not just another tracker — it's an **Anime Decision Engine**. Designed to cure choice paralysis, it combines a stunning Glassmorphic UI with a sophisticated Hybrid Recommendation Engine, real-time streaming data, and seamless cloud sync across all devices.

[Features](#-features) · [Architecture](#-architecture) · [Getting Started](#-getting-started) · [Contributing](#-contributing) · [Roadmap](#-roadmap)

</div>

---
##  Demo

### Home Screen
https://github.com/SUTHARG/AniMatch/raw/main/assets/demo/home_screen.mp4

### Mood Quiz
https://github.com/SUTHARG/AniMatch/raw/main/assets/demo/Quiz_Flow.mp4

### Where to Watch
https://github.com/SUTHARG/AniMatch/raw/main/assets/demo/where_to_watch_and_watch_trailer.mp4

### Watchlist
https://github.com/SUTHARG/AniMatch/raw/main/assets/demo/Watchlist_saving.mp4

##  Features

###  Home Dashboard
- **Anime of the Day** — deterministically selected daily (`dayOfYear % topAnime.length`), changes at midnight
- **Spotlight Banner** — curated trending picks from AniList GraphQL
- **Currently Airing** — live seasonal data from AniList
- **Top Rated All Time** — highest-ranked titles from MyAnimeList via Jikan
- **Anime / Manga mode toggle** — switches the entire feed, synced to cloud

###  The Recommendation Engine
A production-grade **On-Device Hybrid Recommendation Engine**:
- **3 Recommendation Modes** — Standard, Quiz-targeted, Discovery (hidden gems)
- **Mathematical Scoring Pipeline:**
```
S(a,u) = α(Content Similarity) + β(Behavioral Match) + γ(Temporal Recency) + δ(Rating) + ε(Novelty)
```
- **Deterministic Jitter** — stable picks over a 24-hour window, different every day
- Results are filtered, boosted for decisive margins, and never repeat the same show two days running

###  Mood-Based Quiz
A 4-step animated quiz acting as a rapid filter for the recommendation engine:

| Step | Options |
|------|---------|
| 1 — Mood | Dark & Intense · Fun & Lighthearted · Romantic · Action-packed · Relaxing · Epic Adventure |
| 2 — Genres | Action · Adventure · Comedy · Drama · Fantasy · Romance · Sci-Fi · Slice of Life · Thriller · Mystery · Horror · Sports |
| 3 — Length | Short (< 13 eps) · Medium (13–50) · Long (50+) · Any |
| 4 — Status | Completed · Ongoing · Either |

###  Where to Watch
- Live streaming availability fetched from Jikan v4 per anime
- Platform tiles with favicons (Crunchyroll, Netflix, Funimation, Disney+, HIDIVE, Amazon)
- **One tap opens the native streaming app** via URI deep-links
- Falls back gracefully: native app → browser → MyAnimeList page
- Results cached in Firestore per user with **7-day TTL**

| Platform | Deep-link |
|----------|-----------|
| Crunchyroll | `crunchyroll://` |
| Netflix | `netflix://` |
| Funimation | `funimation://` |
| Disney+ | `disneyplus://` |
| Amazon Prime | `aiv://` |
| Others | Browser fallback |

###  Cloud-Synced Watchlist
- Status: **Watching · Completed · On Hold · Dropped · Plan to Watch**
- Episode-by-episode progress tracking
- Personal ratings (0–10 stars) and text reviews
- Filter tabs by status — synced to Firestore in real time with offline persistence

###  Search
- Real-time search with **600ms debounce**
- Recent search history stored in Firestore
- History chips for one-tap re-search + Clear history button
- Results sorted by MAL score

###  Personal Stats
- Total anime tracked, episodes watched, estimated watch time
- Average personal rating · Top 3 favourite genres

###  Profile & Auth
- Email/Password + **Google Sign-In** (one-tap)
- Display name management · App mode synced to cloud

###  Onboarding
- First-launch screen shown **exactly once** via SharedPreferences
- Uses `Navigator.pushReplacement` — user can never navigate back

###  Crashlytics
- All uncaught Flutter framework errors captured automatically
- All async zone errors captured via `runZonedGuarded`
- Non-fatal API errors logged with context (endpoint, reason)
- **Disabled in debug mode** — only active in release builds
- Only uid attached — no PII collected

---

##  Architecture

AniMatch follows a strictly layered, unidirectional architecture.

### High-Level Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        Flutter UI Layer                          │
│        Screens · Widgets · Bottom Sheets · Navigation            │
└──────────────────────────────┬───────────────────────────────────┘
                               │ watches / reads
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Riverpod Providers Layer                       │
│  RecommendationProvider · WatchlistProvider · AuthProvider       │
│  SearchProvider · StatsProvider · AppModeProvider                │
└──────────┬───────────────────┬───────────────────┬──────────────┘
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│ AnimeRepository │  │ MangaRepository  │  │   UserRepository     │
│ Single source   │  │ Single source    │  │   Single source      │
│ of truth        │  │ of truth         │  │   of truth           │
└────────┬────────┘  └────────┬─────────┘  └──────────┬───────────┘
         │                   │                        │
         ▼                   ▼                        ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│  JikanService   │  │ AniListService   │  │   FirebaseService    │
│  REST client    │  │ GraphQL client   │  │   Auth + Firestore   │
│  400ms throttle │  │ Trending/Spot    │  │   Crashlytics        │
│  5min mem cache │  │ 5min mem cache   │  │   Streaming cache    │
└────────┬────────┘  └────────┬─────────┘  └──────────┬───────────┘
         │                   │                        │
         ▼                   ▼                        ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│ Jikan REST v4   │  │ AniList GraphQL  │  │  Firebase Cloud      │
│ api.jikan.moe   │  │ graphql.anilist  │  │  Auth + Firestore    │
│ Free, no key    │  │ Free, no key     │  │  Crashlytics         │
└─────────────────┘  └──────────────────┘  └──────────────────────┘
         │                                            │
         └─────────────────┬──────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                       Local Cache Layer                          │
│  Hive (offline anime data) · SharedPreferences (flags)          │
│  cached_network_image (cover art) · Firestore offline SDK       │
└──────────────────────────────────────────────────────────────────┘
```

### Folder Structure

```
lib/
├── core/
│   ├── constants/               # Colors, API endpoints, string keys
│   ├── error/                   # Custom exception classes
│   ├── theme/                   # Material 3 light/dark themes
│   └── utils/
│       └── snackbar_utils.dart  # showError() and showSuccess()
│
├── data/
│   ├── models/
│   │   ├── anime.dart           # Anime + StreamingLink models
│   │   ├── manga.dart           # Manga model
│   │   └── media_base.dart      # Abstract base for polymorphism
│   ├── repositories/
│   │   ├── anime_repository.dart
│   │   ├── manga_repository.dart
│   │   └── user_repository.dart
│   └── sources/
│       ├── jikan_service.dart   # Jikan REST (throttled, cached, retry)
│       ├── anilist_service.dart # AniList GraphQL (trending, spotlight)
│       ├── firebase_service.dart# Auth, Firestore, Crashlytics helpers
│       └── streaming_utils.dart # Deep-link URI resolver map
│
├── presentation/
│   ├── providers/
│   │   ├── recommendation_provider.dart
│   │   ├── watchlist_provider.dart
│   │   ├── search_provider.dart
│   │   ├── stats_provider.dart
│   │   └── app_state.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── quiz_screen.dart
│   │   ├── results_screen.dart
│   │   ├── detail_screen.dart
│   │   ├── search_screen.dart
│   │   ├── watchlist_screen.dart
│   │   ├── stats_screen.dart
│   │   ├── profile_screen.dart
│   │   └── onboarding_screen.dart
│   └── widgets/
│       ├── anime_card.dart
│       ├── watch_status_sheet.dart
│       ├── rating_sheet.dart
│       └── web_image.dart       # CORS fix for Flutter Web
│
└── main.dart                    # Entry point
```

### Firestore Data Structure

```
users/
└── {uid}/
    ├── displayName
    ├── appMode                        # "anime" | "manga"
    ├── watchlist/
    │   └── {malId}/
    │       ├── title
    │       ├── imageUrl
    │       ├── score
    │       ├── status                 # watching | completed |
    │       │                          # on_hold | dropped | plan_to_watch
    │       ├── episodeProgress
    │       ├── rating                 # 0–10
    │       ├── review
    │       └── addedAt
    ├── manga_watchlist/
    │   └── {malId}/
    │       └── (same + chapterProgress)
    ├── streamingCache/
    │   └── {malId}/
    │       ├── links                  # [{ name, url }]
    │       └── cachedAt               # 7-day TTL
    └── metadata/
        └── search/
            └── recentTerms            # string[] last 10 searches
```

### Caching Strategy

| Cache | Location | TTL |
|-------|----------|-----|
| API responses | In-memory `Map` in service classes | 5 minutes |
| Streaming links | Cloud Firestore per user | 7 days |
| Anime/manga data | Hive local database | Until evicted |
| Cover images | Device via `cached_network_image` | Until evicted |
| Firestore docs | Device via Firestore offline SDK | Until sync |

### App Boot Sequence

```
main()
 ├── WidgetsFlutterBinding.ensureInitialized()
 ├── SystemChrome.setPreferredOrientations([portrait])
 ├── dotenv.load()
 ├── Firebase.initializeApp()
 ├── Crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode)
 ├── FlutterError.onError = recordFlutterFatalError
 ├── PlatformDispatcher.onError = recordError
 ├── SharedPreferences.getBool('seen_onboarding')
 ├── AppState.init()
 └── runZonedGuarded(
       () => runApp(ProviderScope(child: AniMatchApp())),
       (e, s) => Crashlytics.recordError(e, s, fatal: true)
     )
```

### Security Model

```
1. Secrets        → .env via flutter_dotenv (never hardcoded)
2. Firebase files → google-services.json in .gitignore
3. Firestore      → Rules: users read/write own data only
4. Crashlytics    → uid only, no PII, debug-mode disabled
5. APIs           → Jikan & AniList are fully public, no keys
```

---

##  Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Flutter | ≥ 3.11 |
| State Management | Riverpod | ^3.3.1 |
| Authentication | Firebase Auth | ^5.3.1 |
| Database | Cloud Firestore | ^5.4.4 |
| Local Cache | Hive + Hive Flutter | ^2.2.3 |
| Crash Reporting | Firebase Crashlytics | ^4.1.0 |
| Anime Data | Jikan REST API v4 | free |
| Trending Data | AniList GraphQL | free |
| Image Caching | cached_network_image | ^3.4.0 |
| URL Launching | url_launcher | ^6.3.0 |
| Loading UI | shimmer | ^3.0.0 |
| Environment | flutter_dotenv | ^5.1.0 |
| Google Sign-In | google_sign_in | ^6.2.1 |
| Design System | Material You (Material 3) | — |
| Seed Color | `#6C5CE7` purple | — |

---

##  Supported Platforms

| Platform | Status |
|----------|--------|
| Android |  Supported (min SDK 21) |
| iOS |  Supported |
| Web (Chrome / Edge) |  Supported |
| Windows |  Supported |
| macOS |  Supported |
| Linux |  Supported |

---

##  Getting Started

### 1. Clone
```bash
git clone https://github.com/YOUR_USERNAME/AniMatch.git
cd AniMatch
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Environment variables
```bash
cp .env.example .env
# Edit .env and fill in your Firebase credentials
```

### 4. Firebase Setup (5 minutes)

1. Create project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **Authentication** → Email/Password + Google Sign-In
3. Enable **Cloud Firestore** in Production mode
4. Apply security rules:
```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```
5. Download `google-services.json` → place in `android/app/`
6. Download `GoogleService-Info.plist` → place in `ios/Runner/`

> These files are in `.gitignore`. Never commit them to a public repo.

### 5. Run
```bash
flutter run                              # Debug
flutter build apk --release             # Android release
flutter run -d chrome --web-renderer html  # Web
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Jikan 429 errors | Built-in 400ms throttle + auto-retry handles this |
| Images broken on web | Use `--web-renderer html` flag |
| Google Sign-In fails on release | Add release SHA-1 to Firebase Console |
| Crashlytics not showing data | Only active in release builds |
| Onboarding shows every launch | Check `setBool('seen_onboarding', true)` is awaited |
| Build fails — missing config | Add `google-services.json` to `android/app/` |

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

---

##  Roadmap

### Completed
- Flutter multi-platform setup · Riverpod architecture
- Jikan REST v4 + AniList GraphQL integrations
- On-Device Hybrid Recommendation Engine (3 modes)
- Mood-Based Quiz · Where to Watch deep-links
- Firebase Auth (Email + Google) · Firestore sync
- Firebase Crashlytics (release-only)
- Shimmer loading · App icon · Splash screen
- Onboarding (show once) · `flutter analyze` passing 
- Release APK verified (55.7 MB) 

### Upcoming
- Firebase Analytics · Collaborative filtering
- Social layer (friend lists, watchlist sharing)
- CI/CD pipeline (GitHub Actions + Fastlane)
- Play Store + App Store launch

> See [roadmap.md](roadmap.md) for full details.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">

 **If you find AniMatch useful, please star the repository!** 

*Anime data from [MyAnimeList](https://myanimelist.net/) via [Jikan API](https://jikan.moe/) · Trending data from [AniList](https://anilist.co/)*

</div>
