import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/presentation/screens/detail_screen.dart';
import 'package:animatch/presentation/screens/login_screen.dart';
import 'package:animatch/core/utils/image_utils.dart';
import 'package:animatch/core/app_state.dart';
import 'package:animatch/presentation/widgets/shimmer_loader.dart';
import 'package:animatch/presentation/providers/watchlist_provider.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  AppMode _viewMode = AppMode.anime;

  static const _animeTabs = [
    _TabConfig(label: 'All', watchStatus: null, emoji: '📚'),
    _TabConfig(
        label: 'Watching', watchStatus: WatchStatus.watching, emoji: '▶️'),
    _TabConfig(
        label: 'Completed', watchStatus: WatchStatus.completed, emoji: '✅'),
    _TabConfig(
        label: 'Plan to Watch',
        watchStatus: WatchStatus.planToWatch,
        emoji: '📋'),
    _TabConfig(label: 'On Hold', watchStatus: WatchStatus.onHold, emoji: '⏸️'),
    _TabConfig(
        label: 'Dropped', watchStatus: WatchStatus.dropped, emoji: '🗑️'),
  ];

  static const _mangaTabs = [
    _TabConfig(label: 'All', readStatus: null, emoji: '📚'),
    _TabConfig(label: 'Reading', readStatus: ReadStatus.reading, emoji: '📖'),
    _TabConfig(
        label: 'Completed', readStatus: ReadStatus.completed, emoji: '✅'),
    _TabConfig(
        label: 'Plan to Read', readStatus: ReadStatus.planToRead, emoji: '📋'),
    _TabConfig(label: 'On Hold', readStatus: ReadStatus.onHold, emoji: '⏸️'),
    _TabConfig(label: 'Dropped', readStatus: ReadStatus.dropped, emoji: '🗑️'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _animeTabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync view mode with global app state on entry or state change
    setState(() {
      _viewMode = appState.mode;
    });
  }

  void _setViewMode(AppMode mode) {
    if (_viewMode == mode) return;
    setState(() {
      _viewMode = mode;
      _tabController.index = 0; // Reset to "All" when switching modes
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).maybeWhen(
          data: (user) => user,
          orElse: () => FirebaseAuth.instance.currentUser,
        );
    if (user == null) {
      return _NotLoggedIn();
    }

    final tabs = _viewMode == AppMode.manga ? _mangaTabs : _animeTabs;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('My Library',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Log out',
            onPressed: () => ref.read(watchlistActionsProvider).signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Anime/Manga Switcher
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _setViewMode(AppMode.anime),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _viewMode == AppMode.anime
                                  ? Colors.amber
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text('ANIME',
                                style: TextStyle(
                                    color: _viewMode == AppMode.anime
                                        ? Colors.black
                                        : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _setViewMode(AppMode.manga),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _viewMode == AppMode.manga
                                  ? Colors.amber
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text('MANGA',
                                style: TextStyle(
                                    color: _viewMode == AppMode.manga
                                        ? Colors.black
                                        : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Sub-tabs (Watching, Reading, etc)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
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
                    color: Colors.amber.withValues(alpha: 0.2),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  labelColor: Colors.amber,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: tabs
                      .map((t) => Tab(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t.emoji,
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 8),
                                  Text(t.label),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        key: ValueKey(_viewMode), // Force rebuild when switching Anime/Manga
        children: tabs
            .map((t) => _WatchlistTab(
                  uid: user.uid,
                  isManga: _viewMode == AppMode.manga,
                  watchStatus: t.watchStatus,
                  readStatus: t.readStatus,
                ))
            .toList(),
      ),
    );
  }
}

class _TabConfig {
  final String label;
  final WatchStatus? watchStatus;
  final ReadStatus? readStatus;
  final String emoji;
  const _TabConfig(
      {required this.label,
      this.watchStatus,
      this.readStatus,
      required this.emoji});
}

class _WatchlistTab extends ConsumerWidget {
  final String uid;
  final bool isManga;
  final WatchStatus? watchStatus;
  final ReadStatus? readStatus;
  const _WatchlistTab(
      {required this.uid,
      required this.isManga,
      this.watchStatus,
      this.readStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(watchlistProvider(WatchlistFilter(
      uid: uid,
      isManga: isManga,
      watchStatus: watchStatus,
      readStatus: readStatus,
    )));

    return itemsAsync.when(
      loading: () => const WatchlistShimmer(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyTab(
              isManga: isManga,
              watchStatus: watchStatus,
              readStatus: readStatus);
        }

        // Auto-Patch missing data logic
        _triggerAutoPatch(uid, items, isManga, ref);

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
          },
          color: Colors.amber,
          backgroundColor: Colors.black,
          child: GridView.builder(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _WatchlistCard(item: items[i], isManga: isManga),
          ),
        );
      },
    );
  }

  // Set to track IDs currently being patched in this session
  static final Set<int> _patchingIds = {};

  void _triggerAutoPatch(String uid, List<Map<String, dynamic>> items,
      bool isManga, WidgetRef ref) {
    if (uid.isEmpty) return;

    for (var item in items) {
      final malId = item['malId'] as int?;
      if (malId == null) continue;

      bool needsPatch = false;
      if (isManga) {
        needsPatch = (item['chapters'] == null || item['chapters'] == 0);
      } else {
        needsPatch = (item['episodes'] == null || item['episodes'] == 0);
      }

      if (needsPatch && !_patchingIds.contains(malId)) {
        _patchingIds.add(malId);
        _performPatch(uid, malId, isManga, ref);
      }
    }
  }

  Future<void> _performPatch(
      String uid, int malId, bool isManga, WidgetRef ref) async {
    try {
      await ref.read(watchlistActionsProvider).updateMissingTotals(
            uid: uid,
            malId: malId,
            isManga: isManga,
          );
    } catch (e) {
      debugPrint('Auto-patch failed for ID $malId: $e');
    } finally {
      // Keep in patching set for a while to avoid rapid retries on failure
    }
  }
}

class _WatchlistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isManga;
  const _WatchlistCard({required this.item, required this.isManga});

  Color _statusColor(dynamic s) {
    if (s is WatchStatus) {
      switch (s) {
        case WatchStatus.watching:
          return const Color(0xFF4CAF50);
        case WatchStatus.completed:
          return const Color(0xFF9C27B0);
        case WatchStatus.onHold:
          return const Color(0xFFFF9800);
        case WatchStatus.dropped:
          return const Color(0xFFF44336);
        case WatchStatus.planToWatch:
          return const Color(0xFF2196F3);
      }
    } else if (s is ReadStatus) {
      switch (s) {
        case ReadStatus.reading:
          return const Color(0xFF4CAF50);
        case ReadStatus.completed:
          return const Color(0xFF9C27B0);
        case ReadStatus.onHold:
          return const Color(0xFFFF9800);
        case ReadStatus.dropped:
          return const Color(0xFFF44336);
        case ReadStatus.planToRead:
          return const Color(0xFF2196F3);
      }
    }
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final malId = item['malId'] as int;
    final dynamic status = isManga
        ? ReadStatus.fromString(item['status'] as String?)
        : WatchStatus.fromString(item['status'] as String?);

    final imageUrl = item['imageUrl'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DetailScreen(malId: malId, isManga: isManga)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
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
                      Colors.black.withValues(alpha: 0.9),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(status.emoji,
                            style: const TextStyle(fontSize: 12)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${item['score'] ?? 'N/A'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
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
                      shadows: [
                        Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isManga
                        ? '${item['chapterProgress'] ?? 0} / ${item['chapters'] ?? '?'} chps'
                        : '${item['episodeProgress'] ?? 0} / ${item['episodes'] ?? '?'} eps',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
  final bool isManga;
  final WatchStatus? watchStatus;
  final ReadStatus? readStatus;
  const _EmptyTab({required this.isManga, this.watchStatus, this.readStatus});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.3,
            child: ImageUtils.safeBackground(
              'assets/images/login_bg.png',
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
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                      isManga
                          ? (readStatus?.emoji ?? '📚')
                          : (watchStatus?.emoji ?? '📚'),
                      style: const TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 32),
                Text(
                  (!isManga && watchStatus == null) ||
                          (isManga && readStatus == null)
                      ? 'Your journey is waiting'
                      : 'No ${isManga ? "manga" : "anime"} found here',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  (!isManga && watchStatus == null) ||
                          (isManga && readStatus == null)
                      ? 'Start exploring worlds and track your favorite ${isManga ? "manga" : "anime"} right here.'
                      : 'You haven\'t marked any ${isManga ? "manga" : "anime"} as "${isManga ? readStatus!.label : watchStatus!.label}" yet.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      height: 1.6),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ImageUtils.safeBackground(
              'assets/images/login_bg.png',
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
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.9),
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
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5),
                      ],
                    ),
                    child: Icon(Icons.bookmark_outline_rounded,
                        size: 80, color: Colors.amber),
                  ),
                  const SizedBox(height: 48),

                  const Text(
                    'Your Library Awaits',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Login to sync your watchlist across all devices and never lose track of your progress.',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.6),
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
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('JOIN THE WORLD OF ANIME',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
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
            child: Text('Watchlist',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
