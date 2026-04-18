import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'manga.dart';
import 'anime.dart';
import 'anilist_service.dart';
import 'jikan_service.dart';
import 'quiz_screen.dart';
import 'detail_screen.dart';
import 'floating_notification.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';
import 'profile_screen.dart';
import 'image_utils.dart';
import 'shimmer_skeletons.dart';
import 'media_base.dart';
import 'browse_magazines_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  static final Map<String, String> _imageHeaders = kIsWeb ? {} : {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBody: true, // Allows content to flow behind the glass bar
      body: ValueListenableBuilder<AppMode>(
        valueListenable: appState.modeNotifier,
        builder: (context, mode, child) {
          return IndexedStack(index: _currentIndex, children: const [
            _HomeTab(),
            WatchlistScreen(),
          ]);
        },
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
                color: Colors.transparent, // Transparent to show glass behind
                elevation: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavBarIcon(
                      icon: _currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                      isActive: _currentIndex == 0,
                      onTap: () => setState(() => _currentIndex = 0),
                      label: 'Home',
                    ),
                    const SizedBox(width: 48), // Space for FAB
                    _NavBarIcon(
                      icon: _currentIndex == 1 ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
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
          child: const Icon(Icons.search_rounded, color: Colors.black, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
              color: isActive ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 26,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
    path.arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius));
    
    // Right line
    path.lineTo(size.width, size.height - radius);
    
    // Bottom right corner
    path.arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius));
    
    // Bottom line
    path.lineTo(radius, size.height);
    
    // Bottom left corner
    path.arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius));
    
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
    path.arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius));
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius));
    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius));
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

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
  List<Manga> _topUpcomingManga = [];
  
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    appState.modeNotifier.addListener(_onModeChanged);
    _load();
  }

  @override
  void dispose() {
    appState.modeNotifier.removeListener(_onModeChanged);
    super.dispose();
  }

  void _onModeChanged() {
    if ((appState.currentMode == AppMode.anime && _spotlightAnime.isEmpty) ||
        (appState.currentMode == AppMode.manga && _spotlightManga.isEmpty)) {
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    try {
      if (appState.currentMode == AppMode.anime) {
        final trendingData = await _anilist.getTrendingAnime();
        final seasonalData = await _anilist.getSeasonalAnime();
        final upcomingData = await _anilist.getTopUpcomingAnime();

        if (mounted) {
          setState(() {
            _spotlightAnime = seasonalData.take(10).map((e) => Anime.fromAniList(e)).toList();
            _trendingAnime = trendingData.take(10).map((e) => Anime.fromAniList(e)).toList();
            _topUpcomingAnime = upcomingData.map((e) => Anime.fromAniList(e)).toList();
            _loading = false;
          });
        }
      } else {
        // Load Manga Data
        final trendingMangaData = await _jikan.getTopManga(filter: 'publishing'); // Current top publishing
        final topMangaData = await _jikan.getTopManga(); // All-time top

        if (mounted) {
          setState(() {
            // Using publishing manga as spotlight to mirror seasonal anime
            _spotlightManga = trendingMangaData.take(10).toList();
            _trendingManga = topMangaData.take(10).toList();
            _topUpcomingManga = []; // Maybe leave upcoming blank or use something else
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _surpriseMe(BuildContext context) async {
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
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                )
              ),
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
            MaterialPageRoute(builder: (_) => DetailScreen(malId: anime.malId, isManga: false)),
          );
        }
      } else {
        // Random Manga
        // Jikan v4 has a random manga endpoint
        final mangaData = await _jikan.getTopManga(filter: 'bypopularity'); // Fallback if random isn't handy, but let's assume we can pick random from top
        if (context.mounted) {
          Navigator.pop(context);
          if (mangaData.isNotEmpty) {
             mangaData.shuffle();
             Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => DetailScreen(malId: mangaData.first.malId, isManga: true)),
             );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        FloatingNotification.show(
          context,
          title: 'Surprise Unavailable',
          message: 'Failed to find a surprise. Try again!',
          icon: Icons.auto_awesome_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = CustomScrollView(
      slivers: [
        SliverAppBar(
          title: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎌', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('AniMatch',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.shuffle_rounded, color: Colors.amber),
              onPressed: () => _surpriseMe(context),
              tooltip: 'Surprise Me',
            ),
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen())),
              tooltip: 'Anime Quiz',
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              tooltip: 'Profile',
            ),
            const SizedBox(width: 8),
          ],
          floating: true,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),

        // ── Media Type Toggle ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => appState.setMode(AppMode.anime),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: appState.currentMode == AppMode.anime ? Colors.amber : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Anime',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appState.currentMode == AppMode.anime ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => appState.setMode(AppMode.manga),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: appState.currentMode == AppMode.manga ? Colors.amber : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Manga',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appState.currentMode == AppMode.manga ? Colors.black : Colors.white70,
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

        if (_loading)
          const SliverFillRemaining(
              child: HomeShimmer())
        else ...[
          // Spotlight Carousel
          if (appState.currentMode == AppMode.anime && _spotlightAnime.isNotEmpty)
            SliverToBoxAdapter(
              child: _SpotlightCarousel(spotlightItems: _spotlightAnime, isManga: false),
            ),
          if (appState.currentMode == AppMode.manga && _spotlightManga.isNotEmpty)
            SliverToBoxAdapter(
              child: _SpotlightCarousel(spotlightItems: _spotlightManga, isManga: true),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          if (appState.currentMode == AppMode.anime && _trendingAnime.isNotEmpty) ...[
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Trending')),
            SliverToBoxAdapter(
              child: _TrendingList(trendingItems: _trendingAnime, isManga: false),
            ),
          ],
          if (appState.currentMode == AppMode.manga && _trendingManga.isNotEmpty) ...[
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Trending')),
            SliverToBoxAdapter(
              child: _TrendingList(trendingItems: _trendingManga, isManga: true),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Quiz banner moved here for better visibility
          SliverToBoxAdapter(child: _RecommendBanner()),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Schedule Section (Anime Only)
          if (appState.currentMode == AppMode.anime)
            SliverToBoxAdapter(child: _ScheduleSection(jikanService: _jikan)),

          // Magazines Section (Manga Only)
          if (appState.currentMode == AppMode.manga)
            SliverToBoxAdapter(child: _MagazineSection(jikanService: _jikan)),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Top Upcoming List
          if (appState.currentMode == AppMode.anime && _topUpcomingAnime.isNotEmpty) 
            SliverToBoxAdapter(
              child: _TopUpcomingSection(upcomingItems: _topUpcomingAnime, isManga: false),
            ),
          if (appState.currentMode == AppMode.manga && _topUpcomingManga.isNotEmpty) 
            SliverToBoxAdapter(
              child: _TopUpcomingSection(upcomingItems: _topUpcomingManga, isManga: true),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Top 10 List
          if (appState.currentMode == AppMode.anime) ...[
            SliverToBoxAdapter(child: _TopTenSection(anilistService: _anilist, isManga: false)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
          if (appState.currentMode == AppMode.manga) ...[
            SliverToBoxAdapter(child: _TopTenSection(jikanService: _jikan, isManga: true)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
  const _SpotlightCarousel({required this.spotlightItems, this.isManga = false});

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
    final initialPage = (_infinitePages ~/ 2) - ((_infinitePages ~/ 2) % (widget.spotlightItems.isEmpty ? 1 : widget.spotlightItems.length));
    _pageController = PageController(initialPage: initialPage);
    _currentIndex = initialPage % (widget.spotlightItems.isEmpty ? 1 : widget.spotlightItems.length);
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
    
    return SizedBox(
      height: 520, // Slightly taller for the card padding
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              setState(() => _currentIndex = idx % widget.spotlightItems.length);
              // Reset timer on page change (manual or auto)
              _startTimer();
            },
            itemCount: _infinitePages,
            itemBuilder: (context, index) {
              final isCurrent = (index % widget.spotlightItems.length) == _currentIndex;
              final item = widget.spotlightItems[index % widget.spotlightItems.length];
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetailScreen(malId: item.malId, isManga: widget.isManga))),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: isCurrent 
                              ? Colors.amber.withOpacity(0.3) 
                              : Colors.black.withOpacity(0.4),
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
                          ),
                          // Premium Multi-gradient System
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.1),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.9),
                                ],
                                stops: const [0.0, 0.3, 0.6, 1.0],
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
                                  Colors.black.withOpacity(0.6),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '⭐ ${item.scoreText}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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
                                                builder: (_) => DetailScreen(
                                                    malId: item.malId, isManga: widget.isManga)));
                                      },
                                      icon: const Icon(Icons.play_circle_fill_rounded,
                                          color: Colors.black, size: 20),
                                      label: const Text('Watch Now',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold)),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) => DetailScreen(
                                                        malId: item.malId, isManga: widget.isManga)));
                                          },
                                          icon: const Icon(Icons.info_outline_rounded,
                                              color: Colors.white, size: 20),
                                          label: const Text('Detail',
                                              style: TextStyle(color: Colors.white)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.white.withOpacity(0.15),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          ),
          // Dot indicators on the right
          Positioned(
            right: 24,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.spotlightItems.length.clamp(0, 10), // Limit dots for layout
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  width: _currentIndex == index ? 4 : 3,
                  height: _currentIndex == index ? 20 : 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.amber
                        : Colors.white.withOpacity(0.3),
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
class _TrendingList extends StatelessWidget {
  final List<MediaBase> trendingItems;
  final bool isManga;
  const _TrendingList({required this.trendingItems, this.isManga = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: trendingItems.length,
        itemBuilder: (context, index) {
          final item = trendingItems[index];
          final String numStr = (index + 1).toString().padLeft(2, '0');

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
                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: Text(
                        item.displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  
                  // Top-level InkWell to ensure click-ability on Web
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(malId: item.malId, isManga: isManga),
                            ),
                          );
                        },
                      ),
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

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSubtitleTap;
  const _SectionHeader({required this.title, this.subtitle, this.onSubtitleTap});

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
              child: Text(subtitle!, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ── Recommend Banner ──────────────────────────────────────────────────────────
class _RecommendBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not sure what to watch?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          )),
                  const SizedBox(height: 4),
                  Text('Take a quick quiz and get personalized picks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          )),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QuizScreen())),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Start quiz ✨'),
                  ),
                ],
              ),
            ),
            const Text('🎭', style: TextStyle(fontSize: 56)),
          ],
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
  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
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
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0).millisecondsSinceEpoch ~/ 1000;
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
    switch(d) {
      case 'monday': return 'Mon';
      case 'tuesday': return 'Tue';
      case 'wednesday': return 'Wed';
      case 'thursday': return 'Thu';
      case 'friday': return 'Fri';
      case 'saturday': return 'Sat';
      case 'sunday': return 'Sun';
      default: return 'Day';
    }
  }

  void _scrollDays(bool right) {
    final offset = right ? _dayScrollController.offset + 150 : _dayScrollController.offset - 150;
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  final baseDate = now.subtract(Duration(days: now.weekday - 1));
                  final dateForDay = baseDate.add(Duration(days: index));
                  final suffixStr = '${_formatMonth(dateForDay.month)} ${dateForDay.day}';

                  return GestureDetector(
                    onTap: () => _fetchSchedule(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber : colorScheme.surfaceVariant.withOpacity(0.3),
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
                              color: isSelected ? Colors.black54 : Colors.white54,
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
              child: _ScrollArrow(onTap: () => _scrollDays(false), icon: Icons.chevron_left_rounded),
            ),
            Positioned(
              right: 8,
              child: _ScrollArrow(onTap: () => _scrollDays(true), icon: Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Schedule List
        if (_loading)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_scheduledAnime.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No programs scheduled for this day.', style: TextStyle(color: Colors.white54))),
          )
        else
          Column(
            children: [
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _isExpanded ? _scheduledAnime.length : _scheduledAnime.take(7).length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                itemBuilder: (context, index) {
                  final anime = _scheduledAnime[index];
                  final timeObj = DateTime.fromMillisecondsSinceEpoch(anime.airingAt * 1000);
                  final timeStr = '${timeObj.hour.toString().padLeft(2, '0')}:${timeObj.minute.toString().padLeft(2, '0')}';

                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(malId: anime.idMal))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Text(
                              anime.title, 
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.white),
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 16),
                              const SizedBox(width: 4),
                              Text('Episode ${anime.episode}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
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
                    icon: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.amber),
                    label: Text(_isExpanded ? 'See less' : 'See more', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
    const mStr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
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
          _magazines = list.take(8).toList(); // Reduced for faster, more reliable load
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
          // Small staggered delay between magazines to stay under Jikan's 3req/sec limit
          await Future.delayed(const Duration(milliseconds: 600));
        }
        
        if (mounted) setState(() => _loading = false);
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
          height: 220, // Increased height for the new aspect ratio
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _magazines.length,
            itemBuilder: (context, index) {
              final mag = _magazines[index];
              // Use different gradients to simulate unique magazine covers
              final gradients = [
                [const Color(0xFF6448FE), const Color(0xFF5FC6FF)],
                [const Color(0xFFFE485B), const Color(0xFFFE9A5F)],
                [const Color(0xFF48FE9B), const Color(0xFF5FFF9B)],
                [const Color(0xFF9048FE), const Color(0xFFE55FFF)],
              ];
              final gradient = gradients[index % gradients.length];

              return Container(
                width: 160, 
                margin: const EdgeInsets.only(right: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Background Cover
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
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
                                  child: Icon(Icons.auto_stories_rounded, size: 80, color: Colors.white.withOpacity(0.5)),
                                ),
                              ),
                            ),
                      ),
                      
                      // Subtle dynamic overlay for better text legibility
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                      
                      // Top Right Arrow Button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.north_east_rounded, size: 14, color: Colors.white),
                        ),
                      ),
  
                      // Frosted Glass Footer
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Stars
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      Icons.star_rounded, 
                                      size: 10, 
                                      color: i < 4 ? Colors.amber : Colors.white24
                                    )),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mag.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${mag.count} titles',
                                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Click Overlay (Ensures reactivity on Web/CORS images)
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
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
  const _TopUpcomingSection({required this.upcomingItems, this.isManga = false});

  @override
  State<_TopUpcomingSection> createState() => _TopUpcomingSectionState();
}

