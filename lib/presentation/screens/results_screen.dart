import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/data/sources/remote/anilist_service.dart';
import 'package:animatch/presentation/screens/detail_screen.dart';
import 'package:animatch/presentation/screens/login_screen.dart';
import 'package:animatch/core/utils/snackbar_utils.dart' as snacks;
import 'package:animatch/core/utils/image_utils.dart'; // For PremiumImage

class ResultsScreen extends StatefulWidget {
  final List<MediaBase> media;
  final QuizAnswers quizAnswers;
  final bool isManga;

  const ResultsScreen({
    super.key,
    required this.media,
    required this.quizAnswers,
    this.isManga = false,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    _saveQuiz();
  }

  Future<void> _saveQuiz() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseService().saveQuizAnswers(uid, widget.quizAnswers);
    }
  }

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
      body: widget.media.isEmpty
          ? _EmptyState(mood: widget.quizAnswers.mood, isManga: widget.isManga)
          : Column(
              children: [
                // Summary chip row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _SummaryChips(answers: widget.quizAnswers),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.media.length} ${widget.isManga ? 'manga' : 'anime'} found',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.58,
                    ),
                    itemCount: widget.media.length,
                    itemBuilder: (_, i) => _MediaCard(
                        media: widget.media[i], isManga: widget.isManga),
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
    final rawChips = [
      answers.mood,
      ...answers.genres.take(2),
      if (answers.typeParam != null && answers.typeParam != 'any')
        answers.typeParam!,
      answers.episodeRange,
      answers.status,
    ];

    final chips = rawChips
        .where((c) => c != 'any')
        .map((c) => c[0].toUpperCase() + c.substring(1))
        .toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips
          .map((label) => Chip(
                label: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSecondaryContainer)),
                backgroundColor: colorScheme.secondaryContainer,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
          .toList(),
    );
  }
}

class _MediaCard extends StatefulWidget {
  final MediaBase media;
  final bool isManga;
  const _MediaCard({required this.media, required this.isManga});

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  final FirebaseService _firebase = FirebaseService();
  final AnilistService _anilist = AnilistService();
  bool _inList = false;
  String? _anilistImageUrl;
  bool _loadingAnilist = false;

  @override
  void initState() {
    super.initState();
    _checkInList();
    _loadAnilistImage();
  }

  Future<void> _loadAnilistImage() async {
    if (!mounted) return;
    setState(() => _loadingAnilist = true);

    String? url;
    if (widget.media.malId != null) {
      url = await _anilist
          .getCoverImageByMalId(widget.media.malId!, isManga: widget.isManga)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    }

    // Stage 2: Try by Title if ID fails
    if (url == null && mounted) {
      url = await _anilist
          .getCoverImageByTitle(widget.media.displayTitle,
              isManga: widget.isManga)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    }

    if (mounted) {
      setState(() {
        _anilistImageUrl = url;
        _loadingAnilist = false;
      });
    }
  }

  Future<void> _checkInList() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.media.malId == null) return;
    final result = await _firebase.isInWatchlist(uid, widget.media.malId!);
    if (mounted) setState(() => _inList = result);
  }

  Future<void> _toggleList() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      snacks.showError(
        context,
        'Log in to save this ${widget.isManga ? "manga" : "anime"}',
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

    if (widget.media.malId == null) {
      snacks.showError(context, 'Cannot save this item (No ID)');
      return;
    }

    final data = {
      'malId': widget.media.malId!,
      'title': widget.media.displayTitle,
      'imageUrl': widget.media.displayImageUrl,
      'score': widget.media.score,
    };

    if (_inList) {
      if (widget.isManga) {
        await _firebase.removeFromMangaWatchlist(uid, widget.media.malId!);
      } else {
        await _firebase.removeFromWatchlist(uid, widget.media.malId!);
      }
      if (mounted) snacks.showError(context, 'Removed from list');
    } else {
      if (widget.isManga) {
        await _firebase.addToMangaWatchlist(uid, data);
      } else {
        await _firebase.addToWatchlist(uid, data);
      }
      if (mounted) snacks.showSuccess(context, 'Saved to watchlist!');
    }
    if (mounted) setState(() => _inList = !_inList);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetailScreen(malId: widget.media.malId, isManga: widget.isManga),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                      color: colorScheme.surfaceContainerHighest,
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
                      imageUrl:
                          _anilistImageUrl ?? widget.media.displayImageUrl,
                      title: widget.media.displayTitle,
                      fit: BoxFit.cover,
                    ),
                  // Score badge
                  if (widget.media.score != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 12, color: Color(0xFFFFD700)),
                            const SizedBox(width: 3),
                            Text(
                              widget.media.scoreText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // List button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _toggleList,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _inList
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 16,
                          color: _inList ? colorScheme.primary : Colors.white,
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
                    widget.media.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.media.mediaTypeBadge.toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.media.mediaProgressText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (widget.media.genres.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.media.genres.take(2).join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 10,
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
  final bool isManga;
  const _EmptyState({required this.mood, required this.isManga});

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
              'No ${isManga ? "manga" : "anime"} found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try broadening your genre selection or changing the length preference.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
