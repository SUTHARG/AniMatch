# 🎌 AniMatch

> A cross-platform anime discovery and tracking app built with **Flutter** & **Firebase**.

AniMatch helps you find the perfect anime to watch through a personalized mood-based quiz, browse trending titles, track your watchlist, log your viewing progress, and instantly jump to a streaming platform — all in a sleek **Material You** interface.

---

## 📸 Overview

AniMatch is a full-featured anime companion app targeting Android, iOS, Web, Windows, macOS, and Linux from a single Flutter codebase. It integrates with the free [Jikan REST API v4](https://jikan.moe/) (unofficial MyAnimeList API) for anime data and with **Firebase** for authentication and cloud-synced user data.

---

## ✨ Features

### 🏠 Home
- **Anime of the Day** — A daily curated pick from the top-rated list, deterministically selected so it changes every 24 hours
- **Currently Airing** — Horizontal scroll list of anime airing this season
- **Top Rated All Time** — Horizontal scroll list of the all-time highest-ranked anime from MyAnimeList

---

### 🎯 Mood-Based Quiz
A 4-step animated quiz that recommends anime tailored to your taste:

| Step | What you pick |
|------|--------------|
| 1 | **Mood** — Dark & Intense, Fun & Lighthearted, Romantic & Emotional, Action-packed, Relaxing & Chill, Epic Adventure |
| 2 | **Genres** — Action, Adventure, Comedy, Drama, Fantasy, Romance, Sci-Fi, Slice of Life, Thriller, Mystery, Horror, Sports |
| 3 | **Episode Length** — Short (< 13 eps), Medium (13–50 eps), Long (50+ eps), Any |
| 4 | **Airing Status** — Completed, Ongoing, Either |

Results are fetched from Jikan with smart client-side filtering and built-in API rate-limit handling.

---

### 🎬 Where to Watch *(New)*

The detail page for every anime now includes a fully dynamic **"Where to Watch"** section that tells you exactly where you can stream it — and gets you there in one tap.

#### How it works

When you open any anime detail page, AniMatch calls the Jikan v4 `/anime/{id}/streaming` endpoint to fetch a live list of platforms currently carrying that title (e.g. Crunchyroll, Netflix, Funimation, Disney+, HIDIVE, Amazon Prime Video). Each platform is displayed as a tappable card with:

- **Platform favicon** — loaded via Google's public favicon service (`https://www.google.com/s2/favicons?sz=64&domain=…`), with a lettered avatar fallback if the favicon fails to load
- **Platform name & URL preview** — bold name, truncated URL shown as subtitle
- **Open-in-new-tab icon** — visual affordance that tapping opens an external destination
- **One-tap launch** — tapping a tile immediately opens the streaming platform

#### Native app deep-linking

On Android and iOS, AniMatch attempts to open the streaming platform's **native app** instead of the browser. The `lib/streaming_utils.dart` file maps platform names to their URI schemes:

| Platform | Deep-link scheme |
|----------|-----------------|
| Crunchyroll | `crunchyroll://` |
| Netflix | `netflix://` |
| Amazon Prime Video | `aiv://` |
| Funimation | `funimation://` |
| Disney+ | `disneyplus://` |
| HIDIVE & others | Falls back to browser |

If the native app is not installed, `url_launcher` falls back gracefully to the platform's web URL opened in the default browser (`LaunchMode.externalApplication`).

#### Empty state & MyAnimeList fallback

When Jikan returns no streaming links for an anime (common for older or region-locked titles), a clean empty-state card is shown with:
- A `live_tv_outlined` icon and a "No streaming links available" message
- A **"Open on MyAnimeList"** button that links directly to `https://myanimelist.net/anime/{id}`

A secondary **"View on MyAnimeList"** `OutlinedButton` is always rendered at the bottom of the streaming section, regardless of how many platform links are present.

#### Firestore caching

To avoid hammering the Jikan API on every detail-page open, streaming links are cached in Cloud Firestore under each user's document at:

```
users/{uid}/streamingCache/{malId}
```

The cache stores the full list of `{ name, url }` pairs plus a `cachedAt` server timestamp. Cached data is considered fresh for **7 days**; after that, a new Jikan fetch is triggered automatically and the cache is overwritten.

#### Loading animations & accessibility

- A **shimmer placeholder** animates in the section header while data is loading, powered by an `AnimationController` driving a `LinearGradient`
- Platform tiles **stagger-fade in** on arrival using `TweenAnimationBuilder` with a 60 ms delay per item (slide from `Offset(0, 0.2)` + `FadeTransition`)
- The entire section wraps in an `AnimatedSwitcher` (300 ms, `Curves.easeInOut`) so the transition from loading → data (or empty state) is smooth
- Every interactive element carries a `Semantics` label: e.g. *"Watch Attack on Titan on Crunchyroll. Opens external app."*

---

### 📋 Watchlist
- Add any anime to a personal watchlist synced to **Cloud Firestore**
- Set watch status: **Watching · Completed · On Hold · Dropped · Plan to Watch**
- Log **episode-by-episode progress**
- Write **personal ratings** (0–10 stars) and **text reviews**
- Filter watchlist by status category

---

### 🔎 Search
- Real-time search across the entire MyAnimeList catalogue, sorted by score

---

### 📊 Stats
- Total anime tracked, total episodes watched, and estimated watch time (minutes)
- Average personal rating and ratings-given count
- Top 3 favourite genres derived from your watchlist

---

### 👤 Profile
- **Firebase Email / Password** authentication (Sign Up & Sign In)
- Display name management
- Sign out

---

### 🧭 Onboarding
- First-launch onboarding screen (shown exactly once per device via `SharedPreferences`)

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | [Flutter](https://flutter.dev/) (Dart ≥ 3.11) |
| Authentication | [Firebase Auth](https://firebase.google.com/products/auth) — Email / Password |
| Database | [Cloud Firestore](https://firebase.google.com/products/firestore) |
| Anime Data | [Jikan REST API v4](https://docs.api.jikan.moe/) — free, no key required |
| Image Caching | [`cached_network_image`](https://pub.dev/packages/cached_network_image) |
| Local Storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| URL Launching | [`url_launcher`](https://pub.dev/packages/url_launcher) |
| Design System | Material You (Material 3), system light/dark theme |

---

## 📁 Project Structure

```
lib/
├── main.dart               # App entry point — Firebase init, onboarding gate
├── anime.dart              # Anime, QuizAnswers & StreamingLink data models
├── jikan_service.dart      # Jikan API client (throttled, auto-retry on 429)
├── firebase_service.dart   # Firebase Auth + Firestore CRUD, stats, streaming cache
├── streaming_utils.dart    # Platform name → native deep-link URI resolver  ← NEW
├── home_screen.dart        # Bottom-nav shell + Home tab (AotD, Seasonal, Top)
├── quiz_screen.dart        # 4-step animated recommendation quiz
├── results_screen.dart     # Quiz results grid
├── detail_screen.dart      # Full anime detail page (synopsis, trailer, similar, streaming)
├── search_screen.dart      # Real-time anime search
├── watchlist_screen.dart   # Watchlist with status-filter tabs
├── watch_status_sheet.dart # Bottom sheet — change watch status & episode progress
├── rating_sheet.dart       # Star rating + review bottom sheet
├── stats_screen.dart       # Personal stats dashboard
├── profile_screen.dart     # Auth UI and profile management
└── onboarding_screen.dart  # First-launch onboarding
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **≥ 3.11**
- A Firebase project with **Authentication (Email/Password)** and **Cloud Firestore** enabled
- Active internet connection — the Jikan API is public and requires no API key

### 1. Clone the repository

```bash
git clone <your-repo-url>
cd AniMatch
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

**Android**
Place `google-services.json` inside `android/app/`.

**iOS / macOS**
Place `GoogleService-Info.plist` inside the respective platform directory.

**Web**
Edit the `FirebaseOptions` block in `lib/main.dart` with your own project credentials:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.firebasestorage.app",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
  ),
);
```

> ⚠️ **Never commit real Firebase credentials to a public repository.**  
> Consider using environment variables or [`--dart-define`](https://docs.flutter.dev/deployment/obfuscate) to inject secrets safely.

### 4. Android — url_launcher query declaration

`url_launcher` requires the following `<queries>` block in `android/app/src/main/AndroidManifest.xml` so Android allows the app to check for and open external URLs and native streaming apps:

```xml
<manifest>
  <queries>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="https" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="crunchyroll" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="netflix" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="aiv" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="funimation" />
    </intent>
    <intent>
      <action android:name="android.intent.action.VIEW" />
      <data android:scheme="disneyplus" />
    </intent>
  </queries>
  ...
</manifest>
```

### 5. Run the app

```bash
# Any connected device / emulator
flutter run

# Specific target
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
```

---

## 🌐 Supported Platforms

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| Web (Chrome / Edge) | ✅ Supported |
| Windows  | ✅ Supported |
| macOS    | ✅ Supported |
| Linux    | ✅ Supported |

---

## 📦 Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  cloud_firestore: ^5.4.4
  firebase_auth: ^5.3.1
  http: ^1.2.0
  cached_network_image: ^3.3.1
  shared_preferences: ^2.2.3
  url_launcher: ^6.3.0        # ← Added for "Where to Watch" deep-links
  cupertino_icons: ^1.0.8
```

---

## 💡 Implementation Notes

| Topic | Detail |
|-------|--------|
| **Jikan rate limiting** | `JikanService` enforces a 400 ms delay between requests and automatically retries once on HTTP 429 |
| **Streaming data source** | Jikan v4 endpoint `GET /anime/{id}/streaming` — free, no key, returns `[{ name, url }]` |
| **Deep-link resolution** | `streaming_utils.dart` maps platform names to native URI schemes; `url_launcher` tries the deep-link first, falls back to the web URL, then falls back to the MAL page |
| **Streaming cache TTL** | Links stored in Firestore under `users/{uid}/streamingCache/{malId}` with a `cachedAt` timestamp; re-fetched after 7 days |
| **Recommendation algorithm** | Mood → genre ID mapping + user-selected genres → Jikan search; client-side episode-length filter; up to 6 API pages fetched; results shuffled for variety |
| **Offline support** | Firestore SDK default settings provide offline persistence for previously fetched documents (including streaming cache) |
| **Theming** | Material 3 with seed colour `#6C5CE7` (purple), `ThemeMode.system` — follows device light/dark setting |
| **Anime of the Day** | Deterministic: `dayOfYear % topAnime.length` — same pick all day, different every day |
| **Accessibility** | Every streaming tile and MAL fallback button carries a descriptive `Semantics` label for screen readers |

---

## 📄 License

This project is for personal/educational use. Anime data is sourced from [MyAnimeList](https://myanimelist.net/) via the unofficial [Jikan API](https://jikan.moe/) — please review their [terms of service](https://jikan.moe/) before deploying a public app.