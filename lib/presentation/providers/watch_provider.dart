import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/anime.dart';
import '../../data/models/hianime_models.dart';
import '../../data/repositories/streaming_repository.dart';

enum WatchCategory { sub, dub }

class WatchState {
  final int currentEpisode;
  final int malEpisodeCount;        // from Anime model — always available
  final WatchCategory category;
  final AsyncValue<HianimeEpisodeList?> episodeList;
  final AsyncValue<HianimeStreamSources?> sources;
  final AniSkipResult skipTimes;
  final AniSkipInterval? activeSkipInterval; // currently in OP or ED?

  const WatchState({
    this.currentEpisode = 1,
    this.malEpisodeCount = 0,
    this.category = WatchCategory.sub,
    this.episodeList = const AsyncValue.loading(),
    this.sources = const AsyncValue.loading(),
    this.skipTimes = const AniSkipResult(found: false, intervals: []),
    this.activeSkipInterval,
  });

  int get displayEpisodeCount {
    final fromApi = episodeList.value?.totalEpisodes ?? 0;
    if (fromApi > 0) return fromApi;
    return malEpisodeCount > 0 ? malEpisodeCount : 1;
  }

  bool get hasNext => currentEpisode < displayEpisodeCount;
  bool get hasPrev => currentEpisode > 1;

  WatchState copyWith({
    int? currentEpisode,
    int? malEpisodeCount,
    WatchCategory? category,
    AsyncValue<HianimeEpisodeList?>? episodeList,
    AsyncValue<HianimeStreamSources?>? sources,
    AniSkipResult? skipTimes,
    AniSkipInterval? activeSkipInterval,
    bool clearSkipInterval = false,
  }) {
    return WatchState(
      currentEpisode: currentEpisode ?? this.currentEpisode,
      malEpisodeCount: malEpisodeCount ?? this.malEpisodeCount,
      category: category ?? this.category,
      episodeList: episodeList ?? this.episodeList,
      sources: sources ?? this.sources,
      skipTimes: skipTimes ?? this.skipTimes,
      activeSkipInterval: clearSkipInterval
          ? null
          : activeSkipInterval ?? this.activeSkipInterval,
    );
  }
}

class WatchNotifier extends Notifier<WatchState> {
  late Anime _anime;

  @override
  WatchState build() => const WatchState();

  Future<void> init(Anime anime, int startEpisode) async {
    _anime = anime;
    state = WatchState(
      currentEpisode: startEpisode,
      malEpisodeCount: anime.episodes ?? 0,
    );

    // Load episode list and first episode sources in parallel
    await Future.wait([
      _loadEpisodeList(),
      _loadSources(startEpisode),
    ]);

    // Load skip times in background (non-blocking)
    _loadSkipTimes(startEpisode);
  }

  Future<void> _loadEpisodeList() async {
    state = state.copyWith(episodeList: const AsyncValue.loading());
    try {
      final list = await StreamingRepository.instance.getEpisodeList(_anime);
      state = state.copyWith(episodeList: AsyncValue.data(list));
    } catch (e, st) {
      state = state.copyWith(episodeList: AsyncValue.error(e, st));
    }
  }

  Future<void> _loadSources(int episode) async {
    state = state.copyWith(sources: const AsyncValue.loading());
    try {
      final src = await StreamingRepository.instance.getStreamingSources(
        anime: _anime,
        episodeNumber: episode,
        category: state.category.name,
      );
      state = state.copyWith(sources: AsyncValue.data(src));
    } catch (e, st) {
      state = state.copyWith(sources: AsyncValue.error(e, st));
    }
  }

  Future<void> _loadSkipTimes(int episode) async {
    final result = await StreamingRepository.instance.getSkipTimes(
      malId: _anime.malId!,
      episode: episode,
    );
    state = state.copyWith(skipTimes: result);
  }

  Future<void> loadEpisode(int episode) async {
    state = state.copyWith(
      currentEpisode: episode,
      sources: const AsyncValue.loading(),
      skipTimes: const AniSkipResult(found: false, intervals: []),
      clearSkipInterval: true,
    );
    await _loadSources(episode);
    _loadSkipTimes(episode);
  }

  void nextEpisode() {
    if (state.hasNext) loadEpisode(state.currentEpisode + 1);
  }

  void prevEpisode() {
    if (state.hasPrev) loadEpisode(state.currentEpisode - 1);
  }

  void switchCategory(WatchCategory cat) {
    if (cat == state.category) return;
    state = state.copyWith(
      category: cat,
      sources: const AsyncValue.loading(),
    );
    _loadSources(state.currentEpisode);
  }

  // Called by WatchScreen every second with current playback position
  void updatePlaybackPosition(double positionSeconds) {
    final skip = state.skipTimes;
    if (!skip.found) return;

    AniSkipInterval? active;
    for (final interval in skip.intervals) {
      if (interval.isActiveAt(positionSeconds)) {
        active = interval;
        break;
      }
    }

    // Only update state if the active interval changed
    if (active?.skipType != state.activeSkipInterval?.skipType) {
      state = state.copyWith(
        activeSkipInterval: active,
        clearSkipInterval: active == null,
      );
    }
  }

  // Called when user saves progress to Firestore
  // (wire this into watchlistProvider.notifier.updateProgress)
  int get currentEpisode => state.currentEpisode;
}

final watchProvider =
    NotifierProvider.autoDispose<WatchNotifier, WatchState>(
  WatchNotifier.new,
);
