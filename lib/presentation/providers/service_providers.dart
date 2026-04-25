import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animatch/data/sources/remote/anilist_service.dart';
import 'package:animatch/data/sources/local/cache_service.dart';
import 'package:animatch/data/sources/firebase/firebase_service.dart';
import 'package:animatch/data/sources/remote/jikan_service.dart';
import 'package:animatch/data/repositories/anime_repository.dart';
import 'package:animatch/data/repositories/watchlist_repository.dart';

final anilistServiceProvider = Provider<AnilistService>((ref) {
  return AnilistService();
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final jikanServiceProvider = Provider<JikanService>((ref) {
  return JikanService();
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  return AnimeRepositoryImpl(
    jikanService: ref.watch(jikanServiceProvider),
    anilistService: ref.watch(anilistServiceProvider),
    cacheService: ref.watch(cacheServiceProvider),
  );
});

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepositoryImpl(
    firebaseService: ref.watch(firebaseServiceProvider),
  );
});