class _TopUpcomingSectionState extends State<_TopUpcomingSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final itemsToShow = _isExpanded ? widget.upcomingItems : widget.upcomingItems.take(4).toList();

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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.mediaProgressText,
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                          ],
                        ),
                        // Transparent InkWell overlay
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(malId: item.malId, isManga: widget.isManga))),
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
class _TopTenSection extends StatefulWidget {
  final AnilistService? anilistService;
  final JikanService? jikanService;
  final bool isManga;
  const _TopTenSection({this.anilistService, this.jikanService, this.isManga = false});

  @override
  State<_TopTenSection> createState() => _TopTenSectionState();
}

class _TopTenSectionState extends State<_TopTenSection> {
  String _activeTab = 'Today';
  List<MediaBase> _topList = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchTop('Today');
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
      } else {
        List<Map<String, dynamic>> rawList;
        if (tab == 'Today') {
          rawList = await widget.anilistService!.getTrendingAnime(); 
        } else if (tab == 'Week') {
          rawList = await widget.anilistService!.getSeasonalAnime();
        } else {
          rawList = await widget.anilistService!.getTopRatedAnime();
        }

        if (mounted) {
          setState(() {
            _topList = rawList.map((e) => Anime.fromAniList(e)).toList();
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
                const Text('Top 10', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                   children: ['Today', 'Week', 'Month'].map((tab) {
                      final isActive = _activeTab == tab;
                      return GestureDetector(
                        onTap: () => _fetchTop(tab),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.amber[200] : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                             tab,
                             style: TextStyle(
                                color: isActive ? Colors.black : Colors.white,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          
          if (_loading)
             const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else
             ListView.builder(
               padding: EdgeInsets.zero,
               physics: const NeverScrollableScrollPhysics(),
               shrinkWrap: true,
               itemCount: _topList.take(10).length,
               itemBuilder: (context, index) {
                 final anime = _topList[index];
                 final numStr = (index + 1).toString().padLeft(2, '0');
                 return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(malId: anime.malId))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Large rank text
                           SizedBox(
                             width: 40,
                             child: Column(
                               children: [
                                    Text(numStr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Container(height: 2, width: 20, color: Colors.white54, margin: const EdgeInsets.only(top: 4)),
                                  ],
                                )
                          ),
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
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                   maxLines: 2,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 const SizedBox(height: 8),
                                 // Badges (Simulating CC/Mic with Episodes/Score)
                                 Row(
                                   children: [
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                       decoration: BoxDecoration(color: const Color(0xFFB1E5D5), borderRadius: BorderRadius.circular(4)),
                                       child: Row(
                                         children: [
                                           const Icon(Icons.closed_caption, size: 12, color: Colors.black),
                                           const SizedBox(width: 4),
                                           Text('${anime.mediaProgressText.split(' ').first}', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                         ],
                                       )
                                     ),
                                     const SizedBox(width: 6),
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                       decoration: BoxDecoration(color: const Color(0xFFE5B1D5), borderRadius: BorderRadius.circular(4)),
                                       child: Row(
                                         children: [
                                           const Icon(Icons.star_rounded, size: 12, color: Colors.black),
                                           const SizedBox(width: 4),
                                           Text(anime.scoreText, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                         ],
                                       )
                                     ),
                                   ],
                                 )
                               ],
                             )
                          )
                        ],
                      ),
                    )
                 );
               }
             ),
             const SizedBox(height: 8),
        ],
      )
    );
  }
}