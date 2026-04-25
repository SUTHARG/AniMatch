import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/models/hero_recommendation.dart';
import 'package:animatch/presentation/providers/service_providers.dart';
import 'package:animatch/presentation/providers/watchlist_provider.dart';

const defaultRecommendationMood = 'action';

final selectedRecommendationMoodProvider =
    NotifierProvider<RecommendationMoodNotifier, String>(
  RecommendationMoodNotifier.new,
);

final savedRecommendationMoodProvider =
    StreamProvider.autoDispose.family<String?, String>((ref, uid) {
  return ref.watch(firebaseServiceProvider).recommendationMoodStream(uid);
});

class RecommendationMoodNotifier extends Notifier<String> {
  bool _hasLocalSelection = false;

  @override
  String build() => defaultRecommendationMood;

  void hydrate(String mood) {
    if (_hasLocalSelection || mood.trim().isEmpty) return;
    state = mood;
  }

  Future<void> setMood(String mood, {String? uid}) async {
    _hasLocalSelection = true;
    state = mood;

    if (uid != null) {
      await ref.read(firebaseServiceProvider).saveRecommendationMood(uid, mood);
    }
  }
}

final recommendationProvider =
    FutureProvider.autoDispose.family<List<Anime>, RecommendationRequest>(
  (ref, request) {
    return ref.watch(animeRepositoryProvider).getRecommendations(
          mood: request.mood,
          watchedIds: request.watchedIds,
        );
  },
);

final homeRecommendationProvider =
    FutureProvider.autoDispose.family<List<Anime>, String>((ref, fallbackMood) {
  final user = ref.watch(authStateProvider).maybeWhen(
        data: (user) => user,
        orElse: () => FirebaseAuth.instance.currentUser,
      );

  final watchlistItems = user == null
      ? const <Map<String, dynamic>>[]
      : ref
          .watch(watchlistProvider(WatchlistFilter(
            uid: user.uid,
            isManga: false,
          )))
          .maybeWhen(
            data: (items) => items,
            orElse: () => const <Map<String, dynamic>>[],
          );

  final watchedIds =
      watchlistItems.map((item) => item['malId']).whereType<int>().toSet();
  final selectedMood = ref.watch(selectedRecommendationMoodProvider);
  final mood = selectedMood.trim().isEmpty
      ? (_deriveMoodFromWatchlist(watchlistItems) ?? fallbackMood)
      : selectedMood;

  return ref.watch(recommendationProvider(RecommendationRequest(
    mood: mood,
    watchedIds: watchedIds,
  )).future);
});

@immutable
class RecommendationRequest {
  final String mood;
  final Set<int> watchedIds;

  const RecommendationRequest({
    required this.mood,
    required this.watchedIds,
  });

  @override
  bool operator ==(Object other) {
    return other is RecommendationRequest &&
        other.mood == mood &&
        setEquals(other.watchedIds, watchedIds);
  }

  @override
  int get hashCode => Object.hash(mood, Object.hashAllUnordered(watchedIds));
}

String? _deriveMoodFromWatchlist(List<Map<String, dynamic>> items) {
  final genreCounts = <String, int>{};
  for (final item in items) {
    final genres = item['genres'];
    if (genres is! List) continue;
    for (final genre in genres) {
      final key = genre.toString().toLowerCase();
      genreCounts[key] = (genreCounts[key] ?? 0) + 1;
    }
  }

  if (genreCounts.isEmpty) return null;

  final topGenre = genreCounts.entries
      .reduce(
        (a, b) => a.value >= b.value ? a : b,
      )
      .key;

  if (topGenre.contains('romance')) return 'romantic';
  if (topGenre.contains('comedy')) return 'funny';
  if (topGenre.contains('horror')) return 'gore';
  if (topGenre.contains('mystery')) return 'mystery';
  if (topGenre.contains('sports')) return 'sports';
  if (topGenre.contains('slice')) return 'chill';
  if (topGenre.contains('adventure') || topGenre.contains('fantasy')) {
    return 'adventure';
  }
  if (topGenre.contains('drama')) return 'sad';
  if (topGenre.contains('thriller') || topGenre.contains('suspense')) {
    return 'dark';
  }

  return 'action';
}

// ── Hero / Decision-Engine Provider ──────────────────────────────────────────
//
// Returns ONE best anime for the user right now using the full hybrid engine:
//   S(a,u) = α·cosine + β·KL + γ·temporal + δ·Bayesian + ε·novelty
//
// Uses existing getRecommendations cache → first render is instant.

final heroRecommendationProvider =
    FutureProvider.autoDispose<HeroRecommendation>((ref) async {
  final user = ref.watch(authStateProvider).maybeWhen(
        data: (u) => u,
        orElse: () => FirebaseAuth.instance.currentUser,
      );

  final currentUser = user;
  final watchlistItems = currentUser == null
      ? const <Map<String, dynamic>>[]
      : ref
          .watch(watchlistProvider(WatchlistFilter(
            uid: currentUser.uid,
            isManga: false,
          )))
          .maybeWhen(
            data: (items) => items,
            orElse: () => const <Map<String, dynamic>>[],
          );

  final watchedIds =
      watchlistItems.map((e) => e['malId']).whereType<int>().toSet();

  // Mood: user selection → watchlist-derived → default
  final selectedMood = ref.watch(selectedRecommendationMoodProvider);
  final mood = selectedMood.trim().isEmpty
      ? (_deriveMoodFromWatchlist(watchlistItems) ?? defaultRecommendationMood)
      : selectedMood;

  // Pass the raw watchlist to the engine — it extracts genres,
  // ratings, timestamps, and computes all vectors internally.
  return ref.watch(animeRepositoryProvider).getHeroRecommendation(
        userId: currentUser?.uid,
        mood: mood,
        watchedIds: watchedIds,
        watchlistItems: watchlistItems,
      );
});

