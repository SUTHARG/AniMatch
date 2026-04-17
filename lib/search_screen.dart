import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:untitled1/anilist_service.dart';
import 'anime.dart';
import 'jikan_service.dart';
import 'detail_screen.dart';
import 'image_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final JikanService _jikan = JikanService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<Anime> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query == _lastQuery) return;
    _lastQuery = query;
    setState(() => _loading = true);
    try {
      final results = await _jikan.searchAnime(query);
      if (mounted && _lastQuery == query) {
        setState(() { _results = results; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Search anime...',
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() { _results = []; _lastQuery = ''; });
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        _lastQuery.isEmpty
                            ? 'Search for any anime'
                            : 'No results for "$_lastQuery"',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      return _SearchAnimeCard(anime: _results[i]);
                    },
                  ),
    );
  }
}

class _SearchAnimeCard extends StatefulWidget {
  final Anime anime;
  const _SearchAnimeCard({required this.anime});

  @override
  State<_SearchAnimeCard> createState() => _SearchAnimeCardState();
}

class _SearchAnimeCardState extends State<_SearchAnimeCard> {
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
    String? url = await _anilist.getCoverImageByMalId(widget.anime.malId);
    
    // Stage 2: Try by Title if ID fails
    if (url == null && mounted) {
      url = await _anilist.getCoverImageByTitle(widget.anime.displayTitle);
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
    final anime = widget.anime;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 44,
          height: 60,
          color: colorScheme.surfaceVariant,
          child: (_loadingAnilist && _anilistImageUrl == null)
              ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
              : PremiumImage(
                  imageUrl: _anilistImageUrl ?? anime.displayImageUrl,
                  title: anime.displayTitle,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      title: Text(anime.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${anime.scoreText} · ${anime.episodeText}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: anime.genres.isNotEmpty
          ? Chip(
              label: Text(anime.genres.first, style: const TextStyle(fontSize: 10)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailScreen(malId: anime.malId),
        ),
      ),
    );
  }
}
