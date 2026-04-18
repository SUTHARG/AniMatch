# 🎌 AniMatch: Total Discovery & Tracking

> A high-performance, premium Anime & Manga companion app built with **Flutter** & **Firebase**.

AniMatch is designed to provide a "no-compromise" experience for fans. It combines a **Glassmorphic UI** with a sophisticated **Hybrid API Architecture** to deliver instant data, real-time schedules, and seamless cloud synchronization across all devices.

---

## 🚀 Detailed Setup Guide

If you are building this project from scratch, follow these exact steps to ensure everything functions perfectly.

### 1. Prerequisites
- **Flutter SDK**: `^3.11.0` (Master or Stable channel)
- **Dart SDK**: `^3.0.0`
- **Firebase Account**: Access to the [Firebase Console](https://console.firebase.google.com/)

### 2. Firebase Configuration (CRITICAL)
AniMatch relies heavily on Firebase for its "Cloud Sync" features. You **must** enable the following services:

#### A. Authentication
1. Go to **Authentication** > **Sign-in method**.
2. Enable **Email/Password**.
3. Enable **Google Sign-In** (Required for the premium one-tap login).
   - *Note*: For Android, you must generate an **SHA-1 fingerprint** and add it to your Firebase project settings.

#### B. Cloud Firestore
1. Initialize Firestore in **Production Mode**.
2. **Collection Structure**:
   - `users/{uid}`: Stores display names and global preferences (e.g., `appMode: 'anime'`).
   - `users/{uid}/watchlist/{malId}`: Individual anime tracking data (progress, rating, status).
   - `users/{uid}/manga_watchlist/{malId}`: Individual manga tracking data.
   - `users/{uid}/metadata/search`: String array of recent search terms.
   - `users/{uid}/streamingCache/{malId}`: Temporary storage for Jikan streaming links (7-day TTL).

3. **Security Rules**:
   ```javascript
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

### 3. API Hybrid Strategy
AniMatch uses two different APIs to provide a "best-in-class" experience:

| Feature | Provider | Why? |
|---------|----------|------|
| **Trending/Seasonal** | [AniList (GraphQL)](https://anilist.co) | Superior speed and curated "Spotlight" banners. |
| **Airing Schedule** | [Jikan (REST)](https://jikan.moe) | Provides accurate "Estimated Time" data not easily found in AniList. |
| **Manga Search** | [Jikan (REST)](https://jikan.moe) | Comprehensive MyAnimeList database access. |

---

## 🛠️ Internal Architecture

### 🛡️ Smart Caching Layer
To bypass Jikan's strict rate limits (3 requests/second) and prevent "loading fatigue," we implemented a custom **In-Memory Cache** in `AnilistService` and `JikanService`:
- **Logic**: Every API response is stored in a `Map` with a `DateTime` timestamp.
- **TTL**: Data expires every **5 minutes**.
- **Result**: Navigating between "Today" and "Tomorrow" in the schedule is instantaneous.

### 🌓 AppState & Real-time Sync
The `AppState` class (Singleon) manages the global **Anime vs Manga** mode.
- **Auth Listener**: It listens to `FirebaseAuth.instance.authStateChanges()`.
- **Cloud Pull**: When a user logs in, `AppState` automatically fetches their saved `appMode` from Firestore.
- **Auto-Push**: Any change to the mode is immediately pushed to the cloud.

### 🖼️ Web Image Rendering (CORS Fix)
On Flutter Web, images from `cdn.myanimelist.net` often fail due to CORS. 
- **Solution**: We use `web_image_web.dart`, which utilizes `HtmlElementView` to inject a native browser `<img>` tag. This bypasses Flutter's canvas-based image restrictions.

---

## 📂 File Directory Breakdown

| File | Purpose |
|------|---------|
| `lib/anilist_service.dart` | GraphQL queries for Home Screen trends. |
| `lib/jikan_service.dart` | REST calls for Schedules, Manga, and Recommendations. |
| `lib/app_state.dart` | Global state management (ValueNotifiers). |
| `lib/firebase_service.dart` | All interactions with Firestore & Auth. |
| `lib/media_base.dart` | The abstract core for `Anime` and `Manga` polymorphism. |
| `lib/home_screen.dart` | The premium main dashboard with scrollable day-picker. |

---

## 🔧 Troubleshooting

- **Jikan 429 Errors**: If you exceed the rate limit, the service has a built-in `Future.delayed` retry logic.
- **Search Latency**: Search is debounced by 600ms to preserve API health.
- **Web Build**: Always run with `--web-renderer html` to ensure the native image tags work correctly:
  ```bash
  flutter run -d chrome --web-renderer html
  ```

---

## 📄 License
Created for personal/educational use. All data belongs to MyAnimeList/AniList. Premium UI inspired by modern streaming apps.
