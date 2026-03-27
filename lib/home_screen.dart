import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime.dart';           // ← was '../models/anime.dart'
import 'jikan_service.dart';   // ← was '../services/jikan_service.dart'
import 'quiz_screen.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final JikanService _jikan = JikanService();
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _HomeTab(),
    SearchScreen(),
    WatchlistScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Watchlist',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizScreen()),
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Find anime'),
            )
          : null,
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final JikanService _jikan = JikanService();
  List<Anime> _topAnime = [];
  List<Anime> _seasonal = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final top = await _jikan.getTopAnime();
      final seasonal = await _jikan.getCurrentSeasonAnime();
      if (mounted) {
        setState(() {
          _topAnime = top;
          _seasonal = seasonal;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Row(
            children: [
              Text('🎌', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('AniMatch',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          floating: true,
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
        ),

        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // "Find your next anime" banner
          SliverToBoxAdapter(
            child: _RecommendBanner(),
          ),

          // Airing now
          if (_seasonal.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(title: '📡 Airing now'),
            ),
            SliverToBoxAdapter(
              child: _HorizontalAnimeList(animeList: _seasonal),
            ),
          ],

          // Top rated
          if (_topAnime.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(title: '⭐ Top rated all time'),
            ),
            SliverToBoxAdapter(
              child: _HorizontalAnimeList(animeList: _topAnime),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}

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
              colorScheme.secondaryContainer,
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
                                .withOpacity(0.8),
                          )),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              )),
    );
  }
}

class _HorizontalAnimeList extends StatelessWidget {
  final List<Anime> animeList;
  const _HorizontalAnimeList({required this.animeList});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: animeList.length,
        itemBuilder: (_, i) {
          final anime = animeList[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(malId: anime.malId),
              ),
            ),
            child: Container(
              width: 130,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: anime.imageUrl,
                        fit: BoxFit.cover,
                        width: 130,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    anime.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                  ),
                  if (anime.score != null)
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 11, color: Color(0xFFFFD700)),
                        const SizedBox(width: 2),
                        Text(anime.scoreText,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
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
