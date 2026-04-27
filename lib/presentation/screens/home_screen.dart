import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animatch/core/app_state.dart';
import 'package:animatch/data/models/manga.dart';
import 'package:animatch/data/models/anime.dart';
import 'package:animatch/data/sources/remote/anilist_service.dart';
import 'package:animatch/data/sources/remote/jikan_service.dart';
import 'package:animatch/presentation/screens/quiz_screen.dart';
import 'package:animatch/presentation/screens/detail_screen.dart';
import 'package:animatch/presentation/widgets/floating_notification.dart';
import 'package:animatch/presentation/screens/search_screen.dart';
import 'package:animatch/presentation/screens/watchlist_screen.dart';
import 'package:animatch/presentation/screens/profile_screen.dart';
import 'package:animatch/core/utils/image_utils.dart';
import 'package:animatch/presentation/widgets/shimmer_loader.dart';
import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/presentation/screens/browse_magazines_screen.dart';
import 'package:animatch/presentation/widgets/pinterest_interaction.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/presentation/widgets/watch_status_sheet.dart';
import 'package:animatch/presentation/providers/anime_provider.dart';
import 'package:animatch/presentation/providers/recommendation_provider.dart';
import 'package:animatch/presentation/providers/watchlist_provider.dart';
import 'package:animatch/data/models/hero_recommendation.dart';
import 'package:animatch/core/utils/snackbar_utils.dart' as snacks;

class HomeScreen extends StatefulWidget {
  final AppState appState;
  const HomeScreen({super.key, required this.appState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _HomeTab(appState: widget.appState),
              WatchlistScreen(),
            ],
          ),
          bottomNavigationBar: SafeArea(
            bottom: true,
            child: Container(
              height: 80, // Safe height for contents
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Floating Glass Pill
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _NotchedPillClipper(notchMargin: 8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.8),
                            // The border is handled by custom painter for the notch
                          ),
                        ),
                      ),
                    ),
                  ),

                  // The thin white border following the notch
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _NotchedPillBorderPainter(
                        notchMargin: 8,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),

                  // Content icons
                  BottomAppBar(
                    shape: const CircularNotchedRectangle(),
                    notchMargin: 8,
                    color:
                        Colors.transparent, // Transparent to show glass behind
                    elevation: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavBarIcon(
                          icon: _currentIndex == 0
                              ? Icons.home_rounded
                              : Icons.home_outlined,
                          isActive: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                          label: 'Home',
                        ),
                        const SizedBox(width: 48), // Space for FAB
                        _NavBarIcon(
                          icon: _currentIndex == 1
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          isActive: _currentIndex == 1,
                          onTap: () => setState(() => _currentIndex = 1),
                          label: 'Watchlist',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              backgroundColor: Colors.amber,
              shape: const CircleBorder(),
              elevation: 6,
              child: const Icon(Icons.search_rounded,
                  color: Colors.black, size: 28),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String label;

  const _NavBarIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 26,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchedPillClipper extends CustomClipper<Path> {
  final double notchMargin;
  _NotchedPillClipper({required this.notchMargin});

  @override
  Path getClip(Size size) {
    final path = Path();
    const radius = 24.0;
    const notchRadius = 38.0;
    final centerX = size.width / 2;

    // Start from top left corner
    path.moveTo(radius, 0);

    // Top line with notch
    path.lineTo(centerX - notchRadius, 0);
    path.arcToPoint(
      Offset(centerX + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width - radius, 0);

    // Top right corner
    path.arcToPoint(Offset(size.width, radius),
        radius: const Radius.circular(radius));

    // Right line
    path.lineTo(size.width, size.height - radius);

    // Bottom right corner
    path.arcToPoint(Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius));

    // Bottom line
    path.lineTo(radius, size.height);

    // Bottom left corner
    path.arcToPoint(Offset(0, size.height - radius),
        radius: const Radius.circular(radius));

    // Left line
    path.lineTo(0, radius);

    // Top left corner
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NotchedPillBorderPainter extends CustomPainter {
  final double notchMargin;
  final Color color;

  _NotchedPillBorderPainter({required this.notchMargin, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const radius = 24.0;
    const notchRadius = 38.0;
    final centerX = size.width / 2;

    final path = Path();
    path.moveTo(radius, 0);
    path.lineTo(centerX - notchRadius, 0);
    path.arcToPoint(
      Offset(centerX + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(Offset(size.width, radius),
        radius: const Radius.circular(radius));
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height),
        radius: const Radius.circular(radius));
    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius),
        radius: const Radius.circular(radius));
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeTab extends StatefulWidget {
  final AppState appState;
  const _HomeTab({required this.appState});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final JikanService _jikan = JikanService();
  final AnilistService _anilist = AnilistService();
  List<Anime> _spotlightAnime = [];
  List<Anime> _trendingAnime = [];
  List<Anime> _topUpcomingAnime = [];

  List<Manga> _spotlightManga = [];
  List<Manga> _trendingManga = [];
  List<Manga> _popularManhwa = [];
  List<Manga> _popularManhua = [];
  List<Manga> _popularNovels = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onModeChanged);
    _load();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if ((widget.appState.isAnimeMode && _spotlightAnime.isEmpty) ||
        (!widget.appState.isAnimeMode && _spotlightManga.isEmpty)) {
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      if (widget.appState.isAnimeMode) {
        final trendingData = await _anilist.getTrendingAnime();
        final seasonalData = await _anilist.getSeasonalAnime();
        final upcomingData = await _anilist.getTopUpcomingAnime();

        if (mounted) {
          setState(() {
            _spotlightAnime =
                seasonalData.take(10).map((e) => Anime.fromAniList(e)).toList();
            _trendingAnime =
                trendingData.take(10).map((e) => Anime.fromAniList(e)).toList();
            _topUpcomingAnime =
                upcomingData.map((e) => Anime.fromAniList(e)).toList();
            _loading = false;
          });
        }
      } else {
        // Load Manga Data (with rate-limiting awareness)
        final trendingMangaData = await _jikan.getTopManga(
            filter: 'publishing'); // Current top publishing
        final topMangaData = await _jikan.getTopManga(); // All-time top

        // Fetch specific categories
        final manhwaData = await _jikan.getTopManga(type: 'manhwa');
        final manhuaData = await _jikan.getTopManga(type: 'manhua');
        final novelData = await _jikan.getTopManga(type: 'lightnovel');

        if (mounted) {
          setState(() {
            _spotlightManga = trendingMangaData.take(10).toList();
            _trendingManga = topMangaData.take(10).toList();
            _popularManhwa = manhwaData.take(15).toList();
            _popularManhua = manhuaData.take(15).toList();
            _popularNovels = novelData.take(15).toList();
          });
        }
      }
    } catch (_) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _surpriseMe(BuildContext context) async {
    final appState = widget.appState;
    // Show a polished loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 16),
              Text('Finding magic...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                    fontSize: 16,
                  )),
            ],
          ),
        ),
      ),
    );

    try {
      if (appState.currentMode == AppMode.anime) {
        final anime = await _jikan.getRandomAnime();
        if (context.mounted) {
          Navigator.pop(context); // Remove loading
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DetailScreen(malId: anime.malId, isManga: false)),
          );
        }
      } else {
        // Random Manga
        // Jikan v4 has a random manga endpoint
        final mangaData = await _jikan.getTopManga(
            filter:
                'bypopularity'); // Fallback if random isn't handy, but let's assume we can pick random from top
        if (context.mounted) {
          Navigator.pop(context);
          if (mangaData.isNotEmpty) {
            mangaData.shuffle();
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetailScreen(
                      malId: mangaData.first.malId, isManga: true)),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        FloatingNotification.show(
          context,
          title: 'Magic Failed',
          message: 'Failed to find a surprise. Try again!',
          icon: Icons.auto_awesome_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = widget.appState;

    final content = CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/final_app_logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('AniMatch',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
            ],
          ),
          actions: [
            // Mode Toggle in AppBar for Cleaner Look
            IconButton(
              icon: Icon(
                  appState.isAnimeMode
                      ? Icons.movie_filter_rounded
                      : Icons.menu_book_rounded,
                  color: Colors.amber),
              onPressed: () => appState.toggleMode(),
              tooltip: 'Switch to ${appState.isAnimeMode ? 'Manga' : 'Anime'}',
            ),

            // Surprise Me
            IconButton(
              icon: const Icon(Icons.shuffle_rounded, color: Colors.white70),
              onPressed: () => _surpriseMe(context),
              tooltip: 'Surprise Me',
            ),

            // Quiz Button (Matches Screenshot)
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          QuizScreen(isManga: appState.isMangaMode))),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Color(0xFFFF9800)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.black, size: 16),
                    SizedBox(width: 4),
                    Text('Quiz',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              tooltip: 'Profile',
            ),
            const SizedBox(width: 8),
          ],
          floating: true,
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent,
        ),

        // ── Media Type Toggle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => appState.setMode(AppMode.anime),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: appState.isAnimeMode
                              ? Colors.amber
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Anime',
                          style: TextStyle(
                            color: appState.isAnimeMode
                                ? Colors.black
                                : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => appState.setMode(AppMode.manga),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: appState.isMangaMode
                              ? Colors.amber
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Manga',
                          style: TextStyle(
                            color: appState.isMangaMode
                                ? Colors.black
                                : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        if (_loading)
          const SliverFillRemaining(child: HomeShimmer())
        else ...[
          if (appState.isAnimeMode) ...[
            // ── ANIME LAYOUT ──
            if (_spotlightAnime.isNotEmpty)
              SliverToBoxAdapter(
                child: _SpotlightCarousel(
                    spotlightItems: _spotlightAnime, isManga: false),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            if (_trendingAnime.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Trending')),
              SliverToBoxAdapter(
                child: _TrendingList(
                    trendingItems: _trendingAnime, isManga: false),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _ContinueWatchingSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // ── TODAY FOR YOU ─ Decision Engine Hero Card ────────────────────
            const SliverToBoxAdapter(child: _TodayForYouSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _RecommendBanner(isManga: false)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _QuickMoodSelector()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverToBoxAdapter(child: _RecommendedForYouSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(child: _ScheduleSection(jikanService: _jikan)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            if (_topUpcomingAnime.isNotEmpty)
              SliverToBoxAdapter(
                child: _TopUpcomingSection(
                    upcomingItems: _topUpcomingAnime, isManga: false),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            const SliverToBoxAdapter(child: _TopTenSection(isManga: false)),
          ] else ...[
            // ── MANGA LAYOUT ──
            if (_spotlightManga.isNotEmpty)
              SliverToBoxAdapter(
                child: _SpotlightCarousel(
                    spotlightItems: _spotlightManga, isManga: true),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _RecommendBanner(isManga: true)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            if (_trendingManga.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Trending')),
              SliverToBoxAdapter(
                child:
                    _TrendingList(trendingItems: _trendingManga, isManga: true),
              ),
            ],

            if (_popularManhwa.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Popular Manhwa')),
              SliverToBoxAdapter(
                child:
                    _TrendingList(trendingItems: _popularManhwa, isManga: true),
              ),
            ],
            if (_popularManhua.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Popular Manhua')),
              SliverToBoxAdapter(
                child:
                    _TrendingList(trendingItems: _popularManhua, isManga: true),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],

            if (_popularNovels.isNotEmpty) ...[
              const SliverToBoxAdapter(
                  child: _SectionHeader(title: 'Top Novels')),
              SliverToBoxAdapter(
                child:
                    _TrendingList(trendingItems: _popularNovels, isManga: true),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            SliverToBoxAdapter(child: _MagazineSection(jikanService: _jikan)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            SliverToBoxAdapter(
                child: _TopTenSection(jikanService: _jikan, isManga: true)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 200)),
        ],
      ],
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.amber,
      backgroundColor: Colors.black,
      child: content,
    );
  }
}

// ── Spotlight Carousel ────────────────────────────────────────────────────────
class _SpotlightCarousel extends StatefulWidget {
  final List<MediaBase> spotlightItems;
  final bool isManga;
  const _SpotlightCarousel(
      {required this.spotlightItems, this.isManga = false});

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;
  static const int _infinitePages = 1000; // Virtually infinite for a few cards

  @override
  void initState() {
    super.initState();
    // Start in the middle to allow infinite scrolling in both directions
    final initialPage = (_infinitePages ~/ 2) -
        ((_infinitePages ~/ 2) %
            (widget.spotlightItems.isEmpty ? 1 : widget.spotlightItems.length));
    _pageController = PageController(initialPage: initialPage);
    _currentIndex = initialPage %
        (widget.spotlightItems.isEmpty ? 1 : widget.spotlightItems.length);
    _startTimer();
  }

  void _startTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spotlightItems.isEmpty) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = (screenHeight * 0.55).clamp(400.0, 550.0);

    return SizedBox(
      height: carouselHeight,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(
                  () => _currentIndex = idx % widget.spotlightItems.length);
              // Reset timer on page change (manual or auto)
              _startTimer();
            },
            itemBuilder: (context, index) {
              final isCurrent =
                  (index % widget.spotlightItems.length) == _currentIndex;
              final item =
                  widget.spotlightItems[index % widget.spotlightItems.length];

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  // Calculate parallax offset
                  double scrollOffset = 0.0;
                  if (_pageController.hasClients &&
                      _pageController.page != null) {
                    scrollOffset = (_pageController.page! - index);
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DetailScreen(
                                  malId: item.malId, isManga: widget.isManga))),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: isCurrent
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.4),
                              blurRadius: isCurrent ? 30 : 20,
                              spreadRadius: isCurrent ? 5 : 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PremiumImage(
                                imageUrl: item.displayImageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment(
                                    scrollOffset * 0.8, 0), // Parallax effect
                              ),
                              // Premium Multi-gradient System
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.0),
                                      Colors.black.withValues(alpha: 0.2),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.4),
                                      Colors.black.withValues(alpha: 0.95),
                                    ],
                                    stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
                                  ),
                                ),
                              ),
                              // Side shade for text pop
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.6],
                                  ),
                                ),
                              ),
                              // Overlay details
                              Positioned(
                                left: 24,
                                bottom: 30,
                                right: 48,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.amber
                                                    .withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            '#${(index % widget.spotlightItems.length) + 1} Spotlight',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '⭐ ${item.scoreText}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.displayTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        DetailScreen(
                                                            malId: item.malId,
                                                            isManga: widget
                                                                .isManga)));
                                          },
                                          icon: const Icon(
                                              Icons.play_circle_fill_rounded,
                                              color: Colors.black,
                                              size: 20),
                                          label: const Text('Watch Now',
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                          ),
                                        ),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 10, sigmaY: 10),
                                            child: FilledButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            DetailScreen(
                                                                malId:
                                                                    item.malId,
                                                                isManga: widget
                                                                    .isManga)));
                                              },
                                              icon: const Icon(
                                                  Icons.info_outline_rounded,
                                                  color: Colors.white,
                                                  size: 20),
                                              label: const Text('Detail',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.white
                                                    .withValues(alpha: 0.15),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            itemCount: _infinitePages,
          ),
          // Dot indicators on the right
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.spotlightItems.length
                    .clamp(0, 10), // Limit dots for layout
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  width: _currentIndex == index ? 4 : 3,
                  height: _currentIndex == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.amber
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trending List ─────────────────────────────────────────────────────────────
class _TrendingList extends StatefulWidget {
  final List<MediaBase> trendingItems;
  final bool isManga;
  const _TrendingList({required this.trendingItems, this.isManga = false});

