import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/data/models/manga.dart';
import 'package:animatch/data/models/media_base.dart';
import 'package:animatch/data/repositories/watchlist_repository.dart';
import 'package:animatch/presentation/providers/service_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final watchlistProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, WatchlistFilter>(
  (ref, filter) {
    final watchlistRepository = ref.watch(watchlistRepositoryProvider);
    if (filter.uid.isEmpty) return Stream.value(const <Map<String, dynamic>>[]);

    return watchlistRepository.getWatchlist(
      filter.uid,
      isManga: filter.isManga,
      watchStatus: filter.watchStatus,
      readStatus: filter.readStatus,
    );
  },
);

final watchlistActionsProvider = Provider<WatchlistActions>((ref) {
  return WatchlistActions(
    watchlistRepository: ref.watch(watchlistRepositoryProvider),
    ref: ref,
  );
});

class WatchlistActions {
  final WatchlistRepository watchlistRepository;
  final Ref ref;

  WatchlistActions({
    required this.watchlistRepository,
    required this.ref,
  });

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> signOut() {
    return watchlistRepository.signOut();
  }

  Future<Map<String, dynamic>?> getEntry(
    String uid,
    int malId, {
    bool isManga = false,
  }) {
    return watchlistRepository.getWatchlistEntry(uid, malId, isManga: isManga);
  }

  Future<void> saveStatus({
    required String uid,
    required MediaBase media,
    required dynamic status,
    required bool isManga,
  }) async {
    if (isManga) {
      final readStatus = status as ReadStatus;
      final alreadyIn = await watchlistRepository.getWatchlistEntry(
        uid,
        media.malId,
        isManga: true,
      );
      if (alreadyIn != null) {
        await watchlistRepository.updateStatus(
          uid,
          media.malId,
          readStatus.name,
          isManga: true,
        );
      } else {
        await watchlistRepository.addToWatchlist(
            uid,
            {
              'malId': media.malId,
              'title': media.displayTitle,
              'imageUrl': media.displayImageUrl,
              'score': media.score,
              'status': readStatus.name,
              'type': 'manga',
              'chapters': media.chapters,
              'volumes': media is Manga ? media.volumes : null,
            },
            isManga: true);
      }
    } else {
      final watchStatus = status as WatchStatus;
      final alreadyIn = await watchlistRepository.getWatchlistEntry(
        uid,
        media.malId,
      );
      if (alreadyIn != null) {
        await watchlistRepository.updateStatus(
          uid,
          media.malId,
          watchStatus.name,
        );
      } else {
        await watchlistRepository.addToWatchlist(uid, {
          'malId': media.malId,
          'title': media.displayTitle,
          'imageUrl': media.displayImageUrl,
          'score': media.score,
          'status': watchStatus.name,
          'type': 'anime',
          'episodes': media.episodes,
        });
      }
    }

    ref.invalidate(watchlistProvider);
  }

  Future<void> remove({
    required String uid,
    required int malId,
    required bool isManga,
  }) async {
    await watchlistRepository.removeFromWatchlist(
      uid,
      malId,
      isManga: isManga,
    );
    ref.invalidate(watchlistProvider);
  }

  Future<void> saveRating({
    required String uid,
    required int malId,
    required double rating,
    required String review,
    required bool isManga,
  }) async {
    await watchlistRepository.updateRating(
      uid,
      malId,
      rating,
      review,
      isManga: isManga,
    );
    ref.invalidate(watchlistProvider);
  }

  Future<void> updateMissingTotals({
    required String uid,
    required int malId,
    required bool isManga,
  }) async {
    final animeRepository = ref.read(animeRepositoryProvider);
    if (isManga) {
      final detail = await animeRepository.getMangaDetail(malId);
      await watchlistRepository.updateMangaTotals(
        uid,
        malId,
        chapters: detail.chapters,
        volumes: detail.volumes,
      );
    } else {
      final detail = await animeRepository.getAnimeDetail(malId);
      await watchlistRepository.updateAnimeTotals(uid, malId, detail.episodes);
    }
  }
}

@immutable
class WatchlistFilter {
  final String uid;
  final bool isManga;
  final WatchStatus? watchStatus;
  final ReadStatus? readStatus;

  const WatchlistFilter({
    required this.uid,
    required this.isManga,
    this.watchStatus,
    this.readStatus,
  });

  @override
  bool operator ==(Object other) {
    return other is WatchlistFilter &&
        other.uid == uid &&
        other.isManga == isManga &&
        other.watchStatus == watchStatus &&
        other.readStatus == readStatus;
  }

  @override
  int get hashCode => Object.hash(uid, isManga, watchStatus, readStatus);
}
