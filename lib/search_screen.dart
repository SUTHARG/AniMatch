import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'media_base.dart';
import 'manga.dart';
import 'anime.dart';
import 'jikan_service.dart';
import 'firebase_service.dart';
import 'anilist_service.dart';
import 'detail_screen.dart';
import 'image_utils.dart';
import 'shimmer_skeletons.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final JikanService _jikan = JikanService();
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<MediaBase> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _lastQuery = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    if (query == _lastQuery && _results.isNotEmpty) return;
    
    _lastQuery = query;
    setState(() => _loading = true);
    
    try {
      final List<MediaBase> results;
      if (appState.currentMode == AppMode.manga) {
        results = await _jikan.searchManga(query);
      } else {
        results = await _jikan.searchAnime(query);
      }
      
      if (mounted && _lastQuery == query) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchFromHistory(String query) {
    _controller.text = query;
    _onChanged(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              _firebase.saveSearchQuery(val).ignore();
            }
          },
          autofocus: false,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: appState.currentMode == AppMode.manga ? 'Search manga...' : 'Search anime...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _lastQuery = '';
                      });
                    },
                  )
                : Icon(Icons.search, color: Colors.white24),
          ),
        ),
      ),
      body: _loading
          ? const SearchShimmer()
          : _results.isEmpty
              ? _controller.text.isEmpty
                  ? _buildRecentSearches()
                  : _buildEmptyState(colorScheme)
              : ListView.builder(
                  itemCount: _results.length,
                  padding: const EdgeInsets.only(top: 8),
                  itemBuilder: (_, i) {
                    return _SearchMediaCard(
                      media: _results[i],
                      isManga: appState.currentMode == AppMode.manga,
                      onTap: () {
                        // Save query when user explicitly clicks a result
                        if (_controller.text.trim().isNotEmpty) {
                          _firebase.saveSearchQuery(_controller.text).ignore();
                        }
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'No results for "$_lastQuery"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return StreamBuilder<List<String>>(
      stream: _firebase.getRecentSearchesStream(),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 64, color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 16),
                Text('Search for your favorite ${appState.currentMode == AppMode.manga ? "manga" : "anime"}', style: const TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Recent Searches',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _firebase.clearSearchHistory(),
                    child: Text('Clear All', style: TextStyle(color: Colors.amber, fontSize: 13)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final query = history[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _searchFromHistory(query),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.history, color: Colors.white38, size: 18),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  query,
                                  style: TextStyle(color: Colors.white, fontSize: 15),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white24, size: 18),
                                onPressed: () => _firebase.removeSearchQuery(query),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchMediaCard extends StatefulWidget {
  final MediaBase media;
  final bool isManga;
  final VoidCallback onTap;
  const _SearchMediaCard({required this.media, required this.isManga, required this.onTap});

  @override
  State<_SearchMediaCard> createState() => _SearchMediaCardState();
}

class _SearchMediaCardState extends State<_SearchMediaCard> {
  final AnilistService _anilist = AnilistService();
  String? _anilistImageUrl;
  bool _loadingAnilist = false;

  @override
  void initState() {
    super.initState();
    _loadAnilistImage();
  }

  Future<void> _loadAnilistImage() async {
    if (!mounted || !kIsWeb) return;
    setState(() => _loadingAnilist = true);
    
    // Stage 1: Try by MAL ID
    String? url = await _anilist.getCoverImageByMalId(widget.media.malId).timeout(const Duration(seconds: 2), onTimeout: () => null);
    
    // Stage 2: Try by Title if ID fails
    if (url == null && mounted) {
      url = await _anilist.getCoverImageByTitle(widget.media.displayTitle).timeout(const Duration(seconds: 2), onTimeout: () => null);
    }

    if (mounted) {
      setState(() {
        _anilistImageUrl = url;
        _loadingAnilist = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final media = widget.media;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 44,
          height: 60,
          color: colorScheme.surfaceVariant,
          child: (_loadingAnilist && _anilistImageUrl == null)
              ? const ShimmerSkeleton(width: double.infinity, height: double.infinity, borderRadius: 0)
              : PremiumImage(
                  imageUrl: _anilistImageUrl ?? media.displayImageUrl,
                  title: media.displayTitle,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      title: Text(media.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${media.scoreText} · ${media.mediaProgressText}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: media.genres.isNotEmpty
          ? Chip(
              label: Text(media.genres.first, style: TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      onTap: () {
        widget.onTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(malId: media.malId, isManga: widget.isManga),
          ),
        );
      },
    );
  }
}
