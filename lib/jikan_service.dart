// lib/jikan_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'anime.dart';
import 'manga.dart';

class JikanService {
  static final JikanService _instance = JikanService._internal();
  factory JikanService() => _instance;
  JikanService._internal();

  static const String _baseUrl = 'https://animatch-api.railway.app';

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body)['data'];
    } else {
      throw Exception('Backend API error: ${response.statusCode}');
    }
  }

  // ── Anime Endpoints ───────────────────────────────────────────────────────

  Future<List<Anime>> getTopAnime({int page = 1, String? type, String? filter}) async {
    final data = await _get('/anime/top', params: {
      'page': page.toString(),
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    });
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getCurrentSeasonAnime() async {
    final data = await _get('/anime/seasonal');
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getSchedules(String dayOfWeek) async {
    final data = await _get('/anime/schedule/$dayOfWeek');
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getTopUpcomingAnime() async {
    final data = await _get('/anime/upcoming');
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> searchAnime(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/anime/search', params: {
      'q': query.trim(),
      'page': page.toString(),
    });
    return (data as List).map((x) => Anime.fromJson(x)).toList();
  }

  Future<List<Anime>> getRecommendations(QuizAnswers answers) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/recommendations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        ...answers.toJson(),
        'isManga': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      return (data as List).map((x) => Anime.fromJson(x)).toList();
    } else {
      throw Exception('Recommendation API error: ${response.statusCode}');
    }
  }

  Future<Anime> getAnimeDetail(int malId) async {
    final data = await _get('/anime/$malId');
    return Anime.fromJson(data);
  }

  Future<Anime> getRandomAnime() async {
    final data = await _get('/anime/random');
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

  Future<List<Manga>> getTopManga({int page = 1, String? type, String? filter}) async {
    final data = await _get('/manga/top', params: {
      'page': page.toString(),
      if (type != null) 'type': type,
      if (filter != null) 'filter': filter,
    });
    return (data as List).map((x) => Manga.fromJson(x)).toList();
  }

  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/manga/search', params: {
      'q': query.trim(),
      'page': page.toString(),
    });
    return (data as List).map((x) => Manga.fromJson(x)).toList();
  }

  Future<Manga> getMangaDetail(int malId) async {
    final data = await _get('/manga/$malId');
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
    final response = await http.post(
      Uri.parse('$_baseUrl/recommendations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        ...answers.toJson(),
        'isManga': true,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      return (data as List).map((x) => Manga.fromJson(x)).toList();
    } else {
      throw Exception('Recommendation API error: ${response.statusCode}');
    }
  }

  Future<List<MangaMagazine>> getMagazines() async {
    final data = await _get('/manga/magazines');
    return (data as List).map((x) => MangaMagazine.fromJson(x)).toList();
  }

  Future<String?> getMagazineCover(int magazineId) async {
    try {
      final data = await _get('/manga/by-magazine/$magazineId', params: {'limit': '1'});
      final list = data as List;
      if (list.isNotEmpty) {
        return list.first['images']?['jpg']?['large_image_url'];
      }
    } catch (_) {}
    return null;
  }

  Future<List<Manga>> getMangaByMagazine(int magazineId, {int page = 1}) async {
    final data = await _get('/manga/by-magazine/$magazineId', params: {'page': page.toString()});
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

  MangaMagazine({required this.malId, required this.name, required this.count, this.imageUrl});

  factory MangaMagazine.fromJson(Map<String, dynamic> json) {
    return MangaMagazine(
      malId: json['mal_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

