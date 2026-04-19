import 'dart:convert';
import 'package:http/http.dart' as http;

class AiringSchedule {
  final int idMal;
  final String title;
  final String coverImage;
  final int episode;
  final int airingAt;
  final int timeUntilAiring;

  AiringSchedule({
    required this.idMal,
    required this.title,
    required this.coverImage,
    required this.episode,
    required this.airingAt,
    required this.timeUntilAiring,
  });

  factory AiringSchedule.fromJson(Map<String, dynamic> json) {
    final media = json['media'] ?? {};
    final titleObj = media['title'] ?? {};
    final String title = titleObj['english'] ?? titleObj['romaji'] ?? 'Unknown';
    final coverImage = media['coverImage']?['large'] ?? '';
    
    return AiringSchedule(
      idMal: media['idMal'] ?? 0, 
      title: title,
      coverImage: coverImage,
      episode: json['episode'] ?? 0,
      airingAt: json['airingAt'] ?? 0,
      timeUntilAiring: json['timeUntilAiring'] ?? 0,
    );
  }
}

class AnilistService {
  static const String _baseUrl = 'https://animatch-api.railway.app/anilist';

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    final response = await http.get(uri);
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['data'] ?? {};
    }
    throw Exception('Anilist Backend error: ${response.statusCode}');
  }

  /// Get airing schedules between two UNIX timestamps
  Future<List<AiringSchedule>> getSchedules(int startTimestamp, int endTimestamp) async {
    final data = await _get('/schedule', params: {
      'start': startTimestamp.toString(),
      'end': endTimestamp.toString(),
    });
    final list = data['Page']?['airingSchedules'] as List<dynamic>? ?? [];
    return list.map((e) => AiringSchedule.fromJson(e)).where((s) => s.idMal != 0).toList();
  }

  /// Get Trending Anime
  Future<List<Map<String, dynamic>>> getTrendingAnime() async {
    final data = await _get('/trending');
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Seasonal Anime (Current Season)
  Future<List<Map<String, dynamic>>> getSeasonalAnime() async {
    final data = await _get('/seasonal');
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Top Rated Anime
  Future<List<Map<String, dynamic>>> getTopRatedAnime() async {
    final data = await _get('/top-rated');
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Top Upcoming
  Future<List<Map<String, dynamic>>> getTopUpcomingAnime() async {
    final data = await _get('/upcoming');
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get cover image from AniList by MAL ID
  Future<String?> getCoverImageByMalId(int idMal, {bool isManga = false}) async {
    try {
      final data = await _get('/cover/$idMal', params: {
        'type': isManga ? 'MANGA' : 'ANIME',
      });
      return data['Media']?['coverImage']?['extraLarge'] ?? data['Media']?['coverImage']?['large'];
    } catch (_) {
      return null;
    }
  }

  /// Get cover image from AniList by Title (fallback)
  Future<String?> getCoverImageByTitle(String title, {bool isManga = false}) async {
    try {
      final data = await _get('/cover-by-title', params: {
        'q': title,
        'type': isManga ? 'MANGA' : 'ANIME',
      });
      return data['Media']?['coverImage']?['extraLarge'] ?? data['Media']?['coverImage']?['large'];
    } catch (_) {
      return null;
    }
  }
}
