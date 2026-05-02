import 'package:flutter/foundation.dart';
import '../models/anime.dart';
import '../models/hianime_models.dart';
import '../sources/hianime_service.dart';

class StreamingRepository {
  StreamingRepository._();
  static final StreamingRepository instance = StreamingRepository._();

  final HianimeService _service = HianimeService.instance;
  final Map<String, String> _idCache = {}; // malId → hianimeId

  // ── Resolve hianime ID from Anime object ──────────────────────────────────
  Future<String?> resolveHianimeId(Anime anime) async {
    final key = anime.malId.toString();
    if (_idCache.containsKey(key)) return _idCache[key];

    final titlesToTry = [
      anime.title,
      if (anime.titleEnglish != null && anime.titleEnglish != anime.title)
        anime.titleEnglish!,
      // Try truncated title for long names
      if (anime.title.split(' ').length > 4)
        anime.title.split(' ').take(4).join(' '),
    ];

    for (final title in titlesToTry) {
      debugPrint('[StreamingRepo] trying title: "$title"');
      final id = await _service.searchAnimeId(title);
      if (id != null) {
        _idCache[key] = id;
        return id;
      }
    }
    return null;
  }

  // ── Get episode list ──────────────────────────────────────────────────────
  Future<HianimeEpisodeList?> getEpisodeList(Anime anime) async {
    final id = await resolveHianimeId(anime);
    if (id == null) return null;
    return _service.getEpisodes(id);
  }

  // ── Get streaming sources for a specific episode ─────────────────────────
  Future<HianimeStreamSources?> getStreamingSources({
    required Anime anime,
    required int episodeNumber,
    String category = 'sub',
  }) async {
    final hianimeId = await resolveHianimeId(anime);
    if (hianimeId == null) return null;

    final episodes = await _service.getEpisodes(hianimeId);
    final episode = episodes?.episodeByNumber(episodeNumber);

    // Fallback episodeId if not found in list
    final episodeId = episode?.episodeId ?? '$hianimeId?ep=$episodeNumber';

    return _service.getSources(episodeId: episodeId, category: category);
  }

  // ── Get AniSkip timestamps ────────────────────────────────────────────────
  Future<AniSkipResult> getSkipTimes({
    required int malId,
    required int episode,
    double? episodeLength,
  }) {
    return _service.getSkipTimes(
      malId: malId,
      episode: episode,
      episodeLength: episodeLength,
    );
  }
}
