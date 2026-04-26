// lib/core/constants/api_constants.dart
//
// Central place for all external API configuration.
// Base URLs are loaded from .env via flutter_dotenv so the app
// can be pointed at a staging/mock server without a code change.
//
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  ApiConstants._();

  // ── Base URLs (from .env) ────────────────────────────────────────────────
  /// Jikan REST v4 — unofficial MyAnimeList API. No API key required.
  static String get jikanBaseUrl =>
      dotenv.env['JIKAN_BASE_URL'] ?? 'https://api.jikan.moe/v4';

  /// AniList GraphQL endpoint. No API key required.
  static String get anilistBaseUrl =>
      dotenv.env['ANILIST_BASE_URL'] ?? 'https://graphql.anilist.co';

  // ── MyAnimeList web links (public — not sensitive) ───────────────────────
  static const String malAnimeBase = 'https://myanimelist.net/anime/';
  static const String malMangaBase = 'https://myanimelist.net/manga/';

  // ── Streaming deep-link URI schemes (public — not sensitive) ─────────────
  static const String crunchyrollScheme = 'crunchyroll://';
  static const String netflixScheme = 'netflix://';
  static const String amazonPrimeScheme = 'aiv://';
  static const String funimationScheme = 'funimation://';
  static const String disneyPlusScheme = 'disneyplus://';
}
