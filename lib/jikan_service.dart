import 'dart:convert';
import 'package:http/http.dart' as http;
import 'anime.dart';
import 'manga.dart';
class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4';
  static const Duration _requestDelay = Duration(milliseconds: 800);

  DateTime? _lastRequestTime;

  // Rate-limit helper: Jikan allows ~3 req/sec
  Future<void> _throttle() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _requestDelay) {
        await Future.delayed(_requestDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  // Cache storage
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? params}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    final String cacheKey = uri.toString();

    // Check cache
    if (_cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTtl) {
        return _cache[cacheKey];
      }
    }

    await _throttle();

    final response = await http.get(uri, headers: {'Accept': 'application/json'});

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Store in cache
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      return data;
    } else if (response.statusCode == 429) {
      // Rate limited — wait and retry once
      await Future.delayed(const Duration(seconds: 2));
      final retryResponse = await http.get(uri);
      if (retryResponse.statusCode == 200) {
        final data = jsonDecode(retryResponse.body) as Map<String, dynamic>;
        
        // Store in cache
        _cache[cacheKey] = data;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        return data;
      }
    }
    throw JikanException(
        'API error ${response.statusCode}: ${response.reasonPhrase}');
  }

  /// Get top/trending anime for the home screen
  Future<List<Anime>> getTopAnime({int page = 1, String? type, String? filter}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': '20',
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    };
    final data = await _get('/top/anime', params: params);
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get currently airing (seasonal) anime
  Future<List<Anime>> getCurrentSeasonAnime() async {
    final data = await _get('/seasons/now', params: {'limit': '20'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get scheduled anime for a specific day ('monday', 'tuesday', etc.)
  Future<List<Anime>> getSchedules(String dayOfWeek) async {
    final data = await _get('/schedules', params: {'filter': dayOfWeek, 'limit': '15'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get top upcoming anime
  Future<List<Anime>> getTopUpcomingAnime() async {
    final data = await _get('/seasons/upcoming', params: {'limit': '20'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Search anime by text query
  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/anime', params: {
      'q': query.trim(),
      'page': page.toString(),
      'limit': '20',
      'order_by': 'score',
      'sort': 'desc',
    });
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get recommendations based on quiz answers
  Future<List<Anime>> getRecommendations(QuizAnswers answers) async {
    final params = <String, String>{
      'order_by': 'popularity', // Popularity often yields better variety than score
      'limit': '25',
      'min_score': '6.0', // Lowered significantly to allow more matches
      'sfw': 'true',
    };

    // Only strictly filter by the FIRST genre to keep the net extremely wide
    final genreIds = answers.genreIds;
    if (genreIds.isNotEmpty) {
      params['genres'] = genreIds.first.toString();
    }

    if (answers.statusParam.isNotEmpty) {
      params['status'] = answers.statusParam;
    }

    List<Anime> finalResults = [];
    int page = 1;

    // Fetch up to 6 pages (150 top anime) because client-side filtering by episodes
    // guarantees we will drop a huge chunk of them.
    while (finalResults.length < 12 && page <= 6) {
      params['page'] = page.toString();
      final data = await _get('/anime', params: params);
      List<Anime> results = (data['data'] as List<dynamic>? ?? [])
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();

      if (results.isEmpty) break;

      // Client-side episode length filter
      if (answers.minEpisodes != null || answers.maxEpisodes != null) {
        results = results.where((a) {
          if (a.episodes == null) return true; // include unknowns
          final eps = a.episodes!;
          if (answers.minEpisodes != null && eps < answers.minEpisodes!) return false;
          if (answers.maxEpisodes != null && eps > answers.maxEpisodes!) return false;
          return true;
        }).toList();
      }

      finalResults.addAll(results);

      // If we got less than requested limit from API, no more pages exist globally
      if ((data['data'] as List).length < 25) break;

      page++;
    }

    // Shuffle the results slightly so it doesn't always feel like the same 12 anime 
    // if the query is extremely generic
    finalResults.shuffle();
    
    return finalResults.take(16).toList();
  }

  // ── Manga Endpoints ───────────────────────────────────────────────────────

  /// Get top/trending manga
  Future<List<Manga>> getTopManga({int page = 1, String? type, String? filter}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': '20',
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    };
    final data = await _get('/top/manga', params: params);
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Manga.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Search manga by text query
  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/manga', params: {
      'q': query.trim(),
      'page': page.toString(),
      'limit': '20',
      'order_by': 'score',
      'sort': 'desc',
    });
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Manga.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get full details for a single manga
  Future<Manga> getMangaDetail(int malId) async {
    final data = await _get('/manga/$malId/full');
    return Manga.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get the character cast for a specific manga
  Future<List<MangaCharacter>> getMangaCharacters(int malId) async {
    final data = await _get('/manga/$malId/characters');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => MangaCharacter.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get manga recommendations based on a specific manga (related titles)
  Future<List<Manga>> getSimilarManga(int malId) async {
    final data = await _get('/manga/$malId/recommendations');
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .take(10)
        .map((e) {
          final entry = e['entry'] as Map<String, dynamic>? ?? {};
          return Manga(
            malId: entry['mal_id'] as int? ?? 0,
            title: entry['title'] as String? ?? 'Unknown',
            imageUrl: entry['images']?['jpg']?['image_url'] as String? ??
                'https://via.placeholder.com/225x320',
            genres: [],
          );
        })
        .where((a) => a.malId != 0)
        .toList();
  }

  /// Get recommendations based on quiz answers (Manga)
  Future<List<Manga>> getMangaRecommendations(QuizAnswers answers) async {
    final params = <String, String>{
      'order_by': 'popularity',
      'limit': '25',
      'min_score': '6.0',
      'sfw': 'true',
    };

    final genreIds = answers.genreIds;
    if (genreIds.isNotEmpty) {
      params['genres'] = genreIds.first.toString();
    }

    if (answers.statusParam.isNotEmpty) {
      params['status'] = answers.statusParam;
    }
    
    // For manga, type could be manga, novel, lightnovel, manhwa, manhua
    if (answers.typeParam != null && answers.typeParam!.isNotEmpty) {
       params['type'] = answers.typeParam!;
    }

    List<Manga> finalResults = [];
    int page = 1;

    while (finalResults.length < 12 && page <= 6) {
      params['page'] = page.toString();
      final data = await _get('/manga', params: params);
      List<Manga> results = (data['data'] as List<dynamic>? ?? [])
          .map((e) => Manga.fromJson(e as Map<String, dynamic>))
          .toList();

      if (results.isEmpty) break;

      // Client-side length filter (chapters/volumes)
      if (answers.minEpisodes != null || answers.maxEpisodes != null) {
        results = results.where((m) {
          if (m.chapters == null) return true; // include unknowns
          final ch = m.chapters!;
          // Using episode range logic roughly for chapters
          if (answers.minEpisodes != null && ch < (answers.minEpisodes! * 3)) return false; // assuming 3 chapters ~ 1 ep
          if (answers.maxEpisodes != null && ch > (answers.maxEpisodes! * 3)) return false;
          return true;
        }).toList();
      }

      finalResults.addAll(results);

      if ((data['data'] as List).length < 25) break;

      page++;
    }

    finalResults.shuffle();
    return finalResults.take(16).toList();
  }

  /// Get full details for a single anime
  Future<Anime> getAnimeDetail(int malId) async {
    final data = await _get('/anime/$malId/full');
    return Anime.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get a completely random anime entry
  Future<Anime> getRandomAnime() async {
    final data = await _get('/random/anime');
    return Anime.fromJson(data['data'] as Map<String, dynamic>);
  }

  /// Get the character cast for a specific anime
  Future<List<AnimeCharacter>> getCharacters(int malId) async {
    final data = await _get('/anime/$malId/characters');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => AnimeCharacter.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Streaming ─────────────────────────────────────────────────────────────

  /// Fetches the list of streaming platforms for [malId] from Jikan v4.
  ///
  /// Endpoint: GET /anime/{id}/streaming
  /// Returns `[]` on any non-200 response (after one 429 retry).
  Future<List<StreamingLink>> fetchStreamingLinks(int malId) async {
    try {
      await _throttle();
      final uri = Uri.parse('$_baseUrl/anime/$malId/streaming');
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body)['data'] as List<dynamic>? ?? [];
        return raw
            .map((e) => StreamingLink.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 429) {
        // Rate limited — wait and retry once
        await Future.delayed(const Duration(seconds: 2));
        return fetchStreamingLinks(malId);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Convenience alias used by the detail screen's FutureBuilder.
  Future<List<StreamingLink>> getStreamingLinksForAnime(int malId) =>
      fetchStreamingLinks(malId);

  /// Get similar anime recommendations
  Future<List<Anime>> getSimilarAnime(int malId) async {
    final data = await _get('/anime/$malId/recommendations');
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .take(10)
        .map((e) {
          final entry = e['entry'] as Map<String, dynamic>? ?? {};
          return Anime(
            malId: entry['mal_id'] as int? ?? 0,
            title: entry['title'] as String? ?? 'Unknown',
            imageUrl: entry['images']?['jpg']?['image_url'] as String? ??
                'https://via.placeholder.com/225x320',
            genres: [],
          );
        })
        .where((a) => a.malId != 0)
        .toList();
  }

  /// Get popular manga magazines
  Future<List<MangaMagazine>> getMagazines() async {
    final data = await _get('/magazines', params: {'limit': '20'});
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => MangaMagazine.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get a representational image for a magazine by fetching its top manga
  Future<String?> getMagazineCover(int magazineId) async {
    try {
      final data = await _get('/manga', params: {
        'magazines': magazineId.toString(),
        'order_by': 'popularity',
        'limit': '1',
      });
      final list = data['data'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        return list.first['images']?['jpg']?['large_image_url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Get all manga for a specific magazine
  Future<List<Manga>> getMangaByMagazine(int magazineId, {int page = 1}) async {
    final data = await _get('/manga', params: {
      'magazines': magazineId.toString(),
      'order_by': 'popularity',
      'page': page.toString(),
      'limit': '20',
    });
    final list = data['data'] as List<dynamic>? ?? [];
    return list.map((e) => Manga.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class MangaMagazine {
  final int malId;
  final String name;
  final int count;
  String? imageUrl;

  MangaMagazine({required this.malId, required this.name, required this.count, this.imageUrl});

  factory MangaMagazine.fromJson(Map<String, dynamic> json) {
    return MangaMagazine(
      malId: json['mal_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

class JikanException implements Exception {
  final String message;
  const JikanException(this.message);

  @override
  String toString() => 'JikanException: $message';
}
