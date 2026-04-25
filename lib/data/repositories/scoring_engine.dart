// lib/data/repositories/scoring_engine.dart
//
// On-device Hybrid Recommendation Scoring Engine
//
// Final score:
//   S(a,u) = α·cosine(gₐ, gᵤ)           [content similarity]
//           + β·(1 − KL(Pₐ ∥ Pᵤ)/5)     [behavioral distribution match]
//           + γ·cosine(gₐ, gᵤ_temporal)  [recency-weighted preference]
//           + δ·bayesian_rating           [popularity / quality]
//           + ε·novelty                  [anti-repetition]
//
// Weights (tunable):
//   α=0.35  β=0.25  γ=0.20  δ=0.15  ε=0.05
//
// Confidence → sigmoid:  σ(8S − 4)  rescaled to [60, 99]%

import 'dart:math' as math;
import 'package:animatch/data/models/anime.dart';

// ── Genre vocabulary (defines the vector space) ───────────────────────────────
// Each index is one dimension; order is stable.

const List<String> kGenreVocabulary = [
  'Action',       'Adventure',    'Cars',          'Comedy',
  'Dementia',     'Demons',       'Drama',         'Ecchi',
  'Fantasy',      'Game',         'Harem',         'Historical',
  'Horror',       'Isekai',       'Josei',         'Kids',
  'Magic',        'Martial Arts', 'Mecha',         'Military',
  'Music',        'Mystery',      'Parody',        'Police',
  'Psychological','Romance',      'Samurai',       'School',
  'Sci-Fi',       'Seinen',       'Shoujo',        'Shounen',
  'Slice of Life','Space',        'Sports',        'Super Power',
  'Supernatural', 'Thriller',     'Vampire',       'Award Winning',
];

const int _kDim = 40; // must equal kGenreVocabulary.length

// Build lookup once at startup.
final Map<String, int> _kGenreIndex = {
  for (var i = 0; i < kGenreVocabulary.length; i++)
    kGenreVocabulary[i].toLowerCase(): i,
};

// ── Weight configuration ──────────────────────────────────────────────────────

class ScoreWeights {
  final double alpha;   // content / cosine similarity
  final double beta;    // behavioral / KL divergence (reduced: noisy on small datasets)
  final double gamma;   // temporal preference (increased: recent behaviour is decisive)
  final double delta;   // Bayesian popularity (increased: users trust visible quality)
  final double epsilon; // novelty / anti-repetition

  const ScoreWeights({
    this.alpha   = 0.30, // ↓ from 0.35
    this.beta    = 0.10, // ↓ from 0.25 — KL contribution clamped
    this.gamma   = 0.25, // ↑ from 0.20
    this.delta   = 0.30, // ↑ from 0.15 — popularity is the tiebreaker
    this.epsilon = 0.05,
  });
}

// ── Score breakdown (one per candidate) ──────────────────────────────────────

class ScoredAnime {
  final Anime anime;
  final double totalScore;
  final double contentScore;
  final double behaviorScore;
  final double temporalScore;
  final double popularityScore;
  final double noveltyScore;

  const ScoredAnime({
    required this.anime,
    required this.totalScore,
    required this.contentScore,
    required this.behaviorScore,
    required this.temporalScore,
    required this.popularityScore,
    required this.noveltyScore,
  });

  /// Dominant factor label — used by explanation generator.
  String dominantFactor(ScoreWeights weights) {
    final scores = {
      'content':    contentScore   * weights.alpha,
      'behavior':   behaviorScore  * weights.beta,
      'temporal':   temporalScore  * weights.gamma,
      'popularity': popularityScore* weights.delta,
      'novelty':    noveltyScore   * weights.epsilon,
    };
    return scores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }
}

// ── Main engine ───────────────────────────────────────────────────────────────

class ScoringEngine {
  final ScoreWeights weights;

  // Bayesian rating constants
  static const double _kGlobalMean      = 7.0;    // C: global mean MAL score
  static const double _kMinVotes        = 10000.0; // m: confidence threshold
  static const double _kLambda          = 0.04;    // temporal decay (per day)
  static const double _kEps             = 1e-10;   // smoothing / zero-division
  static const double _kMaxKL           = 5.0;     // KL ceiling
  static const int    _kRecentN         = 10;      // "recent" window size
  // ── Decisiveness constants (Tasks 1, 2, 4) ────────────────────────────
  static const double _kTau             = 2.5;    // T1: sharpening exponent S' = S^τ
  static const double _kMarginThreshold = 0.08;   // T2: min gap before boost
  static const double _kMarginBoost     = 0.12;   // T2: boost added to winner
  static const int    _kSparseThreshold = 3;      // T4: watchlist items needed for KL

