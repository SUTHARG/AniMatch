import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/hianime_models.dart';

class HianimeService {
  HianimeService._();
  static final HianimeService instance = HianimeService._();

  // Points to YOUR backend proxy, not AniWatch directly
  String get _base => dotenv.env['BACKEND_URL'] ?? '';

  final http.Client _client = http.Client();

  // In-memory cache
  final Map<String, String> _searchCache = {};
  final Map<String, HianimeEpisodeList> _episodeCache = {};
  final Map<String, HianimeStreamSources> _sourcesCache = {};
  final Map<String, AniSkipResult> _skipCache = {};

  // ── Search: title → hianime id ──────────────────────────────────────────
  Future<String?> searchAnimeId(String title) async {
    final key = title.toLowerCase().trim();
    if (_searchCache.containsKey(key)) return _searchCache[key];

    final uri = Uri.parse('$_base/api/stream/search')
        .replace(queryParameters: {'q': title});
    debugPrint('[HianimeService] search: $uri');

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      debugPrint('[HianimeService] search status: ${res.statusCode}');
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final animes = data?['animes'] as List<dynamic>?;
      if (animes == null || animes.isEmpty) return null;

      final id = (animes.first as Map<String, dynamic>)['id'] as String?;
      if (id != null) _searchCache[key] = id;
      debugPrint('[HianimeService] resolved id: $id');
      return id;
    } catch (e) {
      debugPrint('[HianimeService] search error: $e');
      return null;
    }
  }

  // ── Episode list ─────────────────────────────────────────────────────────
  Future<HianimeEpisodeList?> getEpisodes(String hianimeId) async {
    if (_episodeCache.containsKey(hianimeId)) return _episodeCache[hianimeId];

    final uri = Uri.parse('$_base/api/stream/episodes/$hianimeId');
    debugPrint('[HianimeService] episodes: $uri');

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = HianimeEpisodeList.fromJson(json);
      _episodeCache[hianimeId] = result;
      debugPrint('[HianimeService] episodes count: ${result.totalEpisodes}');
      return result;
    } catch (e) {
      debugPrint('[HianimeService] episodes error: $e');
      return null;
    }
  }

  // ── Streaming sources ─────────────────────────────────────────────────────
  Future<HianimeStreamSources?> getSources({
    required String episodeId,
    String category = 'sub',
    String server = 'hd-1',
  }) async {
    final cacheKey = '$episodeId:$category:$server';
    if (_sourcesCache.containsKey(cacheKey)) return _sourcesCache[cacheKey];

    final uri = Uri.parse('$_base/api/stream/sources').replace(
      queryParameters: {
        'episodeId': episodeId,
        'category': category,
        'server': server,
      },
    );
    debugPrint('[HianimeService] sources: $uri');

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 18));
      debugPrint('[HianimeService] sources status: ${res.statusCode}');
      debugPrint('[HianimeService] sources body: ${res.body}');
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = HianimeStreamSources.fromJson(json);
      if (result.sources.isNotEmpty) _sourcesCache[cacheKey] = result;
      debugPrint('[HianimeService] sources count: ${result.sources.length}');
      return result;
    } catch (e) {
      debugPrint('[HianimeService] sources error: $e');
      return null;
    }
  }

  // ── AniSkip OP/ED timestamps ──────────────────────────────────────────────
  Future<AniSkipResult> getSkipTimes({
    required int malId,
    required int episode,
    double? episodeLength,
  }) async {
    final cacheKey = '$malId:$episode';
    if (_skipCache.containsKey(cacheKey)) return _skipCache[cacheKey]!;

    final params = <String, String>{
      'malId': malId.toString(),
      'episode': episode.toString(),
    };
    if (episodeLength != null) {
      params['episodeLength'] = episodeLength.toStringAsFixed(3);
    }
    final uri = Uri.parse('$_base/api/stream/skip')
        .replace(queryParameters: params);

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const AniSkipResult(found: false, intervals: []);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final result = AniSkipResult.fromJson(json);
      _skipCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[HianimeService] skip error: $e');
      return const AniSkipResult(found: false, intervals: []);
    }
  }

  void clearCache() {
    _searchCache.clear();
    _episodeCache.clear();
    _sourcesCache.clear();
    _skipCache.clear();
  }
}
