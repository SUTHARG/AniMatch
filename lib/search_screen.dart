import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'anime.dart';           // ← was 'lib/models/anime.dart'
import 'jikan_service.dart';   // ← was '../services/jikan_service.dart'
import 'detail_screen.dart';

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
                    final anime = _results[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          width: 44,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(anime.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${anime.scoreText} · ${anime.episodeText}',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      trailing: anime.genres.isNotEmpty
                          ? Chip(
                              label: Text(anime.genres.first,
                                  style: const TextStyle(fontSize: 10)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            )
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(malId: anime.malId),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
