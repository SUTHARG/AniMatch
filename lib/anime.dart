import 'media_base.dart';

// ---------------------------------------------------------------------------
// StreamingLink — a single streaming platform entry
// ---------------------------------------------------------------------------

/// Represents one streaming platform where an anime is available.
class StreamingLink {
  final String name; // e.g. "Crunchyroll", "Netflix"
  final String url;  // web URL for that platform's page for this anime

  const StreamingLink({required this.name, required this.url});

  factory StreamingLink.fromJson(Map<String, dynamic> json) => StreamingLink(
        name: json['name'] as String,
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

// ---------------------------------------------------------------------------
// Anime model
// ---------------------------------------------------------------------------

class Anime implements MediaBase {
  @override
  final int malId;
  final String title;
  final String? titleEnglish;
  final String imageUrl;
  @override
  final String? synopsis;
  @override
  final double? score;
  final int? episodes;
  final String? status;
  final String? type;
  final int? year;
  @override
  final List<String> genres;
  final String? trailerUrl;
  final int? rank;
  final int? members;

  /// Direct link to this anime's page on MyAnimeList.
  @override
  final String? malUrl;

  /// Streaming platforms where this anime is available (populated separately
  /// via JikanService.fetchStreamingLinks or from Firestore cache).
  final List<StreamingLink>? streamingLinks;
  final String? broadcastTime;
  final String? titleJapanese;
  final List<String> synonyms;
  final String? duration;
  final String? rating;
  final String? airedString;
  final List<String> studios;
  final List<String> producers;
  final String? premiered;

  const Anime({
    required this.malId,
    required this.title,
    this.titleEnglish,
    required this.imageUrl,
    this.synopsis,
    this.score,
    this.episodes,
    this.status,
    this.type,
    this.year,
    required this.genres,
    this.trailerUrl,
    this.rank,
    this.members,
    this.malUrl,
    this.streamingLinks,
    this.broadcastTime,
    this.titleJapanese,
    this.synonyms = const [],
    this.duration,
    this.rating,
    this.airedString,
    this.studios = const [],
    this.producers = const [],
    this.premiered,
  });

  @override
  String get displayTitle => titleEnglish?.isNotEmpty == true ? titleEnglish! : title;

  @override
  String get displayImageUrl => imageUrl;

  @override
  String get scoreText => score != null ? score!.toStringAsFixed(1) : 'N/A';

  @override
  String get mediaProgressText => '${type ?? 'TV'} (${episodes?.toString() ?? '?'} eps)';

  @override
  String get mediaTypeBadge => type ?? 'TV';

  @override
  bool get isCompleted => status?.toLowerCase() == 'completed' || status?.toLowerCase() == 'finished';

  @override
  bool get isOngoing => status?.toLowerCase() == 'airing' || status?.toLowerCase() == 'ongoing';

  factory Anime.fromJson(Map<String, dynamic> json) {
    final images = json['images']?['jpg'];
    final imageUrl = images?['large_image_url'] ??
        images?['image_url'] ??
        'https://via.placeholder.com/225x320';

    final genreList = (json['genres'] as List<dynamic>? ?? [])
        .map((g) => g['name'] as String)
        .toList();

    final malId = json['mal_id'] as int;

    return Anime(
      malId: malId,
      title: json['title'] as String? ?? 'Unknown',
      titleEnglish: json['title_english'] as String?,
      imageUrl: imageUrl,
      synopsis: json['synopsis'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      type: json['type'] as String?,
      year: json['year'] as int?,
      genres: genreList,
      trailerUrl: _parseTrailerUrl(json['trailer']),
      rank: json['rank'] as int?,
      members: json['members'] as int?,
      malUrl: 'https://myanimelist.net/anime/$malId',
      streamingLinks: (json['streaming'] as List<dynamic>?)
          ?.map((e) => StreamingLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      broadcastTime: json['broadcast'] != null 
          ? json['broadcast']['time'] as String?
          : null,
      titleJapanese: json['title_japanese'] as String?,
      synonyms: (json['titles'] as List<dynamic>? ?? [])
          .where((t) => t['type'] != 'Default')
          .map((t) => t['title'] as String)
          .toList(),
      duration: json['duration'] as String?,
      rating: json['rating'] as String?,
      airedString: json['aired']?['string'] as String?,
      studios: (json['studios'] as List<dynamic>? ?? [])
          .map((s) => s['name'] as String)
          .toList(),
      producers: (json['producers'] as List<dynamic>? ?? [])
          .map((p) => p['name'] as String)
          .toList(),
      premiered: json['season'] != null && json['year'] != null
          ? "${json['season'].toString().toUpperCase()} ${json['year']}"
          : null,
    );
  }

  factory Anime.fromAniList(Map<String, dynamic> json) {
    final titleObj = json['title'] ?? {};
    final title = titleObj['english'] ?? titleObj['romaji'] ?? 'Unknown';
    final titleEnglish = titleObj['english'] as String?;
    final imageUrl = json['coverImage']?['extraLarge'] ?? json['coverImage']?['large'] ?? '';
    
    final genres = (json['genres'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return Anime(
      malId: json['idMal'] ?? 0,
      title: title,
      titleEnglish: titleEnglish,
      imageUrl: imageUrl,
      synopsis: json['description']?.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ''), // Strip HTML
      score: (json['averageScore'] as num?)?.toDouble() != null 
          ? (json['averageScore'] as num).toDouble() / 10.0 
          : null,
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      genres: genres,
      malUrl: 'https://myanimelist.net/anime/${json['idMal']}',
    );
  }

  String get malPageUrl => malUrl ?? 'https://myanimelist.net/anime/$malId';

  static String? _parseTrailerUrl(Map<String, dynamic>? trailer) {
    if (trailer == null) return null;

    // 1. Try regular URL first
    final url = trailer['url'] as String?;
    if (url != null && url.isNotEmpty && !url.contains('embed')) return url;

    // 2. Try YouTube ID
    final youtubeId = trailer['youtube_id'] as String?;
    if (youtubeId != null && youtubeId.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$youtubeId';
    }

    // 3. Try parsing ID from embed_url
    final embedUrl = trailer['embed_url'] as String?;
    if (embedUrl != null && embedUrl.isNotEmpty) {
      if (embedUrl.contains('youtube.com/embed/')) {
        final id = embedUrl.split('youtube.com/embed/').last.split('?').first;
        return 'https://www.youtube.com/watch?v=$id';
      }
      if (embedUrl.contains('youtube-nocookie.com/embed/')) {
        final id = embedUrl.split('youtube-nocookie.com/embed/').last.split('?').first;
        return 'https://www.youtube.com/watch?v=$id';
      }
      return embedUrl;
    }

    return null;
  }
}

class QuizAnswers {
  final String mood;
  final List<String> genres;
  final String episodeRange;
  final String status;
  final String? typeParam;
  final bool isManga;

  const QuizAnswers({
    required this.mood,
    required this.genres,
    required this.episodeRange,
    required this.status,
    this.typeParam,
    this.isManga = false,
  });

  // Map mood to MyAnimeList genre IDs
  static const Map<String, List<int>> moodToGenreIds = {
    'dark': [41, 14, 7],        // Thriller, Horror, Mystery
    'funny': [4, 20],            // Comedy, Parody
    'romantic': [22, 43],        // Romance, Josei
    'action': [1, 24],           // Action, Sci-Fi
    'chill': [36, 15],           // Slice of Life, Kids
    'adventure': [2, 10],        // Adventure, Fantasy
    'mystery': [7, 41],          // Mystery, Suspense
    'battles': [1, 17],          // Action, Martial Arts
    'cozy': [36, 46],            // Slice of Life, Award Winning
    'gore': [14, 41],            // Horror, Thriller
    'sports': [30],              // Sports
    'sad': [8, 41],              // Drama, Suspense
  };

  static const Map<String, String> genreNameToId = {
    'Action': '1',
    'Adventure': '2',
    'Cars': '3',
    'Comedy': '4',
    'Dementia': '5',
    'Demons': '6',
    'Drama': '8',
    'Ecchi': '9',
    'Fantasy': '10',
    'Game': '11',
    'Harem': '35',
    'Historical': '13',
    'Horror': '14',
    'Isekai': '62',
    'Josei': '43',
    'Kids': '15',
    'Magic': '16',
    'Martial Arts': '17',
    'Mecha': '18',
    'Military': '38',
    'Music': '19',
    'Mystery': '7',
    'Parody': '20',
    'Police': '39',
    'Psychological': '40',
    'Romance': '22',
    'Samurai': '21',
    'School': '23',
    'Sci-Fi': '24',
    'Seinen': '42',
    'Shoujo': '25',
    'Shoujo Ai': '26',
    'Shounen': '27',
    'Shounen Ai': '28',
    'Slice of Life': '36',
    'Space': '29',
    'Sports': '30',
    'Super Power': '31',
    'Supernatural': '37',
    'Thriller': '41',
    'Vampire': '32',
  };

  List<int> get genreIds {
    final ids = <int>{};
    // Add user-selected genres first
    for (final g in genres) {
      final id = genreNameToId[g];
      if (id != null) ids.add(int.parse(id));
      if (ids.length >= 2) break; // Limit to max 2 genres to avoid over-filtering
    }
    
    // Fallback to mood genre only if no user genres were selected
    if (ids.isEmpty) {
      final moodIds = moodToGenreIds[mood] ?? [];
      ids.addAll(moodIds.take(1));
    }
    
    return ids.toList();
  }

  String get statusParam {
    if (isManga) {
      switch (status) {
        case 'ongoing':
          return 'publishing';
        case 'completed':
          return 'complete';
        default:
          return '';
      }
    }
    
    switch (status) {
      case 'ongoing':
        return 'airing';
      case 'completed':
        return 'complete';
      default:
        return '';
    }
  }

  int? get minEpisodes {
    switch (episodeRange) {
      case 'medium':
        return 13;
      case 'long':
        return 50;
      default:
        return null;
    }
  }

  int? get maxEpisodes {
    switch (episodeRange) {
      case 'short':
        return 13;
      case 'medium':
        return 50;
      default:
        return null;
    }
  }
}

class AnimeCharacter {
  final int id;
  final String name;
  final String imageUrl;
  final String role; // "Main" or "Supporting"

  const AnimeCharacter({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });

  factory AnimeCharacter.fromJson(Map<String, dynamic> json) {
    final char = json['character'] as Map<String, dynamic>? ?? {};
    return AnimeCharacter(
      id: char['mal_id'] as int? ?? 0,
      name: char['name'] as String? ?? 'Unknown',
      imageUrl: char['images']?['jpg']?['image_url'] as String? ?? 'https://via.placeholder.com/150',
      role: json['role'] as String? ?? 'Supporting',
    );
  }
}
