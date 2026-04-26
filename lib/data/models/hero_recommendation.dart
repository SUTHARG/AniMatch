// lib/data/models/hero_recommendation.dart

import 'package:flutter/foundation.dart';
import 'package:animatch/data/models/anime.dart';

enum RecommendationMode {
  confident,
  weak,
  explore,
}

@immutable
class HeroRecommendation {
  /// The single best-matching anime.
  final Anime anime;

  /// 0–100 match score shown to the user ("92% match").
  final int confidence;

  /// One short sentence explaining the pick dynamically.
  final String explanation;

  /// Up to 3 alternative picks shown below the hero card.
  final List<Anime> alternatives;

  /// The confidence state of the recommendation.
  final RecommendationMode mode;

  /// Backward-compatible getters for UI
  bool get isConfident => mode == RecommendationMode.confident;
  bool get needsUserInput => mode == RecommendationMode.explore;

  // ── Score breakdown (for transparency / debugging) ─────────────────────────
  final double contentScore; // cosine similarity  [0, 1]
  final double behaviorScore; // 1 - KL divergence  [0, 1]
  final double temporalScore; // recency cosine     [0, 1]
  final double popularityScore; // Bayesian rating    [0, 1]
  final double noveltyScore; // anti-repetition    [0, 1]

  const HeroRecommendation({
    required this.anime,
    required this.confidence,
    required this.explanation,
    this.alternatives = const [],
    this.mode = RecommendationMode.confident,
    this.contentScore = 0,
    this.behaviorScore = 0,
    this.temporalScore = 0,
    this.popularityScore = 0,
    this.noveltyScore = 0,
  });
}
