class Anime {
  final int malId;
  final String title;
  final String? titleEnglish;
  final String imageUrl;
  final String? synopsis;
  final double? score;
  final int? episodes;
  final String? status;
  final String? type;
  final int? year;
  final List<String> genres;
  final String? trailerUrl;
  final int? rank;
  final int? members;

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
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    final images = json['images']?['jpg'];
    final imageUrl = images?['large_image_url'] ??
        images?['image_url'] ??
        'https://via.placeholder.com/225x320';

    final genreList = (json['genres'] as List<dynamic>? ?? [])
        .map((g) => g['name'] as String)
        .toList();

    return Anime(
      malId: json['mal_id'] as int,
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
      trailerUrl: json['trailer']?['url'] as String?,
      rank: json['rank'] as int?,
      members: json['members'] as int?,
    );
  }

  String get displayTitle => titleEnglish?.isNotEmpty == true ? titleEnglish! : title;

  String get episodeText {
    if (episodes == null) return 'Unknown eps';
    if (episodes == 1) return '1 episode';
    return '$episodes episodes';
  }

  String get scoreText => score != null ? score!.toStringAsFixed(1) : 'N/A';

  bool get isCompleted => status?.toLowerCase() == 'finished airing';
  bool get isOngoing => status?.toLowerCase() == 'currently airing';
}

class QuizAnswers {
  final String mood;
  final List<String> genres;
  final String episodeRange;
  final String status;

  const QuizAnswers({
    required this.mood,
    required this.genres,
    required this.episodeRange,
    required this.status,
  });

  // Map mood to Jikan genre IDs
  static const Map<String, List<int>> moodToGenreIds = {
    'dark': [41, 37, 7],        // Thriller, Supernatural, Mystery
    'funny': [4, 9],             // Comedy, Ecchi(light)
    'romantic': [22, 74],        // Romance, Isekai
    'action': [1, 24],           // Action, Sci-Fi
    'chill': [36, 8],            // Slice of Life, Drama
    'adventure': [2, 10],        // Adventure, Fantasy
  };

  static const Map<String, String> genreNameToId = {
    'Action': '1',
    'Adventure': '2',
    'Comedy': '4',
    'Drama': '8',
    'Fantasy': '10',
    'Romance': '22',
    'Sci-Fi': '24',
    'Slice of Life': '36',
    'Thriller': '41',
    'Mystery': '7',
    'Horror': '14',
    'Sports': '30',
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
