import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/anime.dart';
import '../providers/watchlist_provider.dart';
import '../screens/watch_screen.dart';

class WatchButton extends ConsumerWidget {
  final Anime anime;
  final bool compact;
  const WatchButton({super.key, required this.anime, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(watchlistActionsProvider);
    final uid = actions.currentUserId ?? '';
    final resumeEp = ref.watch(watchlistProvider(WatchlistFilter(uid: uid, isManga: false))).maybeWhen(
          data: (items) {
            final match = items.where(
                (i) => i['malId'] == anime.malId).firstOrNull;
            final prog = match?['episodeProgress'] as int? ?? 0;
            return prog > 0 ? prog : 1;
          },
          orElse: () => 1,
        );

    void openWatch() {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WatchScreen(anime: anime, initialEpisode: resumeEp),
      ));
    }

    if (compact) {
      return FloatingActionButton.extended(
        onPressed: openWatch,
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: Text(
          resumeEp > 1 ? 'Resume Ep $resumeEp' : 'Watch Now',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: openWatch,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
        label: Text(
          resumeEp > 1 ? 'Resume — Episode $resumeEp' : 'Watch Now',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
        ),
      ),
    );
  }
}
