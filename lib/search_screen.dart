import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_state.dart';
import 'media_base.dart';
import 'jikan_service.dart';
import 'firebase_service.dart';
import 'anilist_service.dart';
import 'detail_screen.dart';
import 'image_utils.dart';
import 'shimmer_skeletons.dart';
import 'pinterest_interaction.dart';
import 'watch_status_sheet.dart';
import 'utils/snackbar_utils.dart' as snacks;

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

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

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
      if (appState.isMangaMode) {
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
            final uid = _uid;
            final trimmed = val.trim();
            if (trimmed.isNotEmpty && uid != null) {
              _firebase.addSearchTerm(uid, trimmed).ignore();
            }
          },
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: appState.isMangaMode ? 'Search manga...' : 'Search anime...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _lastQuery = '';
                      });
                    },
                  )
                : const Icon(Icons.search, color: Colors.white24),
          ),
        ),
      ),
      body: _loading
          ? const SearchShimmer()
          : _results.isEmpty
              ? _controller.text.isEmpty
                  ? _buildRecentSearchChips()
                  : _buildEmptyState(colorScheme)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  itemCount: _results.length,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemBuilder: (_, i) {
                    return _SearchMediaCard(
                      media: _results[i],
                      isManga: appState.isMangaMode,
                      onTap: () {
                        final uid = _uid;
                        if (_controller.text.trim().isNotEmpty && uid != null) {
                          _firebase.addSearchTerm(uid, _controller.text).ignore();
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
          const Text('🔍', style: TextStyle(fontSize: 48)),
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

  Widget _buildRecentSearchChips() {
    final uid = _uid;
    if (uid == null) return const Center(child: Text('Sign in to see history', style: TextStyle(color: Colors.white38)));

    return StreamBuilder<List<String>>(
      stream: _firebase.getRecentSearchesStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Search history error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'History Error: ${snapshot.error}', 
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white10));
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 64, color: Colors.white.withValues(alpha: 0.05)),
                const SizedBox(height: 16),
                Text('Search for your favorite ${appState.isMangaMode ? "manga" : "anime"}', style: const TextStyle(color: Colors.white38)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    onPressed: () {
                      _firebase.clearSearchHistory(uid);
                      snacks.showSuccess(context, 'Search history cleared');
                    },
                    child: const Text('Clear All', style: TextStyle(color: Colors.amber, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: history.map((query) {
                  return ActionChip(
                    label: Text(query),
                    onPressed: () => _searchFromHistory(query),
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    labelStyle: const TextStyle(color: Colors.white70),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ],
          ),
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

    return PinterestMenuWrapper(
      actions: [
        PinterestMenuAction(
          icon: Icons.bookmark_add_rounded, 
          label: 'Watchlist', 
          onAction: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              snacks.showError(context, 'Please log in to manage your watchlist.');
              return;
            }
            final entry = await FirebaseService().getWatchlistEntry(
              uid, media.malId, isManga: widget.isManga
            );
            
            dynamic currentStatus;
            if (entry != null) {
              currentStatus = widget.isManga 
                ? ReadStatus.fromString(entry['status']) 
                : WatchStatus.fromString(entry['status']);
            }

            if (context.mounted) {
              await showMediaStatusSheet(
                context,
                media: media,
                isManga: widget.isManga,
                currentStatus: currentStatus,
              );
            }
          }
        ),
        PinterestMenuAction(
          icon: Icons.info_outline_rounded, 
          label: 'Details', 
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailScreen(malId: media.malId, isManga: widget.isManga)),
          )
        ),
      ],
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 44,
            height: 60,
            color: colorScheme.surfaceContainerHighest,
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
                label: Text(media.genres.first, style: const TextStyle(fontSize: 10)),
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
      ),
    );
  }
}
