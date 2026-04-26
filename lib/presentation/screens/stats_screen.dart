import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/core/utils/image_utils.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final FirebaseService _firebase = FirebaseService();
  int _selectedMode = 0; // 0: Anime, 1: Manga

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _selectedMode == 0
          ? _firebase.getUserStatsStream()
          : _firebase.getUserMangaStatsStream(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Background Atmosphere
              Positioned.fill(
                child: ImageUtils.safeBackground(
                  'assets/images/login_bg.png',
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: const Text('My Stats',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(
                                  value: 0,
                                  label: Text('Anime'),
                                  icon: Icon(Icons.movie_filter_rounded)),
                              ButtonSegment(
                                  value: 1,
                                  label: Text('Manga'),
                                  icon: Icon(Icons.book_rounded)),
                            ],
                            selected: {_selectedMode},
                            onSelectionChanged: (set) =>
                                setState(() => _selectedMode = set.first),
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              selectedBackgroundColor: Colors.amber,
                              selectedForegroundColor: Colors.black,
                              foregroundColor: Colors.white70,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: loading && stats.isEmpty
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(50),
                                  child: CircularProgressIndicator(
                                      color: Colors.amber)))
                          : stats.isEmpty
                              ? Center(
                                  child: Padding(
                                      padding: const EdgeInsets.all(50),
                                      child: Text(
                                          'No data yet — start tracking ${_selectedMode == 0 ? "anime" : "manga"}!',
                                          style: const TextStyle(
                                              color: Colors.white70))))
                              : Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Hero stat — total
                                      _GlassHeroStat(
                                        value:
                                            '${_selectedMode == 0 ? stats['totalAnime'] : stats['totalManga'] ?? 0}',
                                        label:
                                            '${_selectedMode == 0 ? "Anime" : "Manga"} in your list',
                                        icon: _selectedMode == 0
                                            ? Icons.collections_bookmark_rounded
                                            : Icons.auto_stories_rounded,
                                        color: _selectedMode == 0
                                            ? Colors.amber
                                            : Colors.blueAccent,
                                      ),
                                      const SizedBox(height: 16),

                                      // Grid layout for smaller stats
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _GlassStatCard(
                                              icon: _selectedMode == 0
                                                  ? Icons.personal_video_rounded
                                                  : Icons.menu_book_rounded,
                                              value:
                                                  '${_selectedMode == 0 ? stats['totalEpisodes'] : stats['totalChapters'] ?? 0}',
                                              label: _selectedMode == 0
                                                  ? 'Episodes'
                                                  : 'Chapters',
                                              color: const Color(0xFF00B4DB),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _GlassStatCard(
                                              icon: Icons.history_rounded,
                                              value: _selectedMode == 0
                                                  ? _formatMinutes(
                                                      stats['minutesWatched']
                                                              as int? ??
                                                          0)
                                                  : '${stats['totalVolumes'] ?? 0} volumes',
                                              label: _selectedMode == 0
                                                  ? 'Time watched'
                                                  : 'Volumes read',
                                              color: const Color(0xFF6C5CE7),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: _GlassStatCard(
                                              icon: Icons.star_rounded,
                                              value: (stats['avgRating']
                                                              as double? ??
                                                          0.0) ==
                                                      0
                                                  ? 'N/A'
                                                  : (stats['avgRating']
                                                          as double)
                                                      .toStringAsFixed(1),
                                              label: 'Avg Rating',
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _GlassStatCard(
                                              icon: Icons.edit_note_rounded,
                                              value:
                                                  '${stats['ratingsGiven'] ?? 0}',
                                              label: 'Reviews',
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),

                                      // Status breakdown
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Status breakdown',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white)),
                                            const SizedBox(height: 20),
                                            _GlassStatusBar(
                                              label: _selectedMode == 0
                                                  ? 'Watching'
                                                  : 'Reading',
                                              count: (_selectedMode == 0
                                                          ? stats['watching']
                                                          : stats['reading'])
                                                      as int? ??
                                                  0,
                                              total: (_selectedMode == 0
                                                          ? stats['totalAnime']
                                                          : stats['totalManga'])
                                                      as int? ??
                                                  1,
                                              color: const Color(0xFF4CAF50),
                                            ),
                                            _GlassStatusBar(
                                              label: 'Completed',
                                              count:
                                                  stats['completed'] as int? ??
                                                      0,
                                              total: (_selectedMode == 0
                                                          ? stats['totalAnime']
                                                          : stats['totalManga'])
                                                      as int? ??
                                                  1,
                                              color: const Color(0xFF9C27B0),
                                            ),
                                            _GlassStatusBar(
                                              label: _selectedMode == 0
                                                  ? 'Plan to Watch'
                                                  : 'Plan to Read',
                                              count: (_selectedMode == 0
                                                          ? stats['planToWatch']
                                                          : stats['planToRead'])
                                                      as int? ??
                                                  0,
                                              total: (_selectedMode == 0
                                                          ? stats['totalAnime']
                                                          : stats['totalManga'])
                                                      as int? ??
                                                  1,
                                              color: const Color(0xFF2196F3),
                                            ),
                                            _GlassStatusBar(
                                              label: 'On Hold',
                                              count:
                                                  stats['onHold'] as int? ?? 0,
                                              total: (_selectedMode == 0
                                                          ? stats['totalAnime']
                                                          : stats['totalManga'])
                                                      as int? ??
                                                  1,
                                              color: const Color(0xFFFF9800),
                                            ),
                                            _GlassStatusBar(
                                              label: 'Dropped',
                                              count:
                                                  stats['dropped'] as int? ?? 0,
                                              total: (_selectedMode == 0
                                                          ? stats['totalAnime']
                                                          : stats['totalManga'])
                                                      as int? ??
                                                  1,
                                              color: const Color(0xFFF44336),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 32),

                                      // Top genres
                                      if ((stats['topGenres'] as List?)
                                              ?.isNotEmpty ==
                                          true) ...[
                                        Text('Top Genres',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white70)),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: (stats['topGenres']
                                                  as List<dynamic>)
                                              .asMap()
                                              .entries
                                              .map((e) {
                                            final colors = [
                                              Colors.amber,
                                              Colors.blueGrey.shade300,
                                              Colors.brown.shade300,
                                            ];
                                            final iconColor =
                                                e.key < colors.length
                                                    ? colors[e.key]
                                                    : Colors.white24;
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                    sigmaX: 5, sigmaY: 5),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.05),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: iconColor
                                                            .withValues(
                                                                alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.stars_rounded,
                                                          size: 14,
                                                          color: iconColor),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${e.value}',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 40),
                                      ],
                                    ],
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassHeroStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _GlassHeroStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1)),
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _GlassStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 16),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassStatusBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _GlassStatusBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white70)),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: color, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.05),
              child: Stack(
                children: [
                  AnimatedFractionallySizedBox(
                    duration: const Duration(seconds: 1),
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.6), color],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
