# 🎌 AniMatch Premium

> The ultimate Anime & Manga companion app built with **Flutter** & **Firebase**.

AniMatch transforms how you discover and track your favorites. Featuring a cinematic **Premium UI**, real-time **Airing Schedules**, and **Intelligent Recommendations**, it’s the only anime app you’ll ever need.

---

## ✨ Premium Features

### 🌖 Dual-Universe Support
- **Anime & Manga Modes**: Seamlessly toggle between full Anime and Manga experiences.
*   **Persistent Preferences**: Your chosen mode is synced to the cloud—log in on any device and your preference follows you.

### 📅 Intelligent Airing Schedule
- **Estimated Schedule**: A redesigned day-picker with a live digital clock.
- **Accurate Timing**: Real-time airing data fetched from Jikan, ensuring you never miss a premiere.
- **Visual Badges**: Clear episode counters and status markers.

### ⚡ Performance-First Architecture
- **AniList & Jikan Integration**: Leveraging the best of both worlds (AniList for discovery/trends, Jikan for schedules/manga).
- **Smart Caching Layer**: In-memory caching with Time-To-Live (TTL) ensures near-instant navigation and zero rate-limit delays.

### 🎯 Mood-Based Discovery
- **Personalized Quiz**: Tailored recommendations based on mood, length, and status.
- **Cloud-Synced History**: Previous quiz results are saved to your Firebase profile for easy reference.

### 📊 Real-Time Stats & Tracking
- **Unified Watchlist**: Track both Anime and Manga with episode/chapter progress.
- **Dynamic Stats**: Dashboard updates instantly with "Total Watch Time," "Average Score," and genre breakdowns.
- **Rating & Reviews**: Submit star ratings and full text reviews shared with the community.

---

## 🛠️ Tech Stack & Services

| Layer | Technology |
|-------|-----------|
| **Framework** | [Flutter](https://flutter.dev/) (Material 3 Hybrid Design) |
| **Authentication** | [Firebase Auth](https://firebase.google.com/products/auth) (Email + Google) |
| **Database** | [Cloud Firestore](https://firebase.google.com/products/firestore) (Real-time Sync) |
| **APIs** | [AniList GraphQL](https://anilist.gitbook.io/external-site-documentation/) & [Jikan REST v4](https://jikan.moe/) |
| **Caching** | Custom TTL In-Memory Layer |

---

## 📁 Updated Architecture

```text
lib/
├── anilist_service.dart    # GraphQL client for trending/seasonal anime
├── jikan_service.dart      # REST client for schedules and manga search
├── app_state.dart          # Centralized Auth-aware state (Mode, Cloud Sync)
├── firebase_service.dart   # Firestore CRUD, user-specific data tracking
├── home_screen.dart        # Premium Dashboard & Estimated Schedule UI
├── media_base.dart         # Unified polymorphic interface for Anime/Manga
├── browse_magazines_screen.dart # Specialized Manga discovery
└── image_utils.dart        # CORS-safe native image rendering
```

---

## 🚀 Getting Started

### 1. Clone & Install
```bash
git clone https://github.com/SUTHARG/AniMatch.git
cd AniMatch
flutter pub get
```

### 2. Configure Firebase
*   **Android**: Place `google-services.json` in `android/app/`.
*   **iOS**: Add `GoogleService-Info.plist` via Xcode.
*   **Web**: Update the configuration in `lib/main.dart`.

### 3. Run
```bash
# Standard Run
flutter run

# High-Performance Web Mode
flutter run -d chrome --web-renderer html
```

---

## 💡 Implementation Notes
- **API Strategy**: Uses AniList for high-speed discovery and Jikan for deep metadata/manga.
- **Theming**: Premium Dark mode optimized with `#6C5CE7` accent colors and glassmorphic overlays.
- **Security**: Firestore Rules are optimized for per-user data isolation.

---

## 📄 License
This project is for personal/educational use. Data provided by [AniList](https://anilist.co) and [MyAnimeList](https://myanimelist.net/).
