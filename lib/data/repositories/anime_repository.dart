import 'dart:async';
import 'dart:math' as math;

import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/models/hero_recommendation.dart';
import 'package:animatch/data/repositories/scoring_engine.dart';
import 'package:animatch/data/sources/remote/anilist_service.dart';
import 'package:animatch/data/sources/local/cache_service.dart';
import 'package:animatch/data/sources/remote/jikan_service.dart';
import 'package:animatch/data/models/manga.dart';
import 'package:animatch/data/models/media_base.dart';

abstract class AnimeRepository {
  Future<List<Anime>> getTopAnime({String tab = 'Today'});
  Future<List<Anime>> searchAnime(String query);
  Future<List<Anime>> getRecommendations({
    required String mood,
    required Set<int> watchedIds,
  });
  Future<List<Manga>> searchManga(String query);
  Future<String?> getCoverImage(
    int? malId,
    String title, {
    bool isManga = false,
  });
  Future<Anime> getAnimeDetail(int malId);
  Future<Manga> getMangaDetail(int malId);

  /// Hybrid decision engine: returns the single best anime + confidence.
  ///
  /// [watchlistItems] are the raw Firestore maps for the current user.
  /// Genres, ratings, timestamps, and watch-status are extracted from them
  /// by [ScoringEngine] to build content, behavioral, and temporal vectors.
  Future<HeroRecommendation> getHeroRecommendation({
    String? userId,
    required String mood,
    required Set<int> watchedIds,
    required List<Map<String, dynamic>> watchlistItems,
  });
}

class AnimeRepositoryImpl implements AnimeRepository {
  final JikanService jikanService;
  final AnilistService anilistService;
  final CacheService cacheService;
  final Map<String, Future<List<Anime>>> _topAnimeRequests = {};
  final Map<String, Future<List<Anime>>> _animeSearchRequests = {};
  final Map<String, Future<List<Manga>>> _mangaSearchRequests = {};
  final Map<String, Future<List<Anime>>> _recommendationRequests = {};

  AnimeRepositoryImpl({
    required this.jikanService,
    required this.anilistService,
    required this.cacheService,
  });

  @override
  Future<List<Anime>> getTopAnime({String tab = 'Today'}) async {
    final cached = await cacheService.getTopAnime(tab: tab);
    if (cached != null) return cached;

    final key = tab.toLowerCase();
    final pending = _topAnimeRequests[key];
    if (pending != null) return pending;

    final request = _fetchTopAnime(tab);
    _topAnimeRequests[key] = request;
    try {
      return await request;
    } finally {
      _topAnimeRequests.remove(key);
    }
  }

  Future<List<Anime>> _fetchTopAnime(String tab) async {
    final List<Map<String, dynamic>> rawList;
    if (tab == 'Today') {
      rawList = await anilistService.getTrendingAnime();
    } else if (tab == 'Week') {
      rawList = await anilistService.getSeasonalAnime();
    } else {
      rawList = await anilistService.getTopRatedAnime();
    }

    final results = rawList.map((item) => Anime.fromAniList(item)).toList();
    await cacheService.saveTopAnime(results, tab: tab);
    return results;
  }

  @override
  Future<List<Anime>> searchAnime(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <Anime>[];

    final cached = await cacheService.getSearchResults(normalizedQuery);
    if (cached != null) return cached.whereType<Anime>().toList();

    final key = normalizedQuery.toLowerCase();
    final pending = _animeSearchRequests[key];
    if (pending != null) return pending;

    final request = _fetchAnimeSearch(normalizedQuery);
    _animeSearchRequests[key] = request;
    try {
      return await request;
    } finally {
      _animeSearchRequests.remove(key);
    }
  }

  Future<List<Anime>> _fetchAnimeSearch(String query) async {
    final results = await jikanService.searchAnime(query);
    await cacheService.saveSearchResults(query, results);
    return results;
  }

  @override
  Future<List<Anime>> getRecommendations({
    required String mood,
    required Set<int> watchedIds,
  }) async {
    final normalizedMood = mood.trim().isEmpty ? 'action' : mood.trim();
    final cacheKey = normalizedMood.toLowerCase();
    final cached = await cacheService.getRecommendations(normalizedMood);
    if (cached != null) {
      _refreshRecommendationsInBackground(cacheKey, normalizedMood);
      return _rankRecommendations(cached, watchedIds).take(10).toList();
    }

    final pending = _recommendationRequests[cacheKey];
    if (pending != null) {
      final results = await pending;
      return _rankRecommendations(results, watchedIds).take(10).toList();
    }

    final request = _fetchRecommendations(normalizedMood);
    _recommendationRequests[cacheKey] = request;
    try {
      final results = await request;
      return _rankRecommendations(results, watchedIds).take(10).toList();
    } finally {
      _recommendationRequests.remove(cacheKey);
    }
  }

  Future<List<Anime>> _fetchRecommendations(String mood) async {
    final genreIds = QuizAnswers.moodToGenreIds[mood] ??
        QuizAnswers.moodToGenreIds['action']!;
    final results = <Anime>[];

    for (var page = 1; page <= 2 && results.length < 30; page++) {
      final pageResults = await jikanService.getAnimeByGenres(
        genreIds,
        page: page,
        minScore: 6.5,
      );
      if (pageResults.isEmpty) break;
      results.addAll(pageResults);
      if (pageResults.length < 25) break;
    }

    await cacheService.saveRecommendations(mood, results);
    return results;
  }

  void _refreshRecommendationsInBackground(String cacheKey, String mood) {
    if (_recommendationRequests.containsKey(cacheKey)) return;

    final request = _fetchRecommendations(mood);
    _recommendationRequests[cacheKey] = request;
    unawaited(request.whenComplete(() {
      _recommendationRequests.remove(cacheKey);
    }));
  }

  List<Anime> _rankRecommendations(List<Anime> anime, Set<int> watchedIds) {
    final filtered = anime
        .where((item) => item.malId != 0)
        .where((item) => !watchedIds.contains(item.malId))
        .where((item) => (item.score ?? 0) >= 6.5)
        .toList();

    filtered.sort((a, b) {
      final aRank = _recommendationScore(a);
      final bRank = _recommendationScore(b);
      return bRank.compareTo(aRank);
    });

    return filtered;
  }

  double _recommendationScore(Anime anime) {
    final score = anime.score ?? 0;
    final popularityBoost = anime.members == null
        ? 0.0
        : (anime.members! / 1000000).clamp(0.0, 2.0);
    final rankBoost =
        anime.rank == null ? 0.0 : (1 / anime.rank!).clamp(0.0, 1.0);
    return (score * 10) + popularityBoost + rankBoost;
  }

  @override
  Future<List<Manga>> searchManga(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const <Manga>[];

    final cached = await cacheService.getSearchResults(
      normalizedQuery,
      isManga: true,
    );
    if (cached != null) return cached.whereType<Manga>().toList();

    final key = normalizedQuery.toLowerCase();
    final pending = _mangaSearchRequests[key];
    if (pending != null) return pending;

    final request = _fetchMangaSearch(normalizedQuery);
    _mangaSearchRequests[key] = request;
    try {
      return await request;
    } finally {
      _mangaSearchRequests.remove(key);
    }
  }

  Future<List<Manga>> _fetchMangaSearch(String query) async {
    final results = await jikanService.searchManga(query);
    await cacheService.saveSearchResults(
      query,
      results.cast<MediaBase>(),
      isManga: true,
    );
    return results;
  }

  @override
  Future<String?> getCoverImage(
    int? malId,
    String title, {
    bool isManga = false,
  }) async {
    String? url;
    if (malId != null) {
      url = await anilistService.getCoverImageByMalId(
        malId,
        isManga: isManga,
      );
    }

    url ??= await anilistService.getCoverImageByTitle(
      title,
      isManga: isManga,
    );

    return url;
  }

  @override
  Future<Anime> getAnimeDetail(int malId) {
    return jikanService.getAnimeDetail(malId);
  }

  @override
  Future<Manga> getMangaDetail(int malId) {
    return jikanService.getMangaDetail(malId);
  }

  // ── Decision Engine (delegates to ScoringEngine) ────────────────────────────

  static final _engine = const ScoringEngine();

  @override
  Future<HeroRecommendation> getHeroRecommendation({
    String? userId,
    required String mood,
    required Set<int> watchedIds,
    required List<Map<String, dynamic>> watchlistItems,
  }) async {
    // 1. Fetch pool from cache (zero network cost on repeat calls)
    final pool = await getRecommendations(
      mood: mood,
      watchedIds: watchedIds,
    );

    if (pool.isEmpty) {
      throw StateError('No recommendations for mood: $mood');
    }

    // 2. Rank using the full hybrid scoring engine
    final ranked = _engine.rank(
      pool,
      userId: userId,
      watchlistItems: watchlistItems,
      watchedIds: watchedIds,
    );

    if (ranked.isEmpty) {
      throw StateError('All candidates already watched');
    }

    final best = ranked.first;
    final alts = ranked.skip(1).take(3).map((s) => s.anime).toList();

    // Cold Start Handling & Prior Boost
    if (watchlistItems.length < 3) {
      final rating = (best.anime.score ?? 7.0) / 10.0;
      final priorBoost = 0.15 * best.popularityScore + 0.05 * rating;
      final adjusted = (best.totalScore * 0.8 + priorBoost).clamp(0.0, 1.0);
      return HeroRecommendation(
        anime: best.anime,
        confidence: _engine.confidencePercent(adjusted, penalty: 1.0),
        explanation: 'Start rating more anime to get personalized picks!',
        alternatives: alts,
        mode: RecommendationMode.explore,
      );
    }

    // 3. Sigmoid confidence (now gap and quality-aware)
    final gap =
        ranked.length > 1 ? best.totalScore - ranked[1].totalScore : 0.0;
    final normalizedGap = gap / (best.totalScore + 1e-6);

    final fit = 0.5 * best.contentScore + 0.5 * best.temporalScore;
    final quality = 0.5 * best.popularityScore +
        0.3 * ((best.anime.score ?? 7.0) / 10.0) +
        0.2 * fit;

    // Dynamic Thresholds
    final threshold = _engine.percentileThreshold(ranked, 0.7);
    final entropy = _engine.normalizedEntropy(ranked);
    final isHighQuality = quality > 0.65;

    // Soft absolute floor
    final floor =
        math.max(0.52, _engine.percentileThreshold(ranked, 0.6) - 0.04);
    final passesAbsolute = best.totalScore > floor;

    // Graded entropy influence (non-linear)
    final e = entropy.clamp(0.0, 1.0);
    final entropyPenalty = math.pow(math.max(0.0, e - 0.85), 1.5).toDouble();
    final effectiveScore = best.totalScore - 0.2 * entropyPenalty;
    final hasDominantSignal = effectiveScore > 0.78;

    final isConfident = hasDominantSignal ||
        (best.totalScore > threshold &&
            passesAbsolute &&
            normalizedGap > 0.02 &&
            isHighQuality &&
            entropyPenalty == 0.0);

    final RecommendationMode mode = isConfident
        ? RecommendationMode.confident
        : (best.totalScore > threshold * 0.9 &&
                passesAbsolute &&
                entropyPenalty < 0.1
            ? RecommendationMode.weak
            : RecommendationMode.explore);

    double modePenalty = 0.0;
    if (mode == RecommendationMode.weak) modePenalty = 0.5;
    if (mode == RecommendationMode.explore) modePenalty = 1.0;

    final confidence = _engine.confidencePercent(
      best.totalScore,
      normalizedGap: normalizedGap,
      quality: quality,
      penalty: modePenalty,
    );

    // 4. Explanation from dominant score factor
    final explanation = buildHeroExplanation(best, mood, _engine.weights);

    return HeroRecommendation(
      anime: best.anime,
      confidence: confidence,
      explanation: explanation,
      alternatives: alts,
      mode: mode,
      contentScore: best.contentScore,
      behaviorScore: best.behaviorScore,
      temporalScore: best.temporalScore,
      popularityScore: best.popularityScore,
      noveltyScore: best.noveltyScore,
    );
  }
}
