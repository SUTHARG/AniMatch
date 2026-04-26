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
  static const String _baseUrl = 'https://graphql.anilist.co';

  // Cache storage
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Get airing schedules between two UNIX timestamps
  Future<List<AiringSchedule>> getSchedules(
      int startTimestamp, int endTimestamp) async {
    const String query = '''
      query (\$start: Int, \$end: Int) {
        Page(page: 1, perPage: 50) {
          airingSchedules(airingAt_greater: \$start, airingAt_lesser: \$end, sort: TIME) {
            airingAt
            episode
            media {
              idMal
              title { romaji english }
              coverImage { large }
            }
          }
        }
      }
    ''';

    final variables = {'start': startTimestamp, 'end': endTimestamp};
    final data = await _postQuery(query, variables);
    final list = data['Page']?['airingSchedules'] as List<dynamic>? ?? [];
    return list
        .map((e) => AiringSchedule.fromJson(e))
        .where((s) => s.idMal != 0)
        .toList();
  }

  /// Get Trending Anime (CORS friendly)
  Future<List<Map<String, dynamic>>> getTrendingAnime() async {
    const String query = '''
      query {
        Page(page: 1, perPage: 15) {
          media(type: ANIME, sort: TRENDING_DESC) {
            idMal
            id
            title { english romaji }
            coverImage { extraLarge large }
            bannerImage
            description
            averageScore
            episodes
            status
            format
            genres
            startDate { year month day }
          }
        }
      }
    ''';
    final data = await _postQuery(query, {});
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Seasonal Anime (Current Season)
  Future<List<Map<String, dynamic>>> getSeasonalAnime() async {
    const String query = '''
      query {
        Page(page: 1, perPage: 15) {
          media(type: ANIME, sort: POPULARITY_DESC, status: RELEASING) {
            idMal
            id
            title { english romaji }
            coverImage { extraLarge large }
            bannerImage
            description
            averageScore
            episodes
            status
            format
            genres
            startDate { year month day }
          }
        }
      }
    ''';
    final data = await _postQuery(query, {});
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Top Rated Anime
  Future<List<Map<String, dynamic>>> getTopRatedAnime() async {
    const String query = '''
      query {
        Page(page: 1, perPage: 15) {
          media(type: ANIME, sort: SCORE_DESC) {
            idMal
            id
            title { english romaji }
            coverImage { extraLarge large }
            bannerImage
            description
            averageScore
            episodes
            status
            format
            genres
            startDate { year month day }
          }
        }
      }
    ''';
    final data = await _postQuery(query, {});
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get Top Upcoming
  Future<List<Map<String, dynamic>>> getTopUpcomingAnime() async {
    const String query = '''
      query {
        Page(page: 1, perPage: 15) {
          media(type: ANIME, sort: POPULARITY_DESC, status: NOT_YET_RELEASED) {
            idMal
            id
            title { english romaji }
            coverImage { extraLarge large }
            bannerImage
            description
            averageScore
            episodes
            status
            format
            genres
            startDate { year month day }
          }
        }
      }
    ''';
    final data = await _postQuery(query, {});
    return List<Map<String, dynamic>>.from(data['Page']?['media'] ?? []);
  }

  /// Get CORS-friendly cover image from AniList by MAL ID
  Future<String?> getCoverImageByMalId(int idMal,
      {bool isManga = false}) async {
    final String typeStr = isManga ? 'MANGA' : 'ANIME';
    final String query = '''
      query (\$id: Int) {
        Media(idMal: \$id, type: $typeStr) {
          coverImage { extraLarge large }
        }
      }
    ''';
    try {
      final data = await _postQuery(query, {'id': idMal});
      return data['Media']?['coverImage']?['extraLarge'] ??
          data['Media']?['coverImage']?['large'];
    } catch (_) {
      return null;
    }
  }

  /// Get CORS-friendly cover image from AniList by Title (fallback for new MAL IDs)
  Future<String?> getCoverImageByTitle(String title,
      {bool isManga = false}) async {
    final String typeStr = isManga ? 'MANGA' : 'ANIME';
    final String query = '''
      query (\$q: String) {
        Media(search: \$q, type: $typeStr) {
          coverImage { extraLarge large }
        }
      }
    ''';
    try {
      final data = await _postQuery(query, {'q': title});
      return data['Media']?['coverImage']?['extraLarge'] ??
          data['Media']?['coverImage']?['large'];
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _postQuery(
      String query, Map<String, dynamic> variables) async {
    final String cacheKey =
        jsonEncode({'query': query, 'variables': variables});

    // Check cache
    if (_cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheTtl) {
        return _cache[cacheKey];
      }
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] ?? {};

      // Store in cache
      _cache[cacheKey] = data;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return data;
    }
    throw Exception('AniList API error: ${response.statusCode}');
  }
}
