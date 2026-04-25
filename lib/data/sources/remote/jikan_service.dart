// lib/jikan_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/models/manga.dart';

class JikanService {
  static final JikanService _instance = JikanService._internal();
  factory JikanService() => _instance;
  JikanService._internal();

  final Map<String, _CacheEntry> _cache = {};
  final List<Completer<void>> _queue = [];
  bool _isProcessing = false;

  Future<void> _throttle() async {
    final completer = Completer<void>();
    _queue.add(completer);
    if (!_isProcessing) _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    _isProcessing = true;
    while (_queue.isNotEmpty) {
      final completer = _queue.removeAt(0);
      completer.complete();
      await Future.delayed(
          const Duration(milliseconds: 500)); // ~2 requests per second
    }
    _isProcessing = false;
  }

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('https://api.jikan.moe/v4$path')
        .replace(queryParameters: params);
    final cacheKey = uri.toString();

    // 1. Check Cache
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (DateTime.now().isBefore(entry.expiry)) {
        return entry.data;
      }
      _cache.remove(cacheKey);
    }

    // 2. Throttle
    await _throttle();

    // 3. Fetch
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      _cache[cacheKey] = _CacheEntry(
        data: data,
        expiry: DateTime.now().add(const Duration(minutes: 5)),
      );
      return data;
    } else if (response.statusCode == 429) {
      // Retry once after a delay if rate limited
      await Future.delayed(const Duration(seconds: 2));
      return _get(path, params: params);
    } else {
      throw Exception('Jikan API error: ${response.statusCode}');
    }
  }

  // ── Anime Endpoints ───────────────────────────────────────────────────────

  Future<List<Anime>> getTopAnime(
      {int page = 1, String? type, String? filter}) async {
    final data = await _get('/top/anime', params: {
      'page': page.toString(),
      'limit': '20',
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    });
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getCurrentSeasonAnime() async {
    final data = await _get('/seasons/now', params: {'limit': '20'});
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getSchedules(String dayOfWeek) async {
    final data =
        await _get('/schedules', params: {'filter': dayOfWeek, 'limit': '15'});
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getTopUpcomingAnime() async {
    final data = await _get('/seasons/upcoming', params: {'limit': '20'});
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/anime', params: {
      'q': query.trim(),
      'page': page.toString(),
      'limit': '20',
      'order_by': 'score',
      'sort': 'desc',
    });
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getAnimeByGenres(
    List<int> genreIds, {
    int page = 1,
    double minScore = 6.0,
  }) async {
    final data = await _get('/anime', params: {
      'page': page.toString(),
      'limit': '25',
      'order_by': 'popularity',
      'sort': 'asc',
      'min_score': minScore.toStringAsFixed(1),
      'sfw': 'true',
      if (genreIds.isNotEmpty) 'genres': genreIds.join(','),
    });
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getRecommendations(QuizAnswers answers) async {
    final genreIds = answers.genreIds;
    final params = <String, String>{
      'order_by': 'popularity',
      'limit': '25',
      'min_score': '6.0',
      'sfw': 'true',
      if (genreIds.isNotEmpty) 'genres': genreIds.first.toString(),
      if (answers.statusParam.isNotEmpty) 'status': answers.statusParam,
    };

    List<Anime> finalResults = [];
    int page = 1;

    while (finalResults.length < 12 && page <= 3) {
      params['page'] = page.toString();
      final data = await _get('/anime', params: params);
      List<Anime> results =
          (data as List).map((x) => Anime.fromJson(x)).toList();

      if (results.isEmpty) break;

      if (answers.minEpisodes != null || answers.maxEpisodes != null) {
        results = results.where((a) {
          if (a.episodes == null) return true;
          final eps = a.episodes!;
          if (answers.minEpisodes != null && eps < answers.minEpisodes!) {
            return false;
          }
          if (answers.maxEpisodes != null && eps > answers.maxEpisodes!) {
            return false;
          }
          return true;
        }).toList();
      }

      finalResults.addAll(results);
      if (results.length < 25) break;
      page++;
    }

    finalResults.shuffle();
    return finalResults.take(16).toList();
  }

  Future<Anime> getAnimeDetail(int malId) async {
    final data = await _get('/anime/$malId/full');
    return Anime.fromJson(data);
  }

  Future<Anime> getRandomAnime() async {
    final data = await _get('/random/anime');
    return Anime.fromJson(data);
  }

  Future<List<AnimeCharacter>> getCharacters(int malId) async {
    final data = await _get('/anime/$malId/characters');
    return (data as List).map((x) => AnimeCharacter.fromJson(x)).toList();
  }

  Future<List<StreamingLink>> fetchStreamingLinks(int malId) async {
    try {
      final data = await _get('/anime/$malId/streaming');
      return (data as List).map((x) => StreamingLink.fromJson(x)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Anime>> getSimilarAnime(int malId) async {
    final data = await _get('/anime/$malId/recommendations');
    return (data as List).take(10).map((e) {
      final entry = e['entry'] as Map<String, dynamic>;
      return Anime(
        malId: entry['mal_id'] as int,
        title: entry['title'] as String,
        imageUrl: entry['images']?['jpg']?['image_url'] ?? '',
        genres: [],
      );
    }).toList();
  }

  // ── Manga Endpoints ───────────────────────────────────────────────────────

  Future<List<Manga>> getTopManga(
      {int page = 1, String? type, String? filter}) async {
    final data = await _get('/top/manga', params: {
      'page': page.toString(),
      'limit': '20',
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    });
    return (data as List).map((x) => Manga.fromJson(x)).toList();
  }

  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/manga', params: {
      'q': query.trim(),
      'page': page.toString(),
      'limit': '20',
      'order_by': 'score',
      'sort': 'desc',
    });
    return (data as List).map((x) => Manga.fromJson(x)).toList();
  }

  Future<Manga> getMangaDetail(int malId) async {
    final data = await _get('/manga/$malId/full');
    return Manga.fromJson(data);
  }

  Future<List<MangaCharacter>> getMangaCharacters(int malId) async {
    final data = await _get('/manga/$malId/characters');
    return (data as List).map((x) => MangaCharacter.fromJson(x)).toList();
  }

  Future<List<Manga>> getSimilarManga(int malId) async {
    final data = await _get('/manga/$malId/recommendations');
    return (data as List).take(10).map((e) {
      final entry = e['entry'] as Map<String, dynamic>;
      return Manga(
        malId: entry['mal_id'] as int,
        title: entry['title'] as String,
        imageUrl: entry['images']?['jpg']?['image_url'] ?? '',
        genres: [],
      );
    }).toList();
  }

  Future<List<Manga>> getMangaRecommendations(QuizAnswers answers) async {
    final genreIds = answers.genreIds;
    final params = <String, String>{
      'order_by': 'popularity',
      'limit': '25',
      'min_score': '6.0',
      'sfw': 'true',
      if (genreIds.isNotEmpty) 'genres': genreIds.first.toString(),
      if (answers.statusParam.isNotEmpty) 'status': answers.statusParam,
      if (answers.typeParam != null) 'type': answers.typeParam!,
    };

    List<Manga> finalResults = [];
    int page = 1;

    while (finalResults.length < 12 && page <= 3) {
      params['page'] = page.toString();
      final data = await _get('/manga', params: params);
      List<Manga> results =
          (data as List).map((x) => Manga.fromJson(x)).toList();

      if (results.isEmpty) break;

      if (answers.minEpisodes != null || answers.maxEpisodes != null) {
        results = results.where((m) {
          if (m.chapters == null) return true;
          final ch = m.chapters!;
          if (answers.minEpisodes != null && ch < (answers.minEpisodes! * 3)) {
            return false;
          }
          if (answers.maxEpisodes != null && ch > (answers.maxEpisodes! * 3)) {
            return false;
          }
          return true;
        }).toList();
      }

      finalResults.addAll(results);
      if (results.length < 25) break;
      page++;
    }

    finalResults.shuffle();
    return finalResults.take(16).toList();
  }

  Future<List<MangaMagazine>> getMagazines() async {
    final data = await _get('/magazines', params: {'limit': '20'});
    return (data as List).map((x) => MangaMagazine.fromJson(x)).toList();
  }

  Future<String?> getMagazineCover(int magazineId) async {
    try {
      final data = await _get('/manga', params: {
        'magazines': magazineId.toString(),
        'order_by': 'popularity',
        'limit': '1',
      });
      final list = data as List;
      if (list.isNotEmpty) {
        return list.first['images']?['jpg']?['large_image_url'];
      }
    } catch (_) {}
    return null;
  }

  Future<List<Manga>> getMangaByMagazine(int magazineId, {int page = 1}) async {
    final data = await _get('/manga', params: {
      'magazines': magazineId.toString(),
      'order_by': 'popularity',
      'page': page.toString(),
      'limit': '20',
    });
    return (data as List).map((x) => Manga.fromJson(x)).toList();
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;
  _CacheEntry({required this.data, required this.expiry});
}

class MangaMagazine {
  final int malId;
  final String name;
  final int count;
  String? imageUrl;

  MangaMagazine(
      {required this.malId,
      required this.name,
      required this.count,
      this.imageUrl});

  factory MangaMagazine.fromJson(Map<String, dynamic> json) {
    return MangaMagazine(
      malId: json['mal_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}