  const ScoringEngine({this.weights = const ScoreWeights()});

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Rank [pool], apply score sharpening + margin enforcement, return sorted.
  /// O(n) vector reuse — user context built once and shared across all candidates.
  List<ScoredAnime> rank(
    List<Anime> pool, {
    String? userId,
    required List<Map<String, dynamic>> watchlistItems,
    required Set<int> watchedIds,
  }) {
    final candidates = pool
        .where((a) => !watchedIds.contains(a.malId))
        .toList();

    if (candidates.isEmpty) return const [];

    // Build user context once (amortised O(1) per candidate)
    final userVec     = _userPreferenceVector(watchlistItems);
    final temporalVec = _temporalPreferenceVector(watchlistItems);
    final userDist    = _userGenreDistribution(watchlistItems);

    // T4: detect sparse watchlist → skip KL, use overlap fallback
    final genreItems = watchlistItems
        .where((e) { final g = e['genres']; return g is List && g.isNotEmpty; })
        .length;
    final isSparse = genreItems < _kSparseThreshold;

    // Score all candidates
    var scored = candidates
        .map((a) => _score(
              a,
              userVec:      userVec,
              temporalVec:  temporalVec,
              userDist:     userDist,
              recentHistory: watchlistItems,
              sparseData:   isSparse,
            ))
        .toList();

    // T1: Power sharpening
    scored = scored.map((s) {
      final sharpened = _pow(s.totalScore, _kTau);
      return ScoredAnime(
        anime:          s.anime,
        totalScore:     sharpened.clamp(0.0, 1.0),
        contentScore:   s.contentScore,
        behaviorScore:  s.behaviorScore,
        temporalScore:  s.temporalScore,
        popularityScore: s.popularityScore,
        noveltyScore:   s.noveltyScore,
      );
    }).toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // Exploration jitter: Only apply if top picks are mathematically identical/tight
    if (scored.length > 1) {
      final gap = scored[0].totalScore - scored[1].totalScore;
      final normalizedGap = gap / (scored[0].totalScore + 1e-6);
      if (normalizedGap < 0.03) {
        final now = DateTime.now();
        final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
        final rawSeed = (userId.hashCode * 31) + (dayOfYear * 17) + (watchedIds.length * 13);
        final seed = rawSeed & 0x7fffffff;
        final rng = math.Random(seed);
        scored = scored.map((s) {
          final noise = rng.nextDouble() * 0.01;
          return ScoredAnime(
            anime:          s.anime,
            totalScore:     (s.totalScore + noise).clamp(0.0, 1.0),
            contentScore:   s.contentScore,
            behaviorScore:  s.behaviorScore,
            temporalScore:  s.temporalScore,
            popularityScore: s.popularityScore,
            noveltyScore:   s.noveltyScore,
          );
        }).toList()
          ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
      }
    }

    // T2: Margin enforcement — guarantee a decisive winner
    if (scored.length >= 2) {
      final gap = scored[0].totalScore - scored[1].totalScore;
      if (gap < _kMarginThreshold) {
        final w = scored[0];
        scored[0] = ScoredAnime(
          anime:          w.anime,
          totalScore:     (w.totalScore + _kMarginBoost).clamp(0.0, 1.0),
          contentScore:   w.contentScore,
          behaviorScore:  w.behaviorScore,
          temporalScore:  w.temporalScore,
          popularityScore: w.popularityScore,
          noveltyScore:   w.noveltyScore,
        );
      }
    }

    return scored;
  }

  /// Confidence %  ∈ [60, 99]  — gap-aware sigmoid.
  ///
  ///   σ( S·6 + gap·4 + quality·3 − 4 )
  ///
  int confidencePercent(
    double score, {
    double normalizedGap = 0.0,
    double quality = 0.0,
    double penalty = 0.0,
  }) {
    final s = score.clamp(0.0, 1.0);
    final g = normalizedGap.clamp(0.0, 1.0);
    final q = quality.clamp(0.0, 1.0);

    final raw = s * 5.0 + g * 3.0 + q * 2.0 - 3.0 - penalty;
    final sig = _sigmoid(raw);
    return (sig * 39.0 + 60.0).round().clamp(60, 99);
  }

