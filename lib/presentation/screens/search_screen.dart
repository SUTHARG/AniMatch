import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animatch/core/app_state.dart';
import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/presentation/screens/detail_screen.dart';
import 'package:animatch/core/utils/image_utils.dart';
import 'package:animatch/presentation/widgets/shimmer_loader.dart';
import 'package:animatch/presentation/widgets/pinterest_interaction.dart';
import 'package:animatch/presentation/widgets/watch_status_sheet.dart';
import 'package:animatch/core/utils/snackbar_utils.dart' as snacks;
import 'package:animatch/presentation/providers/search_provider.dart';
import 'package:animatch/presentation/providers/watchlist_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value);
  }

  void _searchFromHistory(String query) {
    _controller.text = query;
    ref.read(searchQueryProvider.notifier).setQuery(query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = ref.watch(searchQueryProvider);
    final searchAsync = ref.watch(searchProvider(SearchRequest(
      query: query,
      isManga: appState.isMangaMode,
    )));
    final results = searchAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <MediaBase>[],
    );
    final loading = query.trim().isNotEmpty && searchAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: (val) {
            final uid = _uid;
            final trimmed = val.trim();
            if (trimmed.isNotEmpty && uid != null) {
              ref
                  .read(searchActionsProvider)
                  .addSearchTerm(uid, trimmed)
                  .ignore();
            }
          },
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText:
                appState.isMangaMode ? 'Search manga...' : 'Search anime...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).setQuery('');
                    },
                  )
                : const Icon(Icons.search, color: Colors.white24),
          ),
        ),
      ),
      body: loading
          ? const SearchShimmer()
          : results.isEmpty
              ? query.isEmpty
                  ? _buildRecentSearchChips()
                  : _buildEmptyState(colorScheme)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  itemCount: results.length,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemBuilder: (_, i) {
                    return _SearchMediaCard(
                      media: results[i],
                      isManga: appState.isMangaMode,
                      onTap: () {
                        final uid = _uid;
                        if (_controller.text.trim().isNotEmpty && uid != null) {
                          ref
                              .read(searchActionsProvider)
                              .addSearchTerm(uid, _controller.text)
                              .ignore();
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
            'No results for "${ref.watch(searchQueryProvider).trim()}"',
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
    if (uid == null)
      return const Center(
          child: Text('Sign in to see history',
              style: TextStyle(color: Colors.white38)));

    return ref.watch(recentSearchesProvider(uid)).when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white10)),
          error: (error, _) {
            debugPrint('Search history error: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'History Error: $error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
          data: (history) {
            if (history.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded,
                        size: 64, color: Colors.white.withValues(alpha: 0.05)),
                    const SizedBox(height: 16),
                    Text(
                        'Search for your favorite ${appState.isMangaMode ? "manga" : "anime"}',
                        style: const TextStyle(color: Colors.white38)),
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
                          ref
                              .read(searchActionsProvider)
                              .clearSearchHistory(uid);
                          snacks.showSuccess(context, 'Search history cleared');
                        },
                        child: const Text('Clear All',
                            style:
                                TextStyle(color: Colors.amber, fontSize: 13)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
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

class _SearchMediaCard extends ConsumerWidget {
  final MediaBase media;
  final bool isManga;
  final VoidCallback onTap;
  const _SearchMediaCard(
      {required this.media, required this.isManga, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverAsync = ref.watch(anilistCoverImageProvider(CoverImageRequest(
      malId: media.malId,
      title: media.displayTitle,
      isManga: isManga,
    )));
    final anilistImageUrl = coverAsync.maybeWhen(
      data: (url) => url,
      orElse: () => null,
    );
    final loadingAnilist =
        kIsWeb && coverAsync.isLoading && anilistImageUrl == null;

    return PinterestMenuWrapper(
      actions: [
        PinterestMenuAction(
            icon: Icons.bookmark_add_rounded,
            label: 'Watchlist',
            onAction: () async {
              final actions = ref.read(watchlistActionsProvider);
              final uid = actions.currentUserId;
              if (uid == null) {
                snacks.showError(
                    context, 'Please log in to manage your watchlist.');
                return;
              }
              if (media.malId == null) {
                snacks.showError(
                    context, 'Cannot manage watchlist for this item (No ID).');
                return;
              }
              final entry =
                  await actions.getEntry(uid, media.malId!, isManga: isManga);

              dynamic currentStatus;
              if (entry != null) {
                currentStatus = isManga
                    ? ReadStatus.fromString(entry['status'])
                    : WatchStatus.fromString(entry['status']);
              }

              if (context.mounted) {
                await showMediaStatusSheet(
                  context,
                  media: media,
                  isManga: isManga,
                  currentStatus: currentStatus,
                );
              }
            }),
        PinterestMenuAction(
            icon: Icons.info_outline_rounded,
            label: 'Details',
            onAction: () {
              if (media.malId == null) {
                snacks.showError(context, 'Detail unavailable (No ID)');
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DetailScreen(malId: media.malId, isManga: isManga)),
                );
              }
            }),
      ],
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 44,
            height: 60,
            color: colorScheme.surfaceContainerHighest,
            child: (loadingAnilist && anilistImageUrl == null)
                ? const ShimmerSkeleton(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0)
                : PremiumImage(
                    imageUrl: anilistImageUrl ?? media.displayImageUrl,
                    title: media.displayTitle,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        title: Text(media.displayTitle,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${media.scoreText} · ${media.mediaProgressText}',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: media.genres.isNotEmpty
            ? Chip(
                label: Text(media.genres.first,
                    style: const TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : null,
        onTap: () {
          onTap();
          if (media.malId == null) {
            snacks.showError(context, 'Detail unavailable (No ID)');
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DetailScreen(malId: media.malId, isManga: isManga),
            ),
          );
        },
      ),
    );
  }
}
