import 'package:hive/hive.dart';

import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/models/manga.dart';
import 'package:animatch/data/models/media_base.dart';

class CacheService {
  static const String _boxName = 'animatch_cache';
  static const Duration _ttl = Duration(minutes: 7);

  Future<Box<dynamic>> get _box => Hive.openBox<dynamic>(_boxName);

  Future<List<Anime>?> getTopAnime({String tab = 'Today'}) async {
    final data = await _readList(_topAnimeKey(tab));
    if (data == null) return null;
    return data.map(_animeFromCache).whereType<Anime>().toList();
  }

  Future<void> saveTopAnime(List<Anime> anime, {String tab = 'Today'}) {
    return _writeList(_topAnimeKey(tab), anime.map(_animeToCache).toList());
  }

  Future<List<MediaBase>?> getSearchResults(
    String query, {
    bool isManga = false,
  }) async {
    final data = await _readList(_searchKey(query, isManga: isManga));
    if (data == null) return null;
    if (isManga) {
      return data.map(_mangaFromCache).whereType<Manga>().toList();
    }
    return data.map(_animeFromCache).whereType<Anime>().toList();
  }

  Future<void> saveSearchResults(
    String query,
    List<MediaBase> results, {
    bool isManga = false,
  }) {
    final data = isManga
        ? results.whereType<Manga>().map(_mangaToCache).toList()
        : results.whereType<Anime>().map(_animeToCache).toList();
    return _writeList(_searchKey(query, isManga: isManga), data);
  }

  Future<List<Anime>?> getRecommendations(String mood) async {
    final data = await _readList(_recommendationKey(mood));
    if (data == null) return null;
    return data.map(_animeFromCache).whereType<Anime>().toList();
  }

  Future<void> saveRecommendations(String mood, List<Anime> anime) {
    return _writeList(
        _recommendationKey(mood), anime.map(_animeToCache).toList());
  }

  Future<List<Map<String, dynamic>>?> _readList(String key) async {
    final box = await _box;
    final raw = box.get(key);
    if (raw is! Map) return null;

    final cachedAtMs = raw['cachedAt'] as int?;
    final items = raw['items'];
    if (cachedAtMs == null || items is! List) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
    if (DateTime.now().difference(cachedAt) > _ttl) {
      await box.delete(key);
      return null;
    }

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final box = await _box;
    await box.put(key, {
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
      'items': items,
    });
  }

  String _topAnimeKey(String tab) => 'top_anime:${tab.toLowerCase()}';

  String _searchKey(String query, {required bool isManga}) {
    return 'search:${isManga ? 'manga' : 'anime'}:${query.trim().toLowerCase()}';
  }

  String _recommendationKey(String mood) =>
      'recommendations:${mood.trim().toLowerCase()}';

  Map<String, dynamic> _animeToCache(Anime anime) {
    return {
      'malId': anime.malId,
      'title': anime.title,
      'titleEnglish': anime.titleEnglish,
      'imageUrl': anime.imageUrl,
      'synopsis': anime.synopsis,
      'score': anime.score,
      'episodes': anime.episodes,
      'status': anime.status,
      'type': anime.type,
      'year': anime.year,
      'genres': anime.genres,
      'trailerUrl': anime.trailerUrl,
      'rank': anime.rank,
      'members': anime.members,
      'malUrl': anime.malUrl,
      'broadcastTime': anime.broadcastTime,
      'titleJapanese': anime.titleJapanese,
      'synonyms': anime.synonyms,
      'duration': anime.duration,
      'rating': anime.rating,
      'airedString': anime.airedString,
      'studios': anime.studios,
      'producers': anime.producers,
      'premiered': anime.premiered,
      'source': anime.source,
    };
  }

  Anime? _animeFromCache(Map<String, dynamic> data) {
    final malId = data['malId'] as int?;
    final title = data['title'] as String?;
    final imageUrl = data['imageUrl'] as String?;
    if (malId == null || title == null || imageUrl == null) return null;

    return Anime(
      malId: malId,
      title: title,
      titleEnglish: data['titleEnglish'] as String?,
      imageUrl: imageUrl,
      synopsis: data['synopsis'] as String?,
      score: (data['score'] as num?)?.toDouble(),
      episodes: data['episodes'] as int?,
      status: data['status'] as String?,
      type: data['type'] as String?,
      year: data['year'] as int?,
      genres: _stringList(data['genres']),
      trailerUrl: data['trailerUrl'] as String?,
      rank: data['rank'] as int?,
      members: data['members'] as int?,
      malUrl: data['malUrl'] as String?,
      broadcastTime: data['broadcastTime'] as String?,
      titleJapanese: data['titleJapanese'] as String?,
      synonyms: _stringList(data['synonyms']),
      duration: data['duration'] as String?,
      rating: data['rating'] as String?,
      airedString: data['airedString'] as String?,
      studios: _stringList(data['studios']),
      producers: _stringList(data['producers']),
      premiered: data['premiered'] as String?,
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> _mangaToCache(Manga manga) {
    return {
      'malId': manga.malId,
      'title': manga.title,
      'titleEnglish': manga.titleEnglish,
      'imageUrl': manga.imageUrl,
      'synopsis': manga.synopsis,
      'score': manga.score,
      'chapters': manga.chapters,
      'volumes': manga.volumes,
      'status': manga.status,
      'type': manga.type,
      'genres': manga.genres,
      'rank': manga.rank,
      'members': manga.members,
      'malUrl': manga.malUrl,
      'titleJapanese': manga.titleJapanese,
      'synonyms': manga.synonyms,
      'publishedString': manga.publishedString,
      'authors': manga.authors,
      'serializations': manga.serializations,
    };
  }

  Manga? _mangaFromCache(Map<String, dynamic> data) {
    final malId = data['malId'] as int?;
    final title = data['title'] as String?;
    final imageUrl = data['imageUrl'] as String?;
    if (malId == null || title == null || imageUrl == null) return null;

    return Manga(
      malId: malId,
      title: title,
      titleEnglish: data['titleEnglish'] as String?,
      imageUrl: imageUrl,
      synopsis: data['synopsis'] as String?,
      score: (data['score'] as num?)?.toDouble(),
      chapters: data['chapters'] as int?,
      volumes: data['volumes'] as int?,
      status: data['status'] as String?,
      type: data['type'] as String?,
      genres: _stringList(data['genres']),
      rank: data['rank'] as int?,
      members: data['members'] as int?,
      malUrl: data['malUrl'] as String?,
      titleJapanese: data['titleJapanese'] as String?,
      synonyms: _stringList(data['synonyms']),
      publishedString: data['publishedString'] as String?,
      authors: _stringList(data['authors']),
      serializations: _stringList(data['serializations']),
    );
  }

  List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
  }
}
