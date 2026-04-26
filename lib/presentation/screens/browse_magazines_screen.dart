import 'package:flutter/material.dart';
import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/data/sources/remote/jikan_service.dart';
import 'package:animatch/presentation/screens/detail_screen.dart';
import 'package:animatch/core/utils/image_utils.dart'; // For PremiumImage

class MagazineBrowseScreen extends StatefulWidget {
  final int magazineId;
  final String magazineName;

  const MagazineBrowseScreen({
    super.key,
    required this.magazineId,
    required this.magazineName,
  });

  @override
  State<MagazineBrowseScreen> createState() => _MagazineBrowseScreenState();
}

class _MagazineBrowseScreenState extends State<MagazineBrowseScreen> {
  final JikanService _jikan = JikanService();
  List<MediaBase> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final results = await _jikan.getMangaByMagazine(widget.magazineId);
      if (mounted) {
        setState(() {
          _items = results;
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.magazineName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(
                              malId: (item as dynamic).malId, isManga: true),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PremiumImage(
                              imageUrl: item.displayImageUrl,
                              title: item.displayTitle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No manga found in this magazine',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