  double percentileThreshold(List<ScoredAnime> scored, double p) {
    if (scored.isEmpty) return 0.65;
    final scores = scored.map((e) => e.totalScore).toList()..sort();
    final index = (p * (scores.length - 1)).round();
    return scores[index];
  }

  /// H = -Sum( p_i * log(p_i) ) where p_i = score_i / sum(scores)
  /// Returns normalized entropy in [0, 1] range.
  double normalizedEntropy(List<ScoredAnime> scored) {
    if (scored.length <= 1) return 0.0;
    var sum = 0.0;
    for (final s in scored) {
      sum += s.totalScore;
    }
    if (sum < _kEps) return 0.0;

    var h = 0.0;
    for (final s in scored) {
      final p = s.totalScore / sum;
      if (p > _kEps) {
        h -= p * math.log(p);
      }
    }
    return h / math.log(scored.length);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VECTOR CONSTRUCTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Genre vector for one anime: binary, then L2-normalised.
  List<double> animeGenreVector(Anime anime) {
    final v = List<double>.filled(_kDim, 0.0);
    for (final g in anime.genres) {
      final idx = _kGenreIndex[g.toLowerCase()];
      if (idx != null) v[idx] = 1.0;
    }
    return _normalise(v);
  }

  /// User preference vector:  gᵤ = Σ rᵢ·gᵢ / Σ rᵢ  (L2-normalised)
  List<double> _userPreferenceVector(List<Map<String, dynamic>> items) {
    final sum = List<double>.filled(_kDim, 0.0);
    var totalW = 0.0;

    for (final item in items) {
      final w      = _ratingWeight(item);
      final genres = _extractGenres(item);
      if (genres.isEmpty) continue;
      _addWeightedGenres(sum, genres, w);
      totalW += w;
    }

    if (totalW < _kEps) return List<double>.filled(_kDim, 0.0);
    for (var i = 0; i < _kDim; i++) { sum[i] /= totalW; }
    return _normalise(sum);
  }

  /// Temporally-decayed preference vector:
  ///   gᵤ_temporal = Σ wᵢ·rᵢ·gᵢ  where  wᵢ = e^(−λ·daysAgo)
  List<double> _temporalPreferenceVector(List<Map<String, dynamic>> items) {
    final now = DateTime.now();
    final sum = List<double>.filled(_kDim, 0.0);
    var totalW = 0.0;

    for (final item in items) {
      final r      = _ratingWeight(item);
      final decay  = _temporalDecay(item, now);
      final w      = r * decay;
      final genres = _extractGenres(item);
      if (genres.isEmpty) continue;
      _addWeightedGenres(sum, genres, w);
      totalW += w;
    }

    if (totalW < _kEps) return List<double>.filled(_kDim, 0.0);
    for (var i = 0; i < _kDim; i++) { sum[i] /= totalW; }
    return _normalise(sum);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISTRIBUTIONS (for KL divergence)
  // ─────────────────────────────────────────────────────────────────────────

  /// P(gₖ | u) = Σ rᵢ·1(gₖ∈i) / Σ rᵢ
  List<double> _userGenreDistribution(List<Map<String, dynamic>> items) {
    final counts = List<double>.filled(_kDim, 0.0);
    var totalW = 0.0;

    for (final item in items) {
      final w      = _ratingWeight(item);
      final genres = _extractGenres(item);
      for (final g in genres) {
        final idx = _kGenreIndex[g.toLowerCase()];
        if (idx != null) {
          counts[idx] += w;
          totalW += w;
        }
      }
    }

    if (totalW < _kEps) {
      // Uniform: no preference data
      return List<double>.filled(_kDim, 1.0 / _kDim);
    }
    return [for (final c in counts) c / totalW];
  }

  /// P(gₖ | a): uniform over the anime's own genres.
  List<double> _animeGenreDistribution(Anime anime) {
    if (anime.genres.isEmpty) {
      return List<double>.filled(_kDim, 1.0 / _kDim);
    }
    final dist = List<double>.filled(_kDim, 0.0);
    final w = 1.0 / anime.genres.length;
    for (final g in anime.genres) {
      final idx = _kGenreIndex[g.toLowerCase()];
      if (idx != null) dist[idx] = w;
    }
    return dist;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCORE COMPONENTS
  // ─────────────────────────────────────────────────────────────────────────

  /// S_content = cosine(gₐ, gᵤ)  ∈ [0, 1]
  double _contentScore(List<double> animeVec, List<double> userVec) =>
      _cosine(animeVec, userVec);

  /// S_behavior = 1 − KL(Pₐ ∥ Pᵤ) / maxKL  ∈ [0, 1]
  ///
  /// KL divergence penalises mismatch in taste distribution.
  /// We negate and normalise so higher = better match.
  /// T4: sparse fallback — use L1 genre overlap instead of KL divergence
  /// when the watchlist has too few rated items for a stable distribution.
  double _behaviorScore(
    List<double> animeDist,
    List<double> userDist, {
    bool sparse = false,
  }) {
    if (sparse) {
      // Simple overlap:  Σ min(Pₐ, Pᵤ)  — stable even with 1-2 items
      var overlap = 0.0;
      for (var i = 0; i < _kDim; i++) {
        final m = animeDist[i] < userDist[i] ? animeDist[i] : userDist[i];
        overlap += m;
      }
      return overlap.clamp(0.0, 1.0);
    }
    final kl = _klDivergence(animeDist, userDist);
    return (1.0 - (kl / _kMaxKL)).clamp(0.0, 1.0);
  }

  /// S_temporal = cosine(gₐ, gᵤ_temporal)  ∈ [0, 1]
  double _temporalScore(List<double> animeVec, List<double> temporalVec) =>
      _cosine(animeVec, temporalVec);

  /// S_popularity = Bayesian adjusted rating / 10  ∈ [0, 1]
  ///
  ///   B = (v·R + m·C) / (v + m)
  ///     R = anime.score,  v = members,  C = global mean,  m = threshold
  double _popularityScore(Anime anime) {
    final R = anime.score ?? _kGlobalMean;
    final v = (anime.members ?? 0).toDouble();
    final bayesian = (v * R + _kMinVotes * _kGlobalMean) / (v + _kMinVotes);
    return (bayesian / 10.0).clamp(0.0, 1.0);
  }

  /// S_novelty = 1 − max_cosine(gₐ, recentWatched)  ∈ [0, 1]
  ///
  /// Penalises anime too similar to what was recently watched.
  double _noveltyScore(
    List<double> animeVec,
    List<Map<String, dynamic>> history,
  ) {
    if (history.isEmpty) return 1.0;

    final recent = history.length > _kRecentN
        ? history.sublist(history.length - _kRecentN)
        : history;

    var maxSim = 0.0;
    for (final item in recent) {
      final genres = _extractGenres(item);
      if (genres.isEmpty) continue;
      final v = _normalise(_rawGenreVector(genres));
      final sim = _cosine(animeVec, v);
      if (sim > maxSim) maxSim = sim;
    }
    return (1.0 - maxSim).clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPOSITE SCORER
  // ─────────────────────────────────────────────────────────────────────────

  ScoredAnime _score(
    Anime anime, {
    required List<double> userVec,
    required List<double> temporalVec,
    required List<double> userDist,
    required List<Map<String, dynamic>> recentHistory,
    bool sparseData = false,
  }) {
    final animeVec  = animeGenreVector(anime);
    final animeDist = _animeGenreDistribution(anime);

    final cs = _contentScore(animeVec, userVec);
    final bs = _behaviorScore(animeDist, userDist, sparse: sparseData); // T4
    final ts = _temporalScore(animeVec, temporalVec);
    final ps = _popularityScore(anime);
    final ns = _noveltyScore(animeVec, recentHistory);

    // Raw linear combination (sharpening applied later in rank())
    final total = weights.alpha   * cs
                + weights.beta    * bs
                + weights.gamma   * ts
                + weights.delta   * ps
                + weights.epsilon * ns;

    return ScoredAnime(
      anime:           anime,
      totalScore:      total.clamp(0.0, 1.0),
      contentScore:    cs,
      behaviorScore:   bs,
      temporalScore:   ts,
      popularityScore: ps,
      noveltyScore:    ns,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MATH PRIMITIVES
  // ─────────────────────────────────────────────────────────────────────────

  List<double> _normalise(List<double> v) {
    var mag = 0.0;
    for (final x in v) { mag += x * x; }
    mag = math.sqrt(mag);
    if (mag < _kEps) return v;
    return [for (final x in v) x / mag];
  }

  /// Cosine similarity between two pre-normalised vectors.
  double _cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    for (var i = 0; i < _kDim; i++) { dot += a[i] * b[i]; }
    return dot.clamp(0.0, 1.0);
  }

  /// KL(P ∥ Q) = Σ Pₖ · ln(Pₖ / Qₖ)   with Laplace smoothing on Q.
  double _klDivergence(List<double> p, List<double> q) {
    var kl = 0.0;
    for (var i = 0; i < _kDim; i++) {
      if (p[i] < _kEps) continue; // 0·log(0) ≡ 0
      final qSmoothed = q[i] + _kEps;
      kl += p[i] * math.log(p[i] / qSmoothed);
    }
    return kl.clamp(0.0, 20.0);
  }

  /// σ(x) = 1 / (1 + e^−x)
  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  double _pow(double base, double exponent) => math.pow(base, exponent).toDouble();

  /// wᵢ = e^(−λ · daysAgo)  — falls back to 1.0 when no timestamp.
  double _temporalDecay(Map<String, dynamic> item, DateTime now) {
    final raw = item['addedAt'];
    if (raw == null) return 1.0;

    DateTime? addedAt;
    try {
      // Firestore Timestamp has a .toDate() method
      addedAt = (raw as dynamic).toDate() as DateTime;
    } catch (_) {
      try {
        addedAt = raw as DateTime;
      } catch (_) {}
    }

    if (addedAt == null) return 1.0;
    final daysAgo = now.difference(addedAt).inDays.abs().toDouble();
    return math.exp(-_kLambda * daysAgo);
  }

  /// Rating weight: userRating/10 if present, else status-proxy.
  double _ratingWeight(Map<String, dynamic> item) {
    final r = item['userRating'];
    if (r is num && r > 0) return (r.toDouble() / 10.0).clamp(0.1, 1.0);

    switch (item['status'] as String? ?? '') {
      case 'completed':    return 0.80;
      case 'watching':     return 0.70;
      case 'planToWatch':  return 0.50;
      case 'onHold':       return 0.40;
      case 'dropped':      return 0.20;
      default:             return 0.50;
    }
  }

  List<String> _extractGenres(Map<String, dynamic> item) {
    final g = item['genres'];
    return g is List ? g.map((e) => e.toString()).toList() : const [];
  }

  List<double> _rawGenreVector(List<String> genres) {
    final v = List<double>.filled(_kDim, 0.0);
    for (final g in genres) {
      final idx = _kGenreIndex[g.toLowerCase()];
      if (idx != null) v[idx] = 1.0;
    }
    return v;
  }

  void _addWeightedGenres(
    List<double> sum,
    List<String> genres,
    double weight,
  ) {
    for (final g in genres) {
      final idx = _kGenreIndex[g.toLowerCase()];
      if (idx != null) sum[idx] += weight;
    }
  }
}

// ── Explanation generator ─────────────────────────────────────────────────────

/// Generates a one-sentence explanation based on the dominant score factor
/// and the anime's actual properties.
String buildHeroExplanation(ScoredAnime scored, String mood, ScoreWeights weights) {
  switch (scored.dominantFactor(weights)) {
    case 'content':
      if (scored.anime.genres.isNotEmpty) {
        final top = scored.anime.genres.take(2).join(' & ');
        return 'Matches your $top taste perfectly';
      }
      return 'Aligns closely with your genre preferences';

    case 'behavior':
      if (scored.behaviorScore > 0.75) {
        return 'Distribution of genres fits your watch history';
      }
      return 'Matches your viewing pattern across genres';

    case 'temporal':
      return 'Fits your recent watching trend';

    case 'popularity':
      final members = scored.anime.members ?? 0;
      final score   = scored.anime.score ?? 0;
      if (members >= 1000000) {
        final m = (members / 1000000).toStringAsFixed(1);
        return 'Loved by ${m}M+ fans worldwide';
      }
      if (score >= 8.5) {
        return 'One of the highest-rated ${_moodLabel(mood)} series';
      }
      return 'Critically acclaimed in the ${_moodLabel(mood)} genre';

    case 'novelty':
      return 'Something fresh — outside your usual picks';

    default:
      return 'Top pick for ${_moodLabel(mood)} vibes today';
  }
}

const _kMoodLabels = <String, String>{
  'dark':      'dark & intense',
  'funny':     'fun & lighthearted',
  'romantic':  'romantic',
  'action':    'action',
  'chill':     'chill',
  'adventure': 'epic adventure',
  'mystery':   'mystery',
  'battles':   'battle',
  'cozy':      'cozy',
  'gore':      'horror',
  'sports':    'sports',
  'sad':       'emotional',
};

String _moodLabel(String mood) => _kMoodLabels[mood] ?? mood;
