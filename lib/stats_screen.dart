import 'package:flutter/material.dart';
import 'firebase_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final FirebaseService _firebase = FirebaseService();
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _firebase.getUserStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h < 24) return '${h}h ${m}m';
    final d = h ~/ 24;
    final rh = h % 24;
    return '${d}d ${rh}h';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stats'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats.isEmpty
          ? const Center(child: Text('No data yet — start tracking anime!'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero stat — total anime
            _HeroStat(
              value: '${_stats['totalAnime'] ?? 0}',
              label: 'Anime in your list',
              icon: '🎌',
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Row: episodes + time
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: '📺',
                    value: '${_stats['totalEpisodes'] ?? 0}',
                    label: 'Episodes watched',
                    color: const Color(0xFF00B4DB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: '⏱️',
                    value: _formatMinutes(
                        _stats['minutesWatched'] as int? ?? 0),
                    label: 'Time watched',
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row: avg rating + rated
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: '⭐',
                    value: (_stats['avgRating'] as double? ?? 0.0) == 0
                        ? 'N/A'
                        : (_stats['avgRating'] as double)
                        .toStringAsFixed(1),
                    label: 'Average rating',
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: '✍️',
                    value: '${_stats['ratingsGiven'] ?? 0}',
                    label: 'Ratings given',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status breakdown
            Text('Status breakdown',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            _StatusBar(
              label: 'Watching',
              emoji: '▶️',
              count: _stats['watching'] as int? ?? 0,
              total: _stats['totalAnime'] as int? ?? 1,
              color: const Color(0xFF4CAF50),
            ),
            _StatusBar(
              label: 'Completed',
              emoji: '✅',
              count: _stats['completed'] as int? ?? 0,
              total: _stats['totalAnime'] as int? ?? 1,
              color: const Color(0xFF9C27B0),
            ),
            _StatusBar(
              label: 'Plan to Watch',
              emoji: '📋',
              count: _stats['planToWatch'] as int? ?? 0,
              total: _stats['totalAnime'] as int? ?? 1,
              color: const Color(0xFF2196F3),
            ),
            _StatusBar(
              label: 'On Hold',
              emoji: '⏸️',
              count: _stats['onHold'] as int? ?? 0,
              total: _stats['totalAnime'] as int? ?? 1,
              color: const Color(0xFFFF9800),
            ),
            _StatusBar(
              label: 'Dropped',
              emoji: '🗑️',
              count: _stats['dropped'] as int? ?? 0,
              total: _stats['totalAnime'] as int? ?? 1,
              color: const Color(0xFFF44336),
            ),
            const SizedBox(height: 24),

            // Top genres
            if ((_stats['topGenres'] as List?)?.isNotEmpty == true) ...[
              Text('Your top genres',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: (_stats['topGenres'] as List<dynamic>)
                    .asMap()
                    .entries
                    .map((e) {
                  final medals = ['🥇', '🥈', '🥉'];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${medals[e.key]} ${e.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;
  const _HeroStat({
    required this.value, required this.label,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      color: color.withOpacity(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon, required this.value,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final String emoji;
  final int count;
  final int total;
  final Color color;
  const _StatusBar({
    required this.label, required this.emoji,
    required this.count, required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor:
              Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}