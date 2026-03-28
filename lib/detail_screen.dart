import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime.dart';
import 'jikan_service.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'watch_status_sheet.dart';
import 'rating_sheet.dart';

class DetailScreen extends StatefulWidget {
  final int malId;
  const DetailScreen({super.key, required this.malId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final JikanService _jikan = JikanService();
  final FirebaseService _firebase = FirebaseService();

  Anime? _anime;
  bool _loading = true;
  WatchStatus? _watchStatus;
  int _episodeProgress = 0;
  double? _userRating;
  String? _userReview;
  List<Anime> _similar = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final anime = await _jikan.getAnimeDetail(widget.malId);

      // Save to history
      if (_firebase.isLoggedIn) _firebase.addToHistory(anime);

      // Load watchlist entry
      Map<String, dynamic>? entry;
      if (_firebase.isLoggedIn) {
        entry = await _firebase.getWatchlistEntry(widget.malId);
      }

      // Load similar anime (background)
      _jikan.getSimilarAnime(widget.malId).then((list) {
        if (mounted) setState(() => _similar = list);
      });

      if (mounted) {
        setState(() {
          _anime = anime;
          _watchStatus = entry != null
              ? WatchStatus.fromString(entry['status'] as String?)
              : null;
          _episodeProgress = entry?['episodeProgress'] as int? ?? 0;
          _userRating = (entry?['userRating'] as num?)?.toDouble();
          _userReview = entry?['userReview'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openStatusSheet() async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    final result = await showWatchStatusSheet(
      context, anime: _anime!, currentStatus: _watchStatus,
    );
    if (mounted) setState(() => _watchStatus = result);
  }

  Future<void> _openRatingSheet() async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    await showRatingSheet(
      context,
      malId: widget.malId,
      animeTitle: _anime!.displayTitle,
      currentRating: _userRating,
      currentReview: _userReview,
    );
    // Reload rating
    final data = await _firebase.getRatingAndReview(widget.malId);
    if (mounted && data != null) {
      setState(() {
        _userRating = (data['rating'] as num?)?.toDouble();
        _userReview = data['review'] as String?;
      });
    }
  }

  Future<void> _updateProgress(int ep) async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    await _firebase.updateEpisodeProgress(widget.malId, ep);
    if (mounted) setState(() => _episodeProgress = ep);
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Log in to track this anime'),
        action: SnackBarAction(
          label: 'Login',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LoginScreen())),
        ),
      ),
    );
  }

  void _share() {
    final anime = _anime;
    if (anime == null) return;
    final text =
        'Check out "${anime.displayTitle}" on AniMatch!\n'
        'Score: ${anime.scoreText} · ${anime.episodeText}\n'
        'Genres: ${anime.genres.take(3).join(", ")}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anime info copied to clipboard! Share it anywhere 📋'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _statusColor(ColorScheme cs) {
    switch (_watchStatus) {
      case WatchStatus.watching:    return const Color(0xFF4CAF50);
      case WatchStatus.completed:   return const Color(0xFF9C27B0);
      case WatchStatus.onHold:      return const Color(0xFFFF9800);
      case WatchStatus.dropped:     return const Color(0xFFF44336);
      case WatchStatus.planToWatch: return const Color(0xFF2196F3);
      default:                      return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _anime == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error ?? 'Failed')));
    }

    final anime = _anime!;
    final inList = _watchStatus != null;
    final totalEps = anime.episodes;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: anime.imageUrl, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, colorScheme.surface.withOpacity(0.95)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Share button
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: _share,
                tooltip: 'Share',
              ),
              // Status badge
              if (inList)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: _openStatusSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(colorScheme).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor(colorScheme), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_watchStatus!.emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(_watchStatus!.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(colorScheme))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title
                Text(anime.displayTitle,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (anime.titleEnglish != null && anime.titleEnglish != anime.title) ...[
                  const SizedBox(height: 4),
                  Text(anime.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 16),
                _StatsRow(anime: anime),
                const SizedBox(height: 16),

                // Genres
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: anime.genres.map((g) => Chip(
                    label: Text(g, style: TextStyle(fontSize: 12, color: colorScheme.onSecondaryContainer)),
                    backgroundColor: colorScheme.secondaryContainer,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
                const SizedBox(height: 20),

                // ── Episode Progress (only if watching + has episodes) ──
                if (inList && _watchStatus == WatchStatus.watching && totalEps != null) ...[
                  _EpisodeTracker(
                    current: _episodeProgress,
                    total: totalEps,
                    onChanged: _updateProgress,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── User Rating display ──
                if (_userRating != null) ...[
                  _UserRatingCard(
                    rating: _userRating!,
                    review: _userReview,
                    onEdit: _openRatingSheet,
                  ),
                  const SizedBox(height: 20),
                ],

                // Synopsis
                if (anime.synopsis != null) ...[
                  Text('Synopsis',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _ExpandableSynopsis(text: anime.synopsis!),
                  const SizedBox(height: 24),
                ],

                // ── Action buttons ──
                // Main status button
                SizedBox(
                  width: double.infinity, height: 54,
                  child: inList
                      ? _StatusButton(
                    status: _watchStatus!,
                    color: _statusColor(colorScheme),
                    onTap: _openStatusSheet,
                  )
                      : FilledButton.icon(
                    onPressed: _openStatusSheet,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add to my list',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Rate button
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _openRatingSheet,
                    icon: Icon(
                      _userRating != null
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                    ),
                    label: Text(
                      _userRating != null
                          ? 'Your rating: ${_userRating!.toStringAsFixed(1)} — Edit'
                          : 'Rate this anime',
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Similar anime ──
                if (_similar.isNotEmpty) ...[
                  Text('You might also like',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _similar.length,
                      itemBuilder: (_, i) {
                        final s = _similar[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailScreen(malId: s.malId)),
                          ),
                          child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: s.imageUrl,
                                      fit: BoxFit.cover,
                                      width: 110,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(s.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Episode Progress Tracker ──────────────────────────────────────────────────

class _EpisodeTracker extends StatelessWidget {
  final int current;
  final int total;
  final ValueChanged<int> onChanged;
  const _EpisodeTracker({required this.current, required this.total, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : current / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('▶️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              const Text('Episode progress',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$current / $total',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4CAF50))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Decrement
              IconButton(
                onPressed: current > 0 ? () => onChanged(current - 1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: const Color(0xFF4CAF50),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF4CAF50),
                    thumbColor: const Color(0xFF4CAF50),
                    overlayColor: const Color(0xFF4CAF50).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: current.toDouble(),
                    min: 0,
                    max: total.toDouble(),
                    divisions: total,
                    label: 'Ep $current',
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ),
              // Increment
              IconButton(
                onPressed: current < total ? () => onChanged(current + 1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: const Color(0xFF4CAF50),
              ),
            ],
          ),
          if (current == total)
            const Center(
              child: Text('🎉 Finished! Great watch!',
                  style: TextStyle(
                      color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── User Rating Card ──────────────────────────────────────────────────────────

class _UserRatingCard extends StatelessWidget {
  final double rating;
  final String? review;
  final VoidCallback onEdit;
  const _UserRatingCard({required this.rating, this.review, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text('Your rating',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.amber)),
              const Text(' / 10',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
              ),
            ],
          ),
          if (review != null && review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review!,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ── Status Button ─────────────────────────────────────────────────────────────

class _StatusButton extends StatelessWidget {
  final WatchStatus status;
  final Color color;
  final VoidCallback onTap;
  const _StatusButton({required this.status, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(status.label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 8),
            Icon(Icons.expand_more_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Anime anime;
  const _StatsRow({required this.anime});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (anime.score != null) ...[
          _StatChip(icon: Icons.star_rounded,
              iconColor: const Color(0xFFFFD700), label: anime.scoreText),
          const SizedBox(width: 10),
        ],
        _StatChip(icon: Icons.play_circle_outline_rounded, label: anime.episodeText),
        const SizedBox(width: 10),
        _StatChip(
          icon: anime.isCompleted
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_checked_rounded,
          iconColor: anime.isCompleted ? Colors.green : colorScheme.primary,
          label: anime.status ?? 'Unknown',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  const _StatChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Expandable Synopsis ───────────────────────────────────────────────────────

class _ExpandableSynopsis extends StatefulWidget {
  final String text;
  const _ExpandableSynopsis({required this.text});

  @override
  State<_ExpandableSynopsis> createState() => _ExpandableSynopsisState();
}

class _ExpandableSynopsisState extends State<_ExpandableSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            firstChild: Text(widget.text,
                maxLines: 4, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant, height: 1.6)),
            secondChild: Text(widget.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant, height: 1.6)),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: 4),
          Text(_expanded ? 'Show less' : 'Read more',
              style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}