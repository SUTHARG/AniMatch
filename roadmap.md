# Roadmap

> This document tracks what has been built and where AniMatch is headed next.
> Completed phases are marked with ✅. Planned phases are open for contributions!

---

## ✅ Phase 1 — Foundation & Architecture

- ✅ Flutter multi-platform project setup (Android, iOS, Web, Windows, macOS, Linux)
- ✅ Riverpod state management across the entire app
- ✅ Layered clean architecture (`core/`, `data/`, `presentation/`)
- ✅ flutter_dotenv environment variable system
- ✅ App icon + splash screen
- ✅ Onboarding flow (shown once via `SharedPreferences`)

## ✅ Phase 2 — Core Data Integrations

- ✅ Jikan REST API v4 integration (MyAnimeList) with 400ms rate-limit throttle
- ✅ AniList GraphQL API integration (trending, currently airing, seasonal)
- ✅ `cached_network_image` for efficient image loading
- ✅ 5-minute in-memory cache for top anime lists

## ✅ Phase 3 — The Decisive Recommendation Engine

- ✅ On-device Hybrid Recommendation Algorithm (`scoring_engine.dart`)
- ✅ `RecommendationMode` system (standard / quiz / discovery)
- ✅ Mathematical scoring pipeline (Content + Behavioral + Temporal + Rating + Novelty)
- ✅ Power Sharpening, Margin Enforcement, Deterministic Jitter, Soft-Floor Confidence
- ✅ 4-step animated Mood Quiz (Mood → Genres → Length → Status)
- ✅ Sparsity fallback (KL Divergence → L1 overlap when watchlist < 3 items)

## ✅ Phase 4 — User Accounts & Cloud Sync

- ✅ Firebase Authentication (Email/Password & Google Sign-In)
- ✅ Cloud Firestore real-time watchlist sync
- ✅ Firestore offline persistence support
- ✅ 7-day streaming availability cache (Firestore TTL per user)
- ✅ Personal stats dashboard (time watched, avg rating, top 3 genres)

## ✅ Phase 5 — UX Polish & Production Readiness

- ✅ Where to Watch integration with native deep-links (Crunchyroll, Netflix, Disney+, etc.)
- ✅ Shimmer loading states throughout the app
- ✅ Firebase Crashlytics (release mode only)
- ✅ `flutter analyze` — **0 issues** ✔
- ✅ Release APK built and verified (**55.7 MB**)
- ✅ MIT License + open-source documentation (README, CONTRIBUTING, CODE_OF_CONDUCT, architecture, roadmap)

---

## 🔜 Phase 6 — Analytics & Observability

- [ ] Firebase Analytics integration (anonymous, privacy-first)
- [ ] Track key user journeys: quiz completion, recommendation acceptance rate
- [ ] Monitor Jikan API cache hit rates
- [ ] Firebase Performance Monitoring for network requests

## 🔜 Phase 7 — Recommendation Engine v2

- [ ] Collaborative filtering signals (aggregate anonymous user trends globally)
- [ ] Recommendation explanations in UI ("Because you loved _Steins;Gate_…")
- [ ] More granular mood-to-genre mappings
- [ ] "Surprise Me" mode — deliberate serendipity

## 🔜 Phase 8 — Social Layer

- [ ] User profiles with shareable watchlists
- [ ] Friend connections and compatibility scores
- [ ] Activity feed ("Your friend just completed _Vinland Saga_")
- [ ] Community lists and curated collections

## 🔜 Phase 9 — Play Store & App Store Launch

- [ ] GitHub Actions CI pipeline (lint → test → build → sign)
- [ ] Fastlane integration for automated Play Store deploys
- [ ] App store screenshot assets (6.5" + 5.5" iPhone, tablet)
- [ ] Comprehensive accessibility (a11y) audit
- [ ] Privacy Policy page (required for store listing)
- [ ] Submit to **Google Play Store**
- [ ] Submit to **Apple App Store**

---

*Want to work on any future phase? Check the [Issues board](https://github.com/YOUR_USERNAME/AniMatch/issues) or open a proposal. All contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).*
