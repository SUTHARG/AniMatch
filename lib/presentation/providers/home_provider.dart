import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/models/hero_recommendation.dart';
import 'package:animatch/presentation/providers/service_providers.dart';
import 'package:animatch/presentation/providers/recommendation_provider.dart';

@immutable
class HomeState {
  final RecommendationMode mode;
  final Anime? hero;
  final List<Anime> alternatives;
  final int confidence;
  final String explanation;

  const HomeState({
    required this.mode,
    this.hero,
    this.alternatives = const [],
    this.confidence = 0,
    this.explanation = '',
  });

  factory HomeState.explore() {
    return const HomeState(
      mode: RecommendationMode.explore,
    );
  }
}

class HomeViewModel extends AsyncNotifier<HomeState> {
  @override
  FutureOr<HomeState> build() async {
    return _fetchRecommendation();
  }

  Future<HomeState> _fetchRecommendation() async {
    final repo = ref.read(animeRepositoryProvider);
    final selectedMood = ref.read(selectedRecommendationMoodProvider);
    final mood = selectedMood.trim().isEmpty ? 'action' : selectedMood;

    final result = await repo.getHeroRecommendation(
      mood: mood,
      watchedIds: const {},
      watchlistItems: const [],
    );

    if (result.mode == RecommendationMode.explore) {
      return HomeState.explore();
    }

    return HomeState(
      mode: result.mode,
      hero: result.anime,
      alternatives: result.alternatives,
      confidence: result.confidence,
      explanation: result.explanation,
    );
  }

  Future<void> refreshRecommendation() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRecommendation());
  }

  Future<void> setMood(String mood) async {
    ref.read(selectedRecommendationMoodProvider.notifier).setMood(mood);
    await refreshRecommendation();
  }
}

final homeViewModelProvider = AsyncNotifierProvider<HomeViewModel, HomeState>(
  () => HomeViewModel(),
);
