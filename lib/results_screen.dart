import 'package:flutter/material.dart';
import 'package:untitled1/anilist_service.dart';
import 'anime.dart';
import 'firebase_service.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'floating_notification.dart';
import 'image_utils.dart';

class ResultsScreen extends StatelessWidget {
  final List<Anime> anime;
  final QuizAnswers quizAnswers;

  const ResultsScreen({
    super.key,
    required this.anime,
    required this.quizAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Your Recommendations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Redo quiz'),
          ),
        ],
      ),
      body: anime.isEmpty
          ? _EmptyState(mood: quizAnswers.mood)
          : Column(
              children: [
                // Summary chip row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _SummaryChips(answers: quizAnswers),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${anime.length} anime found',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.58,
                    ),
                    itemCount: anime.length,
                    itemBuilder: (_, i) => _AnimeCard(anime: anime[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final QuizAnswers answers;
  const _SummaryChips({required this.answers});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = [
      answers.mood,
      ...answers.genres.take(2),
      answers.episodeRange,
      answers.status,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map((label) => Chip(
                label: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSecondaryContainer)),
                backgroundColor: colorScheme.secondaryContainer,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
          .toList(),
    );
  }
}

class _AnimeCard extends StatefulWidget {
  final Anime anime;
  const _AnimeCard({required this.anime});

  @override
  State<_AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<_AnimeCard> {
  final FirebaseService _firebase = FirebaseService();
  final AnilistService _anilist = AnilistService();
  bool _inWatchlist = false;
  String? _anilistImageUrl;
  bool _loadingAnilist = false;

  @override
  void initState() {
    super.initState();
    _checkWatchlist();
    _loadAnilistImage();
  }

  Future<void> _loadAnilistImage() async {
    if (!mounted) return;
    setState(() => _loadingAnilist = true);
    
    // Stage 1: Try by MAL ID
    String? url = await _anilist.getCoverImageByMalId(widget.anime.malId);
    
    // Stage 2: Try by Title if ID fails
    if (url == null && mounted) {
      url = await _anilist.getCoverImageByTitle(widget.anime.displayTitle);
    }

    if (mounted) {
      setState(() {
        _anilistImageUrl = url;
        _loadingAnilist = false;
      });
    }
  }

  Future<void> _checkWatchlist() async {
    if (!_firebase.isLoggedIn) return;
    final result = await _firebase.isInWatchlist(widget.anime.malId);
    if (mounted) setState(() => _inWatchlist = result);
  }

  Future<void> _toggleWatchlist() async {
    if (!_firebase.isLoggedIn) {
      FloatingNotification.show(
        context,
        title: 'Authentication Required',
        message: 'Log in to save this anime to your watchlist',
        icon: Icons.lock_outline_rounded,
        actionLabel: 'Login',
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      );
      return;
    }
    if (_inWatchlist) {
      await _firebase.removeFromWatchlist(widget.anime.malId);
    } else {
      await _firebase.addToWatchlist(widget.anime);
    }
    if (mounted) setState(() => _inWatchlist = !_inWatchlist);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailScreen(malId: widget.anime.malId),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_loadingAnilist && _anilistImageUrl == null)
                    Container(
                      color: colorScheme.surfaceVariant,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    PremiumImage(
                      imageUrl: _anilistImageUrl ?? widget.anime.displayImageUrl,
                      title: widget.anime.displayTitle,
                      fit: BoxFit.cover,
                    ),
                  // Score badge
                  if (widget.anime.score != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: Color(0xFFFFD700)),
                            const SizedBox(width: 3),
                            Text(
                              widget.anime.scoreText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Watchlist button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _toggleWatchlist,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _inWatchlist
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 16,
                          color: _inWatchlist
                              ? colorScheme.primary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.anime.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.anime.episodeText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.anime.genres.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.anime.genres.take(2).join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String mood;
  const _EmptyState({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😔', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No anime found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try broadening your genre selection or changing the episode range.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => FloatingNotification.show(
                context,
                title: 'Action Shared',
                message: 'This feature is coming soon!',
                icon: Icons.celebration_rounded,
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