  @override
  State<_TrendingList> createState() => _TrendingListState();
}

class _TrendingListState extends State<_TrendingList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          return ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.trendingItems.length,
            itemBuilder: (context, index) {
              final item = widget.trendingItems[index];
              final String numStr = (index + 1).toString().padLeft(2, '0');

              double scrollOffset = 0.0;
              if (_scrollController.hasClients) {
                // Approximate parallax based on index and controller offset
                // Width of item (140) + margin (12) = 152
                double itemPos = index * 152.0;
                scrollOffset = (itemPos - _scrollController.offset) / 152.0;
              }

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PremiumImage(
                        imageUrl: item.displayImageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment(scrollOffset * 0.3, 0),
                      ),
                      // Rank Overlay
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(12)),
                          ),
                          child: Text(
                            numStr,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // Title Overlay at bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.4),
                                Colors.black.withValues(alpha: 0.9),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.mediaTypeBadge.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.mediaProgressText,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top-level InkWell to ensure click-ability on Web
                      Positioned.fill(
                        child: PinterestMenuWrapper(
                          actions: [
                            PinterestMenuAction(
                                icon: Icons.bookmark_add_rounded,
                                label: 'Watchlist',
                                onAction: () async {
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) {
                                    FloatingNotification.show(
                                      context,
                                      title: 'Authentication',
                                      message:
                                          'Sign in to manage your watchlist',
                                      icon: Icons.login_rounded,
                                    );
                                    return;
                                  }

                                  if (item.malId == null) {
                                    snacks.showError(
                                        context, 'Cannot manage watchlist (No ID)');
                                    return;
                                  }
                                  final entry = await FirebaseService()
                                      .getWatchlistEntry(uid, item.malId!,
                                          isManga: widget.isManga);

                                  dynamic currentStatus;
                                  if (entry != null) {
                                    currentStatus = widget.isManga
                                        ? ReadStatus.fromString(entry['status'])
                                        : WatchStatus.fromString(
                                            entry['status']);
                                  }

                                  if (context.mounted) {
                                    await showMediaStatusSheet(
                                      context,
                                      media: item,
                                      isManga: widget.isManga,
                                      currentStatus: currentStatus,
                                    );
                                  }
                                }),
                            PinterestMenuAction(
                                icon: Icons.info_outline_rounded,
                                label: 'Details',
                                onAction: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => DetailScreen(
                                              malId: item.malId,
                                              isManga: widget.isManga)),
                                    )),
                            PinterestMenuAction(
                                icon: Icons.share_rounded,
                                label: 'Share',
                                onAction: () {
                                  // Copy link to clipboard as a "Share" action
                                  final url =
                                      'https://myanimelist.net/${widget.isManga ? 'manga' : 'anime'}/${item.malId}';
                                  Clipboard.setData(ClipboardData(text: url));
                                  FloatingNotification.show(
                                    context,
                                    title: 'Shared',
                                    message: 'Link copied to clipboard!',
                                    icon: Icons.share_rounded,
                                  );
                                }),
                          ],
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(
                                        malId: item.malId,
                                        isManga: widget.isManga),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _QuickMoodSelector extends ConsumerWidget {
  const _QuickMoodSelector();

  static const _moods = [
    ('action', 'Action', Icons.flash_on_rounded),
    ('funny', 'Fun', Icons.sentiment_very_satisfied_rounded),
    ('romantic', 'Emotional', Icons.favorite_rounded),
    ('chill', 'Chill', Icons.spa_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).maybeWhen(
          data: (user) => user,
          orElse: () => FirebaseAuth.instance.currentUser,
        );

    if (user != null) {
      ref.listen(savedRecommendationMoodProvider(user.uid), (_, next) {
        final savedMood = next.maybeWhen(
          data: (mood) => mood,
          orElse: () => null,
        );
        if (savedMood != null) {
          ref
              .read(selectedRecommendationMoodProvider.notifier)
              .hydrate(savedMood);
        }
      });
    }

    final selectedMood = ref.watch(selectedRecommendationMoodProvider);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final mood = _moods[index];
          final isSelected = selectedMood == mood.$1;

          return InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: () {
              unawaited(ref
                  .read(selectedRecommendationMoodProvider.notifier)
                  .setMood(mood.$1, uid: user?.uid));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.amber
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: isSelected
                      ? Colors.amber
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mood.$3,
                    size: 17,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    mood.$2,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContinueWatchingSection extends ConsumerWidget {
  const _ContinueWatchingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).maybeWhen(
          data: (user) => user,
          orElse: () => FirebaseAuth.instance.currentUser,
        );
    if (user == null) return const SizedBox.shrink();

    final watchlist = ref.watch(watchlistProvider(WatchlistFilter(
      uid: user.uid,
      isManga: false,
      watchStatus: WatchStatus.watching,
    )));

    return watchlist.maybeWhen(
      data: (items) {
        final continueItems = items
            .where((item) {
              final progress = item['episodeProgress'] as int? ?? 0;
              final total = item['episodes'] as int?;
              return progress > 0 && (total == null || progress < total);
            })
            .take(10)
            .toList();

        if (continueItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Continue Watching'),
            SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = continueItems[index];
                  final malId = item['malId'] as int? ?? 0;
                  final title = item['title'] as String? ?? 'Unknown';
                  final imageUrl = item['imageUrl'] as String? ?? '';
                  final progress = item['episodeProgress'] as int? ?? 0;
                  final total = item['episodes'] as int?;
                  final nextEpisode = total == null
                      ? progress + 1
                      : (progress + 1).clamp(1, total);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: malId == 0
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(malId: malId),
                              ),
                            ),
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2D31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PremiumImage(
                              imageUrl: imageUrl,
                              title: title,
                              width: 68,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Episode $nextEpisode',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  total == null
                                      ? '$progress watched'
                                      : '$progress / $total watched',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _RecommendedForYouSection extends ConsumerWidget {
  const _RecommendedForYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(homeRecommendationProvider('action'));

    return recommendations.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Recommended for You',
              subtitle: 'Refresh',
              onSubtitleTap: () {
                ref.invalidate(
                    homeRecommendationProvider(defaultRecommendationMood));
              },
            ),
            _TrendingList(trendingItems: items, isManga: false),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSubtitleTap;
  const _SectionHeader(
      {required this.title, this.subtitle, this.onSubtitleTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber)),
          if (subtitle != null)
            GestureDetector(
              onTap: onSubtitleTap,
              child: Text(subtitle!,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── Recommend Banner ──────────────────────────────────────────────────────────
class _RecommendBanner extends StatelessWidget {
  final bool isManga;
  const _RecommendBanner({this.isManga = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Vibrant Base Gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C5CE7),
                        const Color(0xFF6C5CE7).withValues(alpha: 0.8),
                        Colors.amber.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Glass Layer
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 340;
                  return Padding(
                    padding: EdgeInsets.all(isSmall ? 16.0 : 28.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize:
                                MainAxisSize.min, // allow banner to shrink
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('MATCHMAKER',
                                    style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 1.5)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Find your next favorite story',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmall ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Take the personalized quiz ✨',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          QuizScreen(isManga: isManga)),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isSmall ? 14 : 20,
                                      vertical: isSmall ? 8 : 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: const Text('Start Quiz',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        if (!isSmall) ...[
                          const SizedBox(width: 12),
                          // Overlapping Cards Effect for Premium Look
                          SizedBox(
                            width: 130,
                            height: 100,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  right: 0,
                                  top: 10,
                                  child: _FloatingCard(
                                      color:
                                          Colors.amber.withValues(alpha: 0.4),
                                      rotation: 0.1,
                                      scale: 0.8),
                                ),
                                Positioned(
                                  right: 15,
                                  top: 5,
                                  child: _FloatingCard(
                                      color:
                                          Colors.amber.withValues(alpha: 0.7),
                                      rotation: -0.05,
                                      scale: 0.9),
                                ),
                                Positioned(
                                  right: 35,
                                  top: 0,
                                  child: const _FloatingCard(
                                      color: Colors.amber,
                                      rotation: 0,
                                      scale: 1.0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final Color color;
  final double rotation;
  final double scale;
  const _FloatingCard(
      {required this.color, required this.rotation, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: 50,
          height: 65,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Schedule Section ──────────────────────────────────────────────────────────
class _ScheduleSection extends StatefulWidget {
  final JikanService jikanService;
  const _ScheduleSection({required this.jikanService});

  @override
  State<_ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<_ScheduleSection> {
  final AnilistService _anilistService = AnilistService();
  final List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];
  late String _selectedDay;
  List<AiringSchedule> _scheduledAnime = [];
  bool _loading = false;
  bool _isExpanded = false;
  Timer? _timer;
  final ScrollController _dayScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final weekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday
    _selectedDay = _days[weekday - 1];
    _fetchSchedule(_selectedDay);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dayScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchedule(String dayStr) async {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final targetWeekday = _days.indexOf(dayStr) + 1;
    final baseDate = now.subtract(Duration(days: todayWeekday - 1));
    final targetDate = baseDate.add(Duration(days: targetWeekday - 1));

    // Map to zero-hour local timestamps
    final startOfDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0)
                .millisecondsSinceEpoch ~/
            1000;
    final endOfDay = startOfDay + 86400; // +24 hours

    setState(() {
      _selectedDay = dayStr;
      _loading = true;
    });

    try {
      final list = await _anilistService.getSchedules(startOfDay, endOfDay);

      if (mounted) {
        setState(() {
          _scheduledAnime = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDayForUI(String d) {
    switch (d) {
      case 'monday':
        return 'Mon';
      case 'tuesday':
        return 'Tue';
      case 'wednesday':
        return 'Wed';
      case 'thursday':
        return 'Thu';
      case 'friday':
        return 'Fri';
      case 'saturday':
        return 'Sat';
      case 'sunday':
        return 'Sun';
      default:
        return 'Day';
    }
  }

  void _scrollDays(bool right) {
    final offset = right
        ? _dayScrollController.offset + 150
        : _dayScrollController.offset - 150;
    _dayScrollController.animateTo(
      offset.clamp(0.0, _dayScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Title and Live Clock
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Schedule',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[200],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatCurrentTime(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Day Selector with Arrows
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 70,
              child: ListView.builder(
                controller: _dayScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 48),
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final isSelected = _selectedDay == day;
                  final now = DateTime.now();
                  final baseDate =
                      now.subtract(Duration(days: now.weekday - 1));
                  final dateForDay = baseDate.add(Duration(days: index));
                  final suffixStr =
                      '${_formatMonth(dateForDay.month)} ${dateForDay.day}';

                  return GestureDetector(
                    onTap: () => _fetchSchedule(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.amber
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatDayForUI(day),
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suffixStr,
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.black54 : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Arrows
            Positioned(
              left: 8,
              child: _ScrollArrow(
                  onTap: () => _scrollDays(false),
                  icon: Icons.chevron_left_rounded),
            ),
            Positioned(
              right: 8,
              child: _ScrollArrow(
                  onTap: () => _scrollDays(true),
                  icon: Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Schedule List
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()))
        else if (_scheduledAnime.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No programs scheduled for this day.',
                    style: TextStyle(color: Colors.white54))),
          )
        else
          Column(
            children: [
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _isExpanded
                    ? _scheduledAnime.length
                    : _scheduledAnime.take(7).length,
                separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withValues(alpha: 0.05), height: 1),
                itemBuilder: (context, index) {
                  final anime = _scheduledAnime[index];
                  final timeObj = DateTime.fromMillisecondsSinceEpoch(
                      anime.airingAt * 1000);
                  final timeStr =
                      '${timeObj.hour.toString().padLeft(2, '0')}:${timeObj.minute.toString().padLeft(2, '0')}';

                  return InkWell(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DetailScreen(malId: anime.idMal))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(timeStr,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Text(anime.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white54, size: 16),
                              const SizedBox(width: 4),
                              Text('Episode ${anime.episode}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_scheduledAnime.length > 7)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.amber),
                    label: Text(_isExpanded ? 'See less' : 'See more',
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final h = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $amPm';
  }

  String _formatMonth(int m) {
    const mStr = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return mStr[m - 1];
  }
}

class _ScrollArrow extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  const _ScrollArrow({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
    );
  }
}

// ── Magazine Section (Manga Home) ──────────────────────────────────────────────
class _MagazineSection extends StatefulWidget {
  final JikanService jikanService;
  const _MagazineSection({required this.jikanService});

  @override
  State<_MagazineSection> createState() => _MagazineSectionState();
}

class _MagazineSectionState extends State<_MagazineSection> {
  List<MangaMagazine> _magazines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMagazines();
  }

  Future<void> _fetchMagazines() async {
    try {
      final list = await widget.jikanService.getMagazines();
      if (mounted) {
        setState(() {
          _magazines =
              list.take(8).toList(); // Reduced for faster, more reliable load
          _loading =
              false; // Show the section immediately with shimmers/placeholders
        });

        // Fetch covers sequentially to avoid Jikan 429 Rate Limits
        for (final mag in _magazines) {
          if (!mounted || appState.currentMode != AppMode.manga) break;

          final cover = await widget.jikanService.getMagazineCover(mag.malId);
          if (mounted) {
            setState(() {
              mag.imageUrl = cover;
            });
          }
          // The JikanService already handles throttling (800ms between calls)
          // so we don't need an extra manual delay here.
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 32),
        child: MagazineShimmer(),
      );
    }
    if (_magazines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _SectionHeader(title: 'Top Magazines'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _magazines.length,
            itemBuilder: (context, index) {
              final mag = _magazines[index];
              final gradients = [
                [const Color(0xFF6448FE), const Color(0xFF5FC6FF)],
                [const Color(0xFFFE485B), const Color(0xFFFE9A5F)],
                [const Color(0xFF48FE9B), const Color(0xFF5FFF9B)],
                [const Color(0xFF9048FE), const Color(0xFFE55FFF)],
              ];
              final gradient = gradients[index % gradients.length];

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Background Cover
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: mag.imageUrl != null
                            ? PremiumImage(
                                imageUrl: mag.imageUrl!,
                                title: mag.name,
                                height: double.infinity,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Opacity(
                                  opacity: 0.15,
                                  child: Center(
                                    child: Icon(Icons.auto_stories_rounded,
                                        size: 60,
                                        color: Colors.white
                                            .withValues(alpha: 0.5)),
                                  ),
                                ),
                              ),
                      ),

                      // Subtle dynamic overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),

                      // Top Right Arrow Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.north_east_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),

                      // Frosted Glass Footer
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                border: Border(
                                    top: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.1))),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mag.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${mag.count} titles',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white
                                            .withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Click Overlay
                      Positioned.fill(
                        child: PinterestMenuWrapper(
                          actions: [
                            PinterestMenuAction(
                              icon: Icons.open_in_new_rounded,
                              label: 'Browse',
                              onAction: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MagazineBrowseScreen(
                                    magazineId: mag.malId,
                                    magazineName: mag.name,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MagazineBrowseScreen(
                                    magazineId: mag.malId,
                                    magazineName: mag.name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Top Upcoming Section ──────────────────────────────────────────────────────
class _TopUpcomingSection extends StatefulWidget {
  final List<MediaBase> upcomingItems;
  final bool isManga;
  const _TopUpcomingSection(
      {required this.upcomingItems, this.isManga = false});

  @override
  State<_TopUpcomingSection> createState() => _TopUpcomingSectionState();
}

class _TopUpcomingSectionState extends State<_TopUpcomingSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final itemsToShow = _isExpanded
        ? widget.upcomingItems
        : widget.upcomingItems.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Top Upcoming',
          subtitle: _isExpanded ? 'Show less' : 'View more >',
          onSubtitleTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 16,
              children: itemsToShow.map((item) {
                final width = (MediaQuery.of(context).size.width - 32 - 12) / 2;
                return SizedBox(
                  width: width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PremiumImage(
                              imageUrl: item.displayImageUrl,
                              title: item.displayTitle,
                              height: width * 1.4,
                              width: width,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.displayTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.mediaProgressText,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        // Transparent InkWell overlay
                        Positioned.fill(
                          child: PinterestMenuWrapper(
                            actions: [
                              PinterestMenuAction(
                                  icon: Icons.bookmark_add_rounded,
                                  label: 'Watchlist',
                                  onAction: () async {
                                    final uid =
                                        FirebaseAuth.instance.currentUser?.uid;
                                    if (uid == null) {
                                      FloatingNotification.show(
                                        context,
                                        title: 'Authentication',
                                        message:
                                            'Sign in to manage your watchlist',
                                        icon: Icons.login_rounded,
                                      );
                                      return;
                                    }

                                    if (item.malId == null) {
                                      snacks.showError(context,
                                          'Cannot manage watchlist (No ID)');
                                      return;
                                    }
                                    final entry = await FirebaseService()
                                        .getWatchlistEntry(uid, item.malId!,
                                            isManga: widget.isManga);

                                    dynamic currentStatus;
                                    if (entry != null) {
                                      currentStatus = widget.isManga
                                          ? ReadStatus.fromString(
                                              entry['status'])
                                          : WatchStatus.fromString(
                                              entry['status']);
                                    }

                                    if (context.mounted) {
                                      await showMediaStatusSheet(
                                        context,
                                        media: item,
                                        isManga: widget.isManga,
                                        currentStatus: currentStatus,
                                      );
                                    }
                                  }),
                              PinterestMenuAction(
                                  icon: Icons.info_outline_rounded,
                                  label: 'Details',
                                  onAction: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => DetailScreen(
                                                malId: item.malId,
                                                isManga: widget.isManga)),
                                      )),
                            ],
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DetailScreen(
                                            malId: item.malId,
                                            isManga: widget.isManga))),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Top 10 Section ───────────────────────────────────────────────────────────
class _TopTenSection extends ConsumerStatefulWidget {
  final JikanService? jikanService;
  final bool isManga;
  const _TopTenSection({this.jikanService, this.isManga = false});

  @override
  ConsumerState<_TopTenSection> createState() => _TopTenSectionState();
}

class _TopTenSectionState extends ConsumerState<_TopTenSection> {
  String _activeTab = 'Today';
  List<MediaBase> _topList = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isManga) {
      _fetchTop('Today');
    }
  }

  Future<void> _fetchTop(String tab) async {
    setState(() {
      _activeTab = tab;
      _loading = true;
    });
    try {
      if (widget.isManga) {
        String? filter;
        if (tab == 'Today') filter = 'bypopularity';
        if (tab == 'Week') filter = 'publishing';
        if (tab == 'Month') filter = 'favorite';

        final list = await widget.jikanService!.getTopManga(filter: filter);
        if (mounted) {
          setState(() {
            _topList = list;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topAnimeAsync =
        widget.isManga ? null : ref.watch(topAnimeProvider(_activeTab));
    final isLoading = widget.isManga ? _loading : topAnimeAsync!.isLoading;
    final topList = widget.isManga
        ? _topList
        : topAnimeAsync!.maybeWhen(
            data: (items) => items,
            orElse: () => const <Anime>[],
          );

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2D31),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Top 10',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Row(
                    children: ['Today', 'Week', 'Month'].map((tab) {
                      final isActive = _activeTab == tab;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _activeTab = tab);
                          if (widget.isManga) {
                            _fetchTop(tab);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.amber[200]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              color: isActive ? Colors.black : Colors.white,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            if (isLoading)
              const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()))
            else
              ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: topList.take(10).length,
                  itemBuilder: (context, index) {
                    final anime = topList[index];
                    final numStr = (index + 1).toString().padLeft(2, '0');
                    return PinterestMenuWrapper(
                      actions: [
                        PinterestMenuAction(
                            icon: Icons.bookmark_add_rounded,
                            label: 'Watchlist',
                            onAction: () async {
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) {
                                FloatingNotification.show(
                                  context,
                                  title: 'Authentication',
                                  message: 'Sign in to manage your watchlist',
                                  icon: Icons.login_rounded,
                                );
                                return;
                              }

                              if (anime.malId == null) {
                                snacks.showError(
                                    context, 'Cannot manage watchlist (No ID)');
                                return;
                              }
                              final entry = await FirebaseService()
                                  .getWatchlistEntry(uid, anime.malId!,
                                      isManga: widget.isManga);

                              dynamic currentStatus;
                              if (entry != null) {
                                currentStatus = widget.isManga
                                    ? ReadStatus.fromString(entry['status'])
                                    : WatchStatus.fromString(entry['status']);
                              }

                              if (context.mounted) {
                                await showMediaStatusSheet(
                                  context,
                                  media: anime,
                                  isManga: widget.isManga,
                                  currentStatus: currentStatus,
                                );
                              }
                            }),
                        PinterestMenuAction(
                            icon: Icons.info_outline_rounded,
                            label: 'Details',
                            onAction: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => DetailScreen(
                                          malId: anime.malId,
                                          isManga: widget.isManga)),
                                )),
                      ],
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailScreen(
                                    malId: anime.malId,
                                    isManga: widget.isManga))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              // Large rank text
                              SizedBox(
                                  width: 40,
                                  child: Column(
                                    children: [
                                      Text(numStr,
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                      Container(
                                          height: 2,
                                          width: 20,
                                          color: Colors.white54,
                                          margin:
                                              const EdgeInsets.only(top: 4)),
                                    ],
                                  )),
                              // Small Poster
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: PremiumImage(
                                  imageUrl: anime.displayImageUrl,
                                  title: anime.displayTitle,
                                  width: 50,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Details
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    anime.displayTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Badges (Simulating CC/Mic with Episodes/Score)
                                  Row(
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFB1E5D5),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.closed_caption,
                                                  size: 12,
                                                  color: Colors.black),
                                              const SizedBox(width: 4),
                                              Text(
                                                  anime.mediaProgressText
                                                      .split(' ')
                                                      .first,
                                                  style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          )),
                                      const SizedBox(width: 6),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFE5B1D5),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  size: 12,
                                                  color: Colors.black),
                                              const SizedBox(width: 4),
                                              Text(anime.scoreText,
                                                  style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          )),
                                    ],
                                  )
                                ],
                              ))
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
            const SizedBox(height: 8),
          ],
        ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TODAY FOR YOU  —  Decision Engine Hero Section
// ═══════════════════════════════════════════════════════════════════════════════

class _TodayForYouSection extends ConsumerWidget {
  const _TodayForYouSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroAsync = ref.watch(heroRecommendationProvider);
    return heroAsync.when(
      loading: () => const _HeroShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hero) => _HeroCard(hero: hero),
    );
  }
}

class _HeroShimmer extends StatelessWidget {
  const _HeroShimmer();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Container(
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14,
                    width: 100,
                    color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 12),
                Container(
                    height: 20,
                    width: 180,
                    color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 8),
                Container(
                    height: 14,
                    width: 140,
                    color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 20),
                Container(
                    height: 40,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final HeroRecommendation hero;
  const _HeroCard({required this.hero});

  @override
  Widget build(BuildContext context) {
    final anime = hero.anime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFa29bfe)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('Today For You',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.3)),
              ]),
            ),
            const SizedBox(width: 8),
            Text('Pick in under 10 seconds',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),

        // Main card
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DetailScreen(malId: anime.malId, isManga: false))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(fit: StackFit.expand, children: [
                  PremiumImage(
                      imageUrl: anime.displayImageUrl, fit: BoxFit.cover),
                  DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                        Colors.black.withValues(alpha: 0.93),
                        Colors.black.withValues(alpha: 0.55)
                      ]))),
                  Row(children: [
                    Container(
                      width: 130,
                      margin: const EdgeInsets.all(14),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: PremiumImage(
                              imageUrl: anime.displayImageUrl,
                              fit: BoxFit.cover)),
                    ),
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ConfidenceBadge(confidence: hero.confidence),
                                const SizedBox(height: 10),
                                Text(anime.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        height: 1.2)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.lightbulb_outline_rounded,
                                      color: Color(0xFFa29bfe), size: 13),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: Text(hero.explanation,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xFFa29bfe),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500))),
                                ]),
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  if (anime.score != null)
                                    _StatChip('⭐ ${anime.scoreText}'),
                                  _StatChip(anime.mediaProgressText),
                                  if (anime.genres.isNotEmpty)
                                    _StatChip(anime.genres.first),
                                ]),
                              ]),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => DetailScreen(
                                            malId: anime.malId,
                                            isManga: false))),
                                icon: const Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.black, size: 18),
                                label: const Text('Watch Now',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                                style: FilledButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                              )),
                        ],
                      ),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
        ),

        // Alternatives strip
        if (hero.alternatives.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('Other picks',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.08), height: 1)),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: hero.alternatives.length,
              itemBuilder: (context, i) {
                final alt = hero.alternatives[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              DetailScreen(malId: alt.malId, isManga: false))),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08))),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(14)),
                        child: SizedBox(
                            width: 48,
                            height: double.infinity,
                            child: PremiumImage(
                                imageUrl: alt.displayImageUrl,
                                fit: BoxFit.cover)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alt.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(alt.genres.take(2).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11)),
                        ],
                      )),
                      const SizedBox(width: 8),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ── Confidence badge ──────────────────────────────────────────────────────────
class _ConfidenceBadge extends StatelessWidget {
  final int confidence;
  const _ConfidenceBadge({required this.confidence});
  Color get _color {
    if (confidence >= 90) return const Color(0xFF00cec9); // teal
    if (confidence >= 75) return const Color(0xFF6C5CE7); // purple
    return const Color(0xFFfdcb6e); // amber
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.5))),
      child: Text('$confidence% match',
          style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

// ── Small stat chip ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}
