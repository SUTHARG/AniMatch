import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime.dart';           // ← was '../models/anime.dart'
import 'jikan_service.dart';   // ← was '../services/jikan_service.dart'
import 'firebase_service.dart';// ← was '../services/firebase_service.dart'

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
  bool _inWatchlist = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final anime = await _jikan.getAnimeDetail(widget.malId);
      final inWl = _firebase.isLoggedIn
          ? await _firebase.isInWatchlist(widget.malId)
          : false;
      if (mounted) {
        setState(() {
          _anime = anime;
          _inWatchlist = inWl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_anime == null) return;
    if (!_firebase.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to save to watchlist')),
      );
      return;
    }
    if (_inWatchlist) {
      await _firebase.removeFromWatchlist(_anime!.malId);
    } else {
      await _firebase.addToWatchlist(_anime!);
    }
    if (mounted) setState(() => _inWatchlist = !_inWatchlist);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _anime == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Failed to load')),
      );
    }

    final anime = _anime!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colorScheme.surface.withOpacity(0.9),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _inWatchlist
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _inWatchlist ? colorScheme.primary : null,
                ),
                onPressed: _toggleWatchlist,
                tooltip: _inWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title
                Text(
                  anime.displayTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (anime.titleEnglish != null &&
                    anime.titleEnglish != anime.title) ...[
                  const SizedBox(height: 4),
                  Text(
                    anime.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Stats row
                _StatsRow(anime: anime),
                const SizedBox(height: 16),

                // Genres
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: anime.genres
                      .map((g) => Chip(
                            label: Text(g,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSecondaryContainer)),
                            backgroundColor: colorScheme.secondaryContainer,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),

                // Synopsis
                if (anime.synopsis != null) ...[
                  Text('Synopsis',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _ExpandableSynopsis(text: anime.synopsis!),
                  const SizedBox(height: 24),
                ],

                // Add to watchlist button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _inWatchlist
                      ? OutlinedButton.icon(
                          onPressed: _toggleWatchlist,
                          icon: const Icon(Icons.bookmark_remove_rounded),
                          label: const Text('Remove from watchlist'),
                        )
                      : FilledButton.icon(
                          onPressed: _toggleWatchlist,
                          icon: const Icon(Icons.bookmark_add_rounded),
                          label: const Text('Add to watchlist'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Anime anime;
  const _StatsRow({required this.anime});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (anime.score != null) ...[
          _StatChip(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFFFD700),
            label: anime.scoreText,
          ),
          const SizedBox(width: 10),
        ],
        _StatChip(
          icon: Icons.play_circle_outline_rounded,
          label: anime.episodeText,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: anime.isCompleted
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_checked_rounded,
          iconColor: anime.isCompleted
              ? Colors.green
              : colorScheme.primary,
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

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
            firstChild: Text(
              widget.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
            ),
            secondChild: Text(
              widget.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? 'Show less' : 'Read more',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
