import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'detail_screen.dart';
import 'login_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebase = FirebaseService();
  late TabController _tabController;

  static const _tabs = [
    _TabConfig(label: 'All',           status: null,                      emoji: '📚'),
    _TabConfig(label: 'Watching',      status: WatchStatus.watching,      emoji: '▶️'),
    _TabConfig(label: 'Completed',     status: WatchStatus.completed,     emoji: '✅'),
    _TabConfig(label: 'Plan to Watch', status: WatchStatus.planToWatch,   emoji: '📋'),
    _TabConfig(label: 'On Hold',       status: WatchStatus.onHold,        emoji: '⏸️'),
    _TabConfig(label: 'Dropped',       status: WatchStatus.dropped,       emoji: '🗑️'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final isLoggedIn = authSnap.data != null;

        if (!isLoggedIn) {
          return _NotLoggedIn();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Watchlist'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Log out',
                onPressed: () => _firebase.signOut(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: _tabs
                  .map((t) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ],
                ),
              ))
                  .toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: _tabs
                .map((t) => _WatchlistTab(
              firebase: _firebase,
              statusFilter: t.status,
            ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _TabConfig {
  final String label;
  final WatchStatus? status;
  final String emoji;
  const _TabConfig({required this.label, required this.status, required this.emoji});
}

class _WatchlistTab extends StatelessWidget {
  final FirebaseService firebase;
  final WatchStatus? statusFilter;
  const _WatchlistTab({required this.firebase, this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firebase.watchlistStream(filter: statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _EmptyTab(statusFilter: statusFilter);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.60,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _WatchlistCard(item: items[i]),
        );
      },
    );
  }
}

class _WatchlistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _WatchlistCard({required this.item});

  Color _statusColor(WatchStatus s) {
    switch (s) {
      case WatchStatus.watching:    return const Color(0xFF4CAF50);
      case WatchStatus.completed:   return const Color(0xFF9C27B0);
      case WatchStatus.onHold:      return const Color(0xFFFF9800);
      case WatchStatus.dropped:     return const Color(0xFFF44336);
      case WatchStatus.planToWatch: return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final malId = item['malId'] as int;
    final status = WatchStatus.fromString(item['status'] as String?);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(malId: malId)),
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
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item['imageUrl'] as String? ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceVariant,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  // Status badge at bottom of image
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      color: _statusColor(status).withOpacity(0.92),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(status.emoji, style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              status.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String? ?? 'Unknown',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFD700)),
                      const SizedBox(width: 3),
                      Text('${item['score'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final WatchStatus? statusFilter;
  const _EmptyTab({this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(statusFilter?.emoji ?? '📚',
                style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              statusFilter == null
                  ? 'Your watchlist is empty'
                  : 'No anime marked as "${statusFilter!.label}"',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Browse anime and tap "Add to my list" to track them here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotLoggedIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔐', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Log in to track your anime',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Save anime with statuses like Watching, Completed, On Hold and more',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Log in / Sign up',
                      style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}