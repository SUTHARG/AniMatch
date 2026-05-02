import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/anime.dart';
import '../../data/models/hianime_models.dart';
import '../providers/watch_provider.dart';
import '../providers/watchlist_provider.dart';

class WatchScreen extends ConsumerStatefulWidget {
  final Anime anime;
  final int initialEpisode;

  const WatchScreen({
    super.key,
    required this.anime,
    this.initialEpisode = 1,
  });

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Timer? _progressTimer;
  String? _currentSourceUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(watchProvider.notifier).init(
            widget.anime,
            widget.initialEpisode,
          );
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _initPlayer(HianimeStreamSources sources) {
    final url = sources.bestSource?.url;
    if (url == null || url == _currentSourceUrl) return;
    _currentSourceUrl = url;

    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _progressTimer?.cancel();

    final videoController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: sources.headers,
    );

    videoController.initialize().then((_) {
      if (!mounted) return;
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowedScreenSleep: false,
        deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6C5CE7),
          handleColor: const Color(0xFF6C5CE7),
          backgroundColor: Colors.white24,
          bufferedColor: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
        ),
      );

      videoController.addListener(() {
        if (!mounted) return;
        if (videoController.value.isInitialized &&
            videoController.value.position >= videoController.value.duration &&
            videoController.value.duration > Duration.zero) {
          final notifier = ref.read(watchProvider.notifier);
          if (ref.read(watchProvider).hasNext) {
            _saveProgress();
            notifier.nextEpisode();
          }
        }
      });

      setState(() {
        _videoPlayerController = videoController;
        _chewieController = chewieController;
      });
      _startProgressTimer();
      _saveProgress();
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final pos = _videoPlayerController?.value.position.inMilliseconds;
      if (pos != null) {
        final seconds = pos / 1000.0;
        ref.read(watchProvider.notifier).updatePlaybackPosition(seconds);
      }
    });
  }

  void _saveProgress() async {
    final episode = ref.read(watchProvider).currentEpisode;
    final malId = widget.anime.malId.toString();
    final actions = ref.read(watchlistActionsProvider);
    final uid = actions.currentUserId;
    if (uid != null) {
      final entry = await actions.getEntry(uid, int.parse(malId));
      if (entry != null) {
        actions.updateProgress(malId: malId, episodeProgress: episode);
      }
    }
  }

  void _skipTo(AniSkipInterval interval) {
    _videoPlayerController?.seekTo(interval.end);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchProvider);

    // Init player when sources arrive
    state.sources.whenData((sources) {
      if (sources != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _initPlayer(sources);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            _TopBar(
              anime: widget.anime,
              state: state,
              onBack: () => Navigator.of(context).pop(),
            ),

            // ── Video area ───────────────────────────────────────────────
            _VideoArea(
              state: state,
              playerController: _chewieController,
              onSkip: _skipTo,
            ),

            // ── SUB / DUB toggle ─────────────────────────────────────────
            _CategoryBar(
              state: state,
              onSwitch: (cat) =>
                  ref.read(watchProvider.notifier).switchCategory(cat),
            ),

            // ── Episode grid ─────────────────────────────────────────────
            Expanded(
              child: _EpisodePanel(
                state: state,
                onEpisodeTap: (ep) =>
                    ref.read(watchProvider.notifier).loadEpisode(ep),
                onPrev: state.hasPrev
                    ? () => ref.read(watchProvider.notifier).prevEpisode()
                    : null,
                onNext: state.hasNext
                    ? () => ref.read(watchProvider.notifier).nextEpisode()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final Anime anime;
  final WatchState state;
  final VoidCallback onBack;
  const _TopBar(
      {required this.anime, required this.state, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anime.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Episode ${state.currentEpisode} / ${state.displayEpisodeCount}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video Area ─────────────────────────────────────────────────────────────
class _VideoArea extends StatelessWidget {
  final WatchState state;
  final ChewieController? playerController;
  final void Function(AniSkipInterval) onSkip;

  const _VideoArea({
    required this.state,
    required this.playerController,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.width * 9 / 16;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        children: [
          // Player or loading/error state
          state.sources.when(
            loading: () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  SizedBox(height: 12),
                  Text('Fetching stream...',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  const Text('Stream error',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                  Text(e.toString(),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            data: (sources) {
              if (sources == null || sources.sources.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off_rounded,
                          color: Colors.white30, size: 44),
                      SizedBox(height: 12),
                      Text('No stream available',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Try switching to SUB or DUB above',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                );
              }
              if (playerController == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                );
              }
              return Chewie(controller: playerController!);
            },
          ),

          // ── AniSkip overlay button ───────────────────────────────────
          if (state.activeSkipInterval != null)
            Positioned(
              bottom: 60,
              right: 16,
              child: _SkipButton(
                interval: state.activeSkipInterval!,
                onSkip: onSkip,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Skip Button ────────────────────────────────────────────────────────────
class _SkipButton extends StatelessWidget {
  final AniSkipInterval interval;
  final void Function(AniSkipInterval) onSkip;
  const _SkipButton({required this.interval, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final label =
        interval.skipType == 'op' ? 'Skip Opening' : 'Skip Ending';
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => onSkip(interval),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fast_forward_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category Bar (SUB / DUB) ───────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  final WatchState state;
  final void Function(WatchCategory) onSwitch;
  const _CategoryBar({required this.state, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111118),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Audio:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 12),
          _Chip(
            label: 'SUB',
            active: state.category == WatchCategory.sub,
            onTap: () => onSwitch(WatchCategory.sub),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'DUB',
            active: state.category == WatchCategory.dub,
            onTap: () => onSwitch(WatchCategory.dub),
          ),
          const Spacer(),
          if (state.skipTimes.found)
            const Row(
              children: [
                Icon(Icons.skip_next_rounded,
                    color: Color(0xFF6C5CE7), size: 14),
                SizedBox(width: 4),
                Text('AniSkip ready',
                    style:
                        TextStyle(color: Color(0xFF6C5CE7), fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6C5CE7) : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Episode Panel ──────────────────────────────────────────────────────────
class _EpisodePanel extends StatelessWidget {
  final WatchState state;
  final void Function(int) onEpisodeTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _EpisodePanel({
    required this.state,
    required this.onEpisodeTap,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final count = state.displayEpisodeCount;
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                const Text('Episodes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                _NavBtn(
                    icon: Icons.skip_previous_rounded,
                    label: 'Prev',
                    onTap: onPrev),
                const SizedBox(width: 8),
                _NavBtn(
                    icon: Icons.skip_next_rounded,
                    label: 'Next',
                    onTap: onNext),
              ],
            ),
          ),
          Expanded(
            child: state.episodeList.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
              ),
              error: (_, __) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                ),
                itemCount: count,
                itemBuilder: (_, i) => _EpisodeCell(
                  number: i + 1,
                  isCurrent: i + 1 == state.currentEpisode,
                  onTap: () => onEpisodeTap(i + 1),
                ),
              ),
              data: (_) => GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.25,
                ),
                itemCount: count,
                itemBuilder: (_, i) => _EpisodeCell(
                  number: i + 1,
                  isCurrent: i + 1 == state.currentEpisode,
                  isFiller: state.episodeList.value?.episodes
                          .elementAtOrNull(i)
                          ?.isFiller ??
                      false,
                  onTap: () => onEpisodeTap(i + 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeCell extends StatelessWidget {
  final int number;
  final bool isCurrent;
  final bool isFiller;
  final VoidCallback onTap;
  const _EpisodeCell({
    required this.number,
    required this.isCurrent,
    this.isFiller = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF6C5CE7)
              : isFiller
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF1A1A28),
          borderRadius: BorderRadius.circular(6),
          border: isCurrent
              ? Border.all(color: const Color(0xFF6C5CE7), width: 1.5)
              : isFiller
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.1), width: 0.5)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            color: isCurrent
                ? Colors.white
                : isFiller
                    ? Colors.white30
                    : Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
            fontWeight:
                isCurrent ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _NavBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
