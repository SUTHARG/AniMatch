import 'dart:ui';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'image_utils.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final FirebaseService _firebase = FirebaseService();

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _firebase.getUserStatsStream(),
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
                child: Image.asset(
                  ImageUtils.resolveAsset('assets/images/login_bg.png'),
                  fit: BoxFit.cover,
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
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.8),
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
                      title: const Text('My Stats', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    
                    SliverToBoxAdapter(
                      child: loading && stats.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator(color: Colors.amber)))
                          : stats.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(50), child: Text('No data yet — start tracking anime!', style: TextStyle(color: Colors.white70))))
                          : Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hero stat — total anime
                                  _GlassHeroStat(
                                    value: '${stats['totalAnime'] ?? 0}',
                                    label: 'Anime in your list',
                                    icon: Icons.collections_bookmark_rounded,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(height: 16),

                                  // Grid layout for smaller stats
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _GlassStatCard(
                                          icon: Icons.personal_video_rounded,
                                          value: '${stats['totalEpisodes'] ?? 0}',
                                          label: 'Episodes',
                                          color: const Color(0xFF00B4DB),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _GlassStatCard(
                                          icon: Icons.history_rounded,
                                          value: _formatMinutes(stats['minutesWatched'] as int? ?? 0),
                                          label: 'Time watched',
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
                                          value: (stats['avgRating'] as double? ?? 0.0) == 0
                                              ? 'N/A'
                                              : (stats['avgRating'] as double).toStringAsFixed(1),
                                          label: 'Avg Rating',
                                          color: Colors.amber,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _GlassStatCard(
                                          icon: Icons.edit_note_rounded,
                                          value: '${stats['ratingsGiven'] ?? 0}',
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
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Status breakdown',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                                        const SizedBox(height: 20),
                                        _GlassStatusBar(
                                          label: 'Watching',
                                          count: stats['watching'] as int? ?? 0,
                                          total: stats['totalAnime'] as int? ?? 1,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                        _GlassStatusBar(
                                          label: 'Completed',
                                          count: stats['completed'] as int? ?? 0,
                                          total: stats['totalAnime'] as int? ?? 1,
                                          color: const Color(0xFF9C27B0),
                                        ),
                                        _GlassStatusBar(
                                          label: 'Plan to Watch',
                                          count: stats['planToWatch'] as int? ?? 0,
                                          total: stats['totalAnime'] as int? ?? 1,
                                          color: const Color(0xFF2196F3),
                                        ),
                                        _GlassStatusBar(
                                          label: 'On Hold',
                                          count: stats['onHold'] as int? ?? 0,
                                          total: stats['totalAnime'] as int? ?? 1,
                                          color: const Color(0xFFFF9800),
                                        ),
                                        _GlassStatusBar(
                                          label: 'Dropped',
                                          count: stats['dropped'] as int? ?? 0,
                                          total: stats['totalAnime'] as int? ?? 1,
                                          color: const Color(0xFFF44336),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),

                                  // Top genres
                                  if ((stats['topGenres'] as List?)?.isNotEmpty == true) ...[
                                    Text('Top Genres',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white70)),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: (stats['topGenres'] as List<dynamic>)
                                          .asMap()
                                          .entries
                                          .map((e) {
                                        final colors = [
                                          Colors.amber,
                                          Colors.blueGrey.shade300,
                                          Colors.brown.shade300,
                                        ];
                                        final iconColor = e.key < colors.length ? colors[e.key] : Colors.white24;
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: iconColor.withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.stars_rounded, size: 14, color: iconColor),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${e.value}',
                                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
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
    required this.value, required this.label,
    required this.icon, required this.color,
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
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                            color: Colors.white.withOpacity(0.5))),
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
    required this.icon, required this.value,
    required this.label, required this.color,
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
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      color: Colors.white.withOpacity(0.4))),
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
    required this.label, required this.count, required this.total,
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
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
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
              color: Colors.white.withOpacity(0.05),
              child: Stack(
                children: [
                  AnimatedFractionallySizedBox(
                    duration: const Duration(seconds: 1),
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.6), color],
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