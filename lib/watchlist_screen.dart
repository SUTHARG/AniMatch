import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'detail_screen.dart';
import 'login_screen.dart';
import 'image_utils.dart';
import 'shimmer_skeletons.dart';

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
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('My Watchlist', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                tooltip: 'Log out',
                onPressed: () => _firebase.signOut(),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.amber,
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: _tabs
                      .map((t) => Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(t.label),
                        ],
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ),
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
          return const WatchlistShimmer();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _EmptyTab(statusFilter: statusFilter);

        return RefreshIndicator(
          onRefresh: () async {
            // Re-trigger the stream by forcing a rebuild or just waiting
            await Future.delayed(const Duration(seconds: 1));
          },
          color: Colors.amber,
          backgroundColor: Colors.black,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _WatchlistCard(item: items[i]),
          ),
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

    final imageUrl = item['imageUrl'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(malId: malId)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster Image
            PremiumImage(
              imageUrl: imageUrl,
              title: item['title'] as String? ?? 'Anime',
              fit: BoxFit.cover,
            ),
            
            // Premium Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.6, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // Top Status Pill
            Positioned(
              top: 10,
              right: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(status.emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          status.label.split(' ').first, // Shorter label
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Rating Pill
            Positioned(
              top: 10,
              left: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${item['score'] ?? 'N/A'}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Title
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String? ?? 'Unknown',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                    ),
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
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.3,
            child: Image.asset(
              ImageUtils.resolveAsset('assets/images/login_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(statusFilter?.emoji ?? '📚', style: const TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 32),
                Text(
                  statusFilter == null ? 'Your journey is waiting' : 'No anime found here',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  statusFilter == null
                      ? 'Start exploring worlds and track your favorite anime right here.'
                      : 'You haven\'t marked any anime as "${statusFilter!.label}" yet.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotLoggedIn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Glow Icon
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 40, spreadRadius: 5),
                      ],
                    ),
                    child: const Icon(Icons.bookmark_outline_rounded, size: 80, color: Colors.amber),
                  ),
                  const SizedBox(height: 48),
                  
                  const Text(
                    'Your Library Awaits',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Login to sync your watchlist across all devices and never lose track of your progress.',
                    style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      icon: const Icon(Icons.login_rounded, weight: 700),
                      label: const Text('JOIN THE WORLD OF ANIME', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Small header for consistency
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: const Text('Watchlist', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}