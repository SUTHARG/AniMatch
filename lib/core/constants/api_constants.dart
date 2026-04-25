// lib/core/constants/api_constants.dart
// Central place for all external API endpoints and base URLs.

class ApiConstants {
  ApiConstants._();

  // ── Jikan (MyAnimeList unofficial API) ──────────────────────────────────────
  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';

  // ── AniList GraphQL ─────────────────────────────────────────────────────────
  static const String anilistBaseUrl = 'https://graphql.anilist.co';

  // ── MyAnimeList web links ───────────────────────────────────────────────────
  static const String malAnimeBase = 'https://myanimelist.net/anime/';
  static const String malMangaBase = 'https://myanimelist.net/manga/';

  // ── Streaming deep-link schemes ─────────────────────────────────────────────
  static const String crunchyrollScheme = 'crunchyroll://';
  static const String netflixScheme     = 'netflix://';
  static const String amazonPrimeScheme = 'aiv://';
  static const String funimationScheme  = 'funimation://';
  static const String disneyPlusScheme  = 'disneyplus://';
}
