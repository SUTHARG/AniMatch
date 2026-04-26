# AniMatch Architecture

> A deep-dive into the technical design decisions powering AniMatch.

---

## 1. The 5-Layer Architecture

AniMatch enforces a strict, unidirectional data pipeline. Each layer has one responsibility and communicates only with the layer directly below it.

```text
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1 · USER INTERACTION                                     │
│  Flutter Widgets · Screens · Animated UI components            │
└──────────────────────────────┬──────────────────────────────────┘
                               │  watch() / read() / notifyListeners
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2 · APP STATE & PROVIDERS                                │
│  Riverpod Providers · AppState · NotifierProviders              │
│  RecommendationProvider · AnimeProvider · WatchlistProvider     │
└────────────┬──────────────────────┬─────────────────────────────┘
             │                      │
             ▼                      ▼
┌────────────────────┐  ┌───────────────────────────────────────┐
│  Layer 3 · REPOS   │  │  Layer 3 · SCORING ENGINE             │
│  AnimeRepository   │  │  scoring_engine.dart                  │
│  WatchlistRepo     │  │  Hybrid on-device recommendation      │
└──────────┬─────────┘  └───────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4 · SERVICES (Data Sources)                              │
│  JikanService · AniListService · FirebaseService                │
└──────────┬─────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 5 · EXTERNAL SYSTEMS                                     │
│  Jikan REST v4 · AniList GraphQL · Firebase (Auth+Firestore)   │
│  Hive (local) · SharedPreferences · Firebase Crashlytics        │
└─────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Files | Responsibility |
|-------|-------|----------------|
| UI Screens | `lib/presentation/screens/` | Render state, dispatch actions. Zero business logic. |
| Providers | `lib/presentation/providers/` | Manage state, orchestrate async flows. |
| Repositories | `lib/data/repositories/` | Single source of truth — decides cache vs network. |
| Services | `lib/data/sources/` | Low-level API/Firebase clients. Handles parsing & errors. |
| External | Firebase, Jikan, AniList | The actual data. Never accessed directly by UI. |

---

## 2. Full Folder Structure

```text
lib/
├── core/
│   ├── app_state.dart              # Global auth state + app mode
│   ├── constants/                  # App-wide colors, strings, API constants
│   ├── theme/                      # Light & dark MaterialTheme definitions
│   └── utils/                      # Date formatters, number helpers
├── data/
│   ├── models/
│   │   ├── anime.dart              # Anime (JsonSerializable, full MAL schema)
│   │   ├── manga.dart              # Manga model
│   │   ├── media_base.dart         # Shared base interface
│   │   └── hero_recommendation.dart # Typed result from ScoringEngine
│   ├── repositories/
│   │   ├── anime_repository.dart   # Fetch + cache coordination (Jikan/AniList)
│   │   ├── watchlist_repository.dart # CRUD to Firestore watchlist
│   │   └── scoring_engine.dart     # ⭐ The Hybrid Recommendation Algorithm
│   └── sources/
│       ├── firebase/               # FirebaseService (auth, Firestore, Crashlytics)
│       ├── local/                  # Hive box helpers + SharedPreferences wrappers
│       └── remote/                 # JikanService (REST) + AniListService (GraphQL)
└── presentation/
    ├── providers/                  # All Riverpod providers (anime, watchlist, rec)
    ├── screens/
    │   ├── home_screen.dart        # Main dashboard (Today + Airing + Top Rated)
    │   ├── quiz_screen.dart        # 4-step mood quiz flow
    │   ├── results_screen.dart     # Decisive recommendation display
    │   ├── detail_screen.dart      # Full anime detail + Where to Watch
    │   ├── watchlist_screen.dart   # Watchlist management UI
    │   ├── stats_screen.dart       # Personal stats dashboard
    │   ├── profile_screen.dart     # Account settings + sign out
    │   ├── search_screen.dart      # Real-time Jikan search
    │   ├── login_screen.dart       # Auth (Email + Google Sign-In)
    │   └── onboarding_screen.dart  # First-launch walkthrough (shown once)
    └── widgets/                    # Reusable: AnimeCard, shimmer loaders, etc.
```

---

## 3. The Recommendation Engine

### RecommendationMode System

The `ScoringEngine` operates in one of three modes, selected at runtime:

| Mode | Trigger | Behaviour |
|------|---------|-----------|
| `standard` | Home screen "For You" | Full pipeline against user history. |
| `quiz` | After 4-step Mood Quiz | Applies hard genre/length/status filters before scoring. |
| `discovery` | Explore / hidden gems | Increases the novelty weight `ε`, discourages mainstream titles. |

### Scoring Pipeline

For each candidate anime `a` scored against user profile `u`:

```text
S(a,u) = α · cosine(gₐ, gᵤ)              [content similarity — genre vectors]
       + β · (1 − KL(Pₐ ∥ Pᵤ) / 5)      [behavioral distribution match]
       + γ · cosine(gₐ, gᵤ_temporal)     [recency-weighted preference]
       + δ · bayesian_rating              [popularity-adjusted quality]
       + ε · novelty                      [anti-repetition bonus]
```

**Post-processing:**
1. **Power Sharpening** — `S^2.5` amplifies differences so the winner is decisive.
2. **Margin Enforcement** — If the gap between #1 and #2 is < threshold, #1 is boosted.
3. **Deterministic Jitter** — `rng(userHash + dayOfYear)` for stable daily tie-breaking.
4. **Soft Floor** — Confidence rescaled to `[60%, 99%]` via sigmoid for reassuring UX.

**Sparsity fallback:** When watchlist has < 3 rated items, `KL Divergence` falls back to the simpler `L1 overlap`.

---

## 4. Local Cache Strategy (Hive)

| Cache | TTL | Backend |
|-------|-----|---------|
| Top anime lists | 5 minutes (in-memory) | Jikan API |
| Streaming availability | 7 days | Firestore per-user doc |
| Onboarding state | Permanent | `SharedPreferences` |
| User watchlist | Real-time | Firestore (offline persistence) |

---

## 5. flutter_dotenv Usage

All sensitive credentials are loaded at app startup via `flutter_dotenv`:

```dart
// main.dart
await dotenv.load(fileName: ".env");

// firebase_options.dart
apiKey: dotenv.env['FIREBASE_API_KEY']!,
```

The `.env` file is in `.gitignore`. New contributors copy `.env.example` → `.env` and fill in their own Firebase project credentials. **`firebase_options.dart` contains zero hardcoded secrets** and is safe to commit.

---

## 6. Security Design

| Concern | Solution |
|---------|----------|
| API keys in code | All keys in `.env` via `flutter_dotenv` |
| Firebase credentials | `google-services.json` / `GoogleService-Info.plist` in `.gitignore` |
| User data isolation | Firestore rules enforce `request.auth.uid == userId` |
| Crash data | Crashlytics — disabled in `kDebugMode`, active in release only |
| Signing keys | `*.jks` / `key.properties` in `.gitignore` — never committed |

---

## 7. Key Third-Party Integrations

### Jikan REST API v4 (MyAnimeList)
- Rate limit: **3 req/sec** — handled with a 400ms inter-request throttle.
- Auto-retry once on HTTP 429.
- Base URL configurable via `JIKAN_BASE_URL` in `.env`.

### AniList GraphQL API
- No auth token required for read operations.
- Used for: currently airing, trending, seasonal spotlight.
- Base URL: `ANILIST_BASE_URL` in `.env`.

### Firebase
- **Auth**: Email/Password + Google Sign-In.
- **Firestore**: Real-time watchlist sync with offline persistence.
- **Crashlytics**: Release-only error reporting.
