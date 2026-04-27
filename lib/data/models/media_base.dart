abstract class MediaBase {
  int? get anilistId;
  int? get malId;
  String get displayTitle;
  String get displayImageUrl;
  double? get score;
  String get scoreText;
  List<String> get genres;
  String? get synopsis;
  String? get malUrl;

  // Added contextual accessors
  String get mediaProgressText; // E.g., "X episodes" or "Y chapters"
  String get mediaTypeBadge; // E.g., "TV" or "Manga"
  bool get isCompleted;
  bool get isOngoing;

  // Total counts
  int? get episodes;
  int? get chapters;
  String? get duration;
}
