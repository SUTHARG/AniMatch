import 'package:animatch/data/sources/firebase/firebase_service.dart';

abstract class WatchlistRepository {
  Stream<List<Map<String, dynamic>>> getWatchlist(
    String userId, {
    bool isManga = false,
    WatchStatus? watchStatus,
    ReadStatus? readStatus,
  });

  Future<void> addToWatchlist(
    String userId,
    Map<String, dynamic> data, {
    bool isManga = false,
  });

  Future<void> updateStatus(
    String userId,
    int malId,
    String status, {
    bool isManga = false,
  });

  Future<void> updateRating(
    String userId,
    int malId,
    double rating,
    String review, {
    bool isManga = false,
  });

  Future<void> removeFromWatchlist(
    String userId,
    int malId, {
    bool isManga = false,
  });

  Future<Map<String, dynamic>?> getWatchlistEntry(
    String userId,
    int malId, {
    bool isManga = false,
  });

  Future<void> updateEpisodeProgress(String userId, int malId, int episode);

  Future<void> updateAnimeTotals(String userId, int malId, int? episodes);

  Future<void> updateMangaTotals(
    String userId,
    int malId, {
    int? chapters,
    int? volumes,
  });

  Stream<List<String>> getRecentSearches(String userId);
  Future<void> addSearchTerm(String userId, String term);
  Future<void> clearSearchHistory(String userId);
  Future<void> signOut();
}

class WatchlistRepositoryImpl implements WatchlistRepository {
  final FirebaseService firebaseService;

  WatchlistRepositoryImpl({
    required this.firebaseService,
  });

  @override
  Stream<List<Map<String, dynamic>>> getWatchlist(
    String userId, {
    bool isManga = false,
    WatchStatus? watchStatus,
    ReadStatus? readStatus,
  }) {
    if (isManga) {
      return firebaseService.mangaWatchlistStream(
        uid: userId,
        filter: readStatus,
      );
    }

    return firebaseService.watchlistStream(
      uid: userId,
      filter: watchStatus,
    );
  }

  @override
  Future<void> addToWatchlist(
    String userId,
    Map<String, dynamic> data, {
    bool isManga = false,
  }) {
    if (isManga) {
      return firebaseService.addToMangaWatchlist(userId, data);
    }

    return firebaseService.addToWatchlist(userId, data);
  }

  @override
  Future<void> updateStatus(
    String userId,
    int malId,
    String status, {
    bool isManga = false,
  }) {
    if (isManga) {
      return firebaseService.updateMangaWatchStatus(userId, malId, status);
    }

    return firebaseService.updateWatchStatus(userId, malId, status);
  }

  @override
  Future<void> updateRating(
    String userId,
    int malId,
    double rating,
    String review, {
    bool isManga = false,
  }) {
    return firebaseService.saveRating(
      userId,
      malId,
      rating,
      review,
      isManga: isManga,
    );
  }

  @override
  Future<void> removeFromWatchlist(
    String userId,
    int malId, {
    bool isManga = false,
  }) {
    if (isManga) {
      return firebaseService.removeFromMangaWatchlist(userId, malId);
    }

    return firebaseService.removeFromWatchlist(userId, malId);
  }

  @override
  Future<Map<String, dynamic>?> getWatchlistEntry(
    String userId,
    int malId, {
    bool isManga = false,
  }) {
    return firebaseService.getWatchlistEntry(
      userId,
      malId,
      isManga: isManga,
    );
  }

  @override
  Future<void> updateEpisodeProgress(String userId, int malId, int episode) {
    return firebaseService.updateEpisodeProgress(userId, malId, episode);
  }

  @override
  Future<void> updateAnimeTotals(String userId, int malId, int? episodes) {
    return firebaseService.updateAnimeTotals(userId, malId, episodes);
  }

  @override
  Future<void> updateMangaTotals(
    String userId,
    int malId, {
    int? chapters,
    int? volumes,
  }) {
    return firebaseService.updateMangaTotals(
      userId,
      malId,
      chapters: chapters,
      volumes: volumes,
    );
  }

  @override
  Stream<List<String>> getRecentSearches(String userId) {
    return firebaseService.getRecentSearchesStream(userId);
  }

  @override
  Future<void> addSearchTerm(String userId, String term) {
    return firebaseService.addSearchTerm(userId, term);
  }

  @override
  Future<void> clearSearchHistory(String userId) {
    return firebaseService.clearSearchHistory(userId);
  }

  @override
  Future<void> signOut() {
    return firebaseService.signOut();
  }
}
