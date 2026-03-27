import 'dart:convert';
import 'package:http/http.dart' as http;
import 'anime.dart';           // ← was '../models/anime.dart'

class JikanService {
  static const String _baseUrl = 'https://api.jikan.moe/v4';
  static const Duration _requestDelay = Duration(milliseconds: 400);

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
  Future<List<Anime>> getTopAnime({int page = 1, String? type}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': '20',
      if (type != null) 'type': type,
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
      'order_by': 'score',
      'sort': 'desc',
      'limit': '20',
      'min_score': '7.0',
      'sfw': 'true',
    };

    // Add genres from quiz
    final genreIds = answers.genreIds;
    if (genreIds.isNotEmpty) {
      params['genres'] = genreIds.join(',');
    }

    // Add status filter
    if (answers.statusParam.isNotEmpty) {
      params['status'] = answers.statusParam;
    }

    // Add episode range
    if (answers.maxEpisodes != null) {
      params['max_score'] = '10'; // placeholder; episode filtering done client-side
    }

    final data = await _get('/anime', params: params);
    List<Anime> results = (data['data'] as List<dynamic>? ?? [])
        .map((e) => Anime.fromJson(e as Map<String, dynamic>))
        .toList();

    // Client-side episode filtering
    if (answers.minEpisodes != null || answers.maxEpisodes != null) {
      results = results.where((a) {
        if (a.episodes == null) return true; // include unknowns
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

    return results;
  }

  /// Get full details for a single anime
  Future<Anime> getAnimeDetail(int malId) async {
    final data = await _get('/anime/$malId/full');
    return Anime.fromJson(data['data'] as Map<String, dynamic>);
  }

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
