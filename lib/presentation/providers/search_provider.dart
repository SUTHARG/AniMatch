import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/data/repositories/watchlist_repository.dart';
import 'package:animatch/presentation/providers/service_providers.dart';

final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

final searchProvider =
    FutureProvider.autoDispose.family<List<MediaBase>, SearchRequest>(
  (ref, request) async {
    final query = request.query.trim();
    if (query.isEmpty) return const <MediaBase>[];

    var disposed = false;
    ref.onDispose(() => disposed = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (disposed) return const <MediaBase>[];

    final animeRepository = ref.watch(animeRepositoryProvider);
    try {
      if (request.isManga) {
        return animeRepository.searchManga(query);
      }
      return animeRepository.searchAnime(query);
    } catch (error) {
      throw Exception(
          'Failed to search ${request.isManga ? 'manga' : 'anime'}: $error');
    }
  },
);

final recentSearchesProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, uid) {
  return ref.watch(watchlistRepositoryProvider).getRecentSearches(uid);
});

final searchActionsProvider = Provider<SearchActions>((ref) {
  return SearchActions(ref.watch(watchlistRepositoryProvider));
});

final anilistCoverImageProvider =
    FutureProvider.autoDispose.family<String?, CoverImageRequest>(
  (ref, request) async {
    if (!kIsWeb) return null;

    final animeRepository = ref.watch(animeRepositoryProvider);
    return animeRepository
        .getCoverImage(
          request.malId,
          request.title,
          isManga: request.isManga,
        )
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
  },
);

class SearchActions {
  final WatchlistRepository _watchlistRepository;

  SearchActions(this._watchlistRepository);

  Future<void> addSearchTerm(String uid, String term) {
    return _watchlistRepository.addSearchTerm(uid, term);
  }

  Future<void> clearSearchHistory(String uid) {
    return _watchlistRepository.clearSearchHistory(uid);
  }
}

@immutable
class SearchRequest {
  final String query;
  final bool isManga;

  const SearchRequest({
    required this.query,
    required this.isManga,
  });

  @override
  bool operator ==(Object other) {
    return other is SearchRequest &&
        other.query == query &&
        other.isManga == isManga;
  }

  @override
  int get hashCode => Object.hash(query, isManga);
}

@immutable
class CoverImageRequest {
  final int? malId;
  final String title;
  final bool isManga;

  const CoverImageRequest({
    required this.malId,
    required this.title,
    required this.isManga,
  });

  @override
  bool operator ==(Object other) {
    return other is CoverImageRequest &&
        other.malId == malId &&
        other.title == title &&
        other.isManga == isManga;
  }

  @override
  int get hashCode => Object.hash(malId, title, isManga);
}
