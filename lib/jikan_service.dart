import 'dart:convert';
import 'package:http/http.dart' as http;
import 'anime.dart';           // ← was '../models/anime.dart'

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

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? params}) async {
    await _throttle();

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri, headers: {'Accept': 'application/json'});

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 429) {
      // Rate limited — wait and retry once
      await Future.delayed(const Duration(seconds: 2));
      final retryResponse = await http.get(uri);
      if (retryResponse.statusCode == 200) {
        return jsonDecode(retryResponse.body) as Map<String, dynamic>;
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

  /// Get anime recommendations based on a specific anime (related titles)
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
}

class JikanException implements Exception {
  final String message;
  const JikanException(this.message);

  @override
  String toString() => 'JikanException: $message';
}
