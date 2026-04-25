import 'package:animatch/data/models/media_base.dart';

class Manga implements MediaBase {
  @override
  final int malId;
  final String title;
  final String? titleEnglish;
  final String imageUrl;
  @override
  final String? synopsis;
  @override
  final double? score;
  @override
  final int? chapters;
  final int? volumes;
  final String? status;
  final String? type; // Manga, Novel, Light Novel, One-shot, Doujinshi, Manhwa, Manhua, OEL
  @override
  final List<String> genres;
  final int? rank;
  final int? members;

  /// Direct link to this manga's page on MyAnimeList.
  @override
  final String? malUrl;

  final String? titleJapanese;
  final List<String> synonyms;
  final String? publishedString;
  final List<String> authors;
  final List<String> serializations;

  const Manga({
    required this.malId,
    required this.title,
    this.titleEnglish,
    required this.imageUrl,
    this.synopsis,
    this.score,
    this.chapters,
    this.volumes,
    this.status,
    this.type,
    required this.genres,
    this.rank,
    this.members,
    this.malUrl,
    this.titleJapanese,
    this.synonyms = const [],
    this.publishedString,
    this.authors = const [],
    this.serializations = const [],
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final images = json['images']?['jpg'];
    final imageUrl = images?['large_image_url'] ??
        images?['image_url'] ??
        'https://via.placeholder.com/225x320';

    final genreList = (json['genres'] as List<dynamic>? ?? [])
        .map((g) => g['name'] as String)
        .toList();

    final malId = json['mal_id'] as int;

    return Manga(
      malId: malId,
      title: json['title'] as String? ?? 'Unknown',
      titleEnglish: json['title_english'] as String?,
      imageUrl: imageUrl,
      synopsis: json['synopsis'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      chapters: json['chapters'] as int?,
      volumes: json['volumes'] as int?,
      status: json['status'] as String?,
      type: json['type'] as String?,
      genres: genreList,
      rank: json['rank'] as int?,
      members: json['members'] as int?,
      malUrl: 'https://myanimelist.net/manga/$malId',
      titleJapanese: json['title_japanese'] as String?,
      synonyms: (json['titles'] as List<dynamic>? ?? [])
          .where((t) => t['type'] != 'Default')
          .map((t) => t['title'] as String)
          .toList(),
      publishedString: json['published']?['string'] as String?,
      authors: (json['authors'] as List<dynamic>? ?? [])
          .map((a) => a['name'] as String)
          .toList(),
      serializations: (json['serializations'] as List<dynamic>? ?? [])
          .map((s) => s['name'] as String)
          .toList(),
    );
  }

  @override
  String get displayTitle => titleEnglish?.isNotEmpty == true ? titleEnglish! : title;

  String get chapterText {
    if (chapters == null) {
      if (isOngoing) return 'Serialized';
      if (status?.toLowerCase() == 'on hiatus') return 'On Hiatus';
      return 'Unknown Chapters';
    }
    if (chapters == 1) return '1 chapter';
    return '$chapters chapters';
  }
  
  String get volumeText {
    if (volumes == null) return 'Unknown volumes';
    if (volumes == 1) return '1 volume';
    return '$volumes volumes';
  }

  @override
  String get scoreText => score != null ? score!.toStringAsFixed(1) : 'N/A';

  @override
  String get mediaProgressText => chapterText;
  
  @override
  String get mediaTypeBadge => type ?? 'Manga';

  String get malPageUrl => malUrl ?? 'https://myanimelist.net/manga/$malId';

  @override
  bool get isCompleted => status?.toLowerCase() == 'finished';
  @override
  bool get isOngoing => status?.toLowerCase() == 'publishing';

  @override
  int? get episodes => null;

  @override
  String? get duration => null;

  @override
  String get displayImageUrl => imageUrl;
}

class MangaCharacter {
  final int id;
  final String name;
  final String imageUrl;
  final String role; // "Main" or "Supporting"

  const MangaCharacter({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.role,
  });

  factory MangaCharacter.fromJson(Map<String, dynamic> json) {
    final char = json['character'] as Map<String, dynamic>? ?? {};
    return MangaCharacter(
      id: char['mal_id'] as int? ?? 0,
      name: char['name'] as String? ?? 'Unknown',
      imageUrl: char['images']?['jpg']?['image_url'] as String? ?? 'https://via.placeholder.com/150',
      role: json['role'] as String? ?? 'Supporting',
    );
  }
}
