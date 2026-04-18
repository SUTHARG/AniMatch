import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled1/anilist_service.dart';
import 'anime.dart';
import 'manga.dart';
import 'media_base.dart';
import 'jikan_service.dart';
import 'firebase_service.dart';
import 'login_screen.dart';
import 'watch_status_sheet.dart';
import 'rating_sheet.dart';
import 'streaming_utils.dart';
import 'floating_notification.dart';
import 'image_utils.dart';
import 'shimmer_skeletons.dart';

class DetailScreen extends StatefulWidget {
  final int malId;
  final bool isManga;
  const DetailScreen({super.key, required this.malId, this.isManga = false});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final JikanService _jikan = JikanService();
  final FirebaseService _firebase = FirebaseService();
  final AnilistService _anilist = AnilistService();

  MediaBase? _media;
  String? _anilistImageUrl;
  bool _loading = true;
  bool _showWhereToWatch = false;
  WatchStatus? _watchStatus;
  ReadStatus? _readStatus;
  int _progress = 0; // either episode or chapter
  double? _userRating;
  String? _userReview;
  List<MediaBase> _similar = [];
  List<dynamic> _characters = []; // AnimeCharacter or MangaCharacter
  String? _error;
  bool _loadingAnilist = false;
  
  MediaBase get media => _media!;

  late final Future<List<StreamingLink>> _streamingFuture;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _streamingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _streamingFuture = _getStreamingLinks();
    _load();
  }

  Future<List<StreamingLink>> _getStreamingLinks() async {
    if (widget.isManga) return []; // Manga doesn't have streaming links typically through this endpoint

    final uid = _firebase.currentUser?.uid;
    if (uid != null) {
      try {
        final cached = await _firebase.getCachedStreamingLinks(uid, widget.malId);
        if (cached != null) {
          return cached.map((e) => StreamingLink.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }
    final links = await _jikan.fetchStreamingLinks(widget.malId);
    if (uid != null && links.isNotEmpty) {
      _firebase.cacheStreamingLinks(uid, widget.malId, links).ignore();
    }
    return links;
  }

  Future<void> _launchUrl(String rawUrl, {String? platformName, BuildContext? ctx}) async {
    final resolvedRaw = platformName != null ? resolveStreamingUrl(platformName, rawUrl) : rawUrl;
    final resolved = Uri.tryParse(resolvedRaw);
    final web = Uri.tryParse(rawUrl);
    final mal = Uri.parse('https://myanimelist.net/anime/${widget.malId}');

    Future<bool> tryLaunch(Uri? uri) async {
      if (uri == null) return false;
      try {
        if (await canLaunchUrl(uri)) {
          final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
          return success;
        }
      } catch (_) {}
      return false;
    }

    // Try primary resolved link (native app scheme)
    if (await tryLaunch(resolved)) return;
    
    // Fallback to web link if resolved was different
    if (resolved != web) {
      if (await tryLaunch(web)) return;
    }
    
    // Final fallback to MAL page
    await tryLaunch(mal);

    if (ctx != null && ctx.mounted) {
      FloatingNotification.show(
        ctx,
        title: 'Opening Alternative',
        message: 'Opening MAL instead of primary link.',
        icon: Icons.open_in_new_rounded,
      );
    }
  }

  Future<void> _load() async {
    try {
      // 1. Fetch core detail
      MediaBase media;
      if (widget.isManga) {
        final manga = await _jikan.getMangaDetail(widget.malId);
        media = manga;
        // if (_firebase.isLoggedIn) _firebase.addToHistory(manga); // History not implemented for manga yet
      } else {
        final anime = await _jikan.getAnimeDetail(widget.malId);
        media = anime;
        if (_firebase.isLoggedIn) _firebase.addToHistory(anime);
      }

      Map<String, dynamic>? entry;
      if (_firebase.isLoggedIn) entry = await _firebase.getWatchlistEntry(widget.malId, isManga: widget.isManga);

      if (mounted) {
        setState(() {
          _media = media;
          if (widget.isManga) {
             _readStatus = entry != null ? ReadStatus.fromString(entry['status'] as String?) : null;
             _progress = entry?['chapterProgress'] as int? ?? 0;
          } else {
             _watchStatus = entry != null ? WatchStatus.fromString(entry['status'] as String?) : null;
             _progress = entry?['episodeProgress'] as int? ?? 0;
          }
          _userRating = (entry?['userRating'] as num?)?.toDouble();
          _userReview = entry?['userReview'] as String?;
        });
      }

      // 2. Fetch similar (awaited sequentially to prevent 429)
      if (widget.isManga) {
        final similarList = await _jikan.getSimilarManga(widget.malId);
        if (mounted) setState(() => _similar = similarList);
      } else {
        final similarList = await _jikan.getSimilarAnime(widget.malId);
        if (mounted) setState(() => _similar = similarList);
      }

      // 3. Fetch characters (awaited sequentially)
      if (widget.isManga) {
        final charList = await _jikan.getMangaCharacters(widget.malId);
        if (mounted) setState(() => _characters = charList);
      } else {
        final charList = await _jikan.getCharacters(widget.malId);
        if (mounted) setState(() => _characters = charList);
      }

      // 4. Fetch CORS-friendly cover from AniList on Web
      if (kIsWeb) {
        setState(() => _loadingAnilist = true);
        final url = await _anilist.getCoverImageByMalId(widget.malId) ?? await _anilist.getCoverImageByTitle(media.displayTitle);
        if (mounted) {
          setState(() {
            if (url != null) _anilistImageUrl = url;
            _loadingAnilist = false;
          });
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _scrollToStreaming() {
    if (!_showWhereToWatch) {
      setState(() => _showWhereToWatch = true);
    }
    // Delay slightly to allow the section to be built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_streamingKey.currentContext != null) {
        Scrollable.ensureVisible(_streamingKey.currentContext!, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      }
    });
  }

  Future<void> _openStatusSheet() async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    final result = await showMediaStatusSheet(
      context, 
      media: _media!, 
      isManga: widget.isManga,
      currentStatus: widget.isManga ? _readStatus : _watchStatus,
    );
    if (mounted) {
      setState(() {
        if (widget.isManga) {
          _readStatus = result;
        } else {
          _watchStatus = result;
        }
      });
    }
  }

  Future<void> _openRatingSheet() async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    await showRatingSheet(
      context,
      malId: widget.malId,
      title: _media!.displayTitle,
      isManga: widget.isManga,
      currentRating: _userRating,
      currentReview: _userReview,
    );
    final data = await _firebase.getRatingAndReview(widget.malId, isManga: widget.isManga);
    if (mounted && data != null) {
      setState(() {
        _userRating = (data['rating'] as num?)?.toDouble();
        _userReview = data['review'] as String?;
      });
    }
  }

  Future<void> _updateProgress(int val) async {
    if (!_firebase.isLoggedIn) { _promptLogin(); return; }
    if (widget.isManga) {
      await _firebase.updateChapterProgress(widget.malId, val);
    } else {
      await _firebase.updateEpisodeProgress(widget.malId, val);
    }
    if (mounted) setState(() => _progress = val);
  }

  void _promptLogin() {
    FloatingNotification.show(
      context,
      title: 'Sign In Required',
      message: 'Log in to track this ${widget.isManga ? 'manga' : 'anime'} in your list.',
      actionLabel: 'Login',
      icon: Icons.account_circle_rounded,
      onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
    );
  }

  void _share() {
    final media = _media;
    if (media == null) return;
    final type = widget.isManga ? 'Manga' : 'Anime';
    final progress = media.mediaProgressText;
    final text = 'Check out "${media.displayTitle}" on AniMatch!\nType: $type · Score: ${media.scoreText} · $progress';
    Clipboard.setData(ClipboardData(text: text));
    
    FloatingNotification.show(
      context,
      title: 'Shared!',
      message: 'Link copied to clipboard.',
      icon: Icons.check_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_loading) return const Scaffold(body: DetailShimmer());
    if (_error != null || _media == null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_error ?? 'Failed')));

    final media = _media!;
    final inList = widget.isManga ? _readStatus != null : _watchStatus != null;
    
    int? total;
    if (widget.isManga) {
      total = (media as Manga).chapters;
    } else {
      total = (media as Anime).episodes;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white), onPressed: _share)],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 400, width: double.infinity,
                  child: (_loadingAnilist && _anilistImageUrl == null) 
                    ? const ShimmerSkeleton(width: double.infinity, height: double.infinity, borderRadius: 0)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          PremiumImage(
                            imageUrl: _anilistImageUrl ?? media.displayImageUrl,
                            title: media.displayTitle,
                            fit: BoxFit.cover,
                          ),
                          Container(color: Colors.black.withOpacity(0.4)),
                        ],
                      ),
                ),
                Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.4), const Color(0xFF1E1E1E)],
                    ),
                  ),
                ),
                Column(
                  children: [
                    const SizedBox(height: 100),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          if (_loadingAnilist && _anilistImageUrl == null)
                            Container(width: 160, height: 230, color: Colors.black26, child: const Center(child: CircularProgressIndicator()))
                          else
                            PremiumImage(
                              imageUrl: _anilistImageUrl ?? media.displayImageUrl,
                              title: media.displayTitle,
                              width: 160,
                              height: 230,
                              fit: BoxFit.cover,
                            ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              color: Colors.black.withOpacity(0.7),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sensors, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(widget.isManga ? 'Read2gether' : 'Watch2gether', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(media.displayTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!widget.isManga) _Badge(label: (media as Anime).rating?.split(' ').first ?? 'PG-13', color: Colors.white12),
                      _Badge(label: 'HD', color: Colors.amber),
                      _Badge(label: '${widget.isManga ? 'ch' : 'cc'} ${total ?? "?"}', color: const Color(0xFFB1E5D5), textColor: Colors.black),
                      if (widget.isManga) _Badge(label: 'vol ${(media as Manga).volumes ?? "?"}', color: const Color(0xFFE5B1D5), textColor: Colors.black),
                      if (!widget.isManga) _Badge(label: 'mic 1155', color: const Color(0xFFE5B1D5), textColor: Colors.black),
                      Text('•', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      Text(media.mediaTypeBadge, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      if (!widget.isManga) ...[
                        Text('•', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                        Text((media as Anime).duration?.split(' ').first ?? '24m', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.isManga 
                            ? () => _launchUrl('https://mangadex.org/search?q=${Uri.encodeComponent(media.displayTitle)}') 
                            : _scrollToStreaming,
                          icon: Icon(widget.isManga ? Icons.menu_book_rounded : Icons.play_arrow_rounded, color: Colors.black),
                          label: Text(widget.isManga ? 'Read now' : 'Watch now', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openStatusSheet,
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                          label: Text(widget.isManga ? 'Edit Manga List' : 'Edit Watch List',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30))),
                        ),
                      ),
                    ],
                  ),
                  if (_media is Anime && (_media as Anime).trailerUrl != null && (_media as Anime).trailerUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchUrl((_media as Anime).trailerUrl!),
                        icon: const Icon(Icons.movie_creation_outlined,
                            color: Colors.amber),
                        label: const Text('Watch Trailer',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Share this ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                      Text('to your friends', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Align(alignment: Alignment.centerLeft, child: Text('Overview:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white))),
                  const SizedBox(height: 12),
                  Text(_media?.synopsis ?? 'No description available.', style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5)),
                  const SizedBox(height: 24),
                  _DetailItem(label: 'Japanese:', value: (widget.isManga ? (media as Manga).titleJapanese : (media as Anime).titleJapanese) ?? 'N/A'),
                  _DetailItem(label: 'Synonyms:', value: media is Anime ? (media as Anime).synonyms.join(', ') : (media as Manga).synonyms.join(', ')),
                  _DetailItem(label: widget.isManga ? 'Published:' : 'Aired:', value: (widget.isManga ? (media as Manga).publishedString : (media as Anime).airedString) ?? 'N/A'),
                  if (!widget.isManga) _DetailItem(label: 'Premiered:', value: (media as Anime).premiered ?? 'N/A'),
                  if (!widget.isManga) _DetailItem(label: 'Duration:', value: (media as Anime).duration ?? 'N/A'),
                  _DetailItem(label: 'Status:', value: media.isCompleted ? 'Finished' : (media.isOngoing ? (widget.isManga ? 'Publishing' : 'Currently Airing') : 'N/A')),
                  _DetailItem(label: 'MAL Score:', value: media.scoreText),
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerLeft, child: Text('Genres:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white))),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: _media!.genres.map((g) => _GenreChip(label: g)).toList()),
                  const SizedBox(height: 24),
                  if (widget.isManga) ...[
                    _DetailItem(label: 'Authors:', value: (media as Manga).authors.join(', ').isEmpty ? 'N/A' : (media as Manga).authors.join(', ')),
                    _DetailItem(label: 'Serialization:', value: (media as Manga).serializations.join(', ').isEmpty ? 'N/A' : (media as Manga).serializations.join(', ')),
                  ] else ...[
                    _DetailItem(label: 'Studios:', value: (media as Anime).studios.join(', ').isEmpty ? 'N/A' : (media as Anime).studios.join(', ')),
                    _DetailItem(label: 'Producers:', value: (media as Anime).producers.isEmpty ? 'N/A' : (media as Anime).producers.take(3).join(', ')),
                  ],
                  const SizedBox(height: 32),
                  if (inList && ((!widget.isManga && _watchStatus == WatchStatus.watching) || (widget.isManga && _readStatus == ReadStatus.reading)) && total != null) ...[
                    _EpisodeTracker(
                      current: _progress, 
                      total: total, 
                      onChanged: _updateProgress, 
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_userRating != null) ...[
                    _UserRatingCard(rating: _userRating!, review: _userReview, onEdit: _openRatingSheet),
                    const SizedBox(height: 24),
                  ],
                  if (_showWhereToWatch && _media is Anime) ...[
                    _WhereToWatchSection(
                      key: _streamingKey,
                      anime: _media as Anime,
                      streamingFuture: _streamingFuture,
                      showHeader: true,
                      onLaunch: (link) => _launchUrl(link.url, platformName: link.name, ctx: context),
                      onLaunchMal: () => _launchUrl(_media!.malUrl ?? ''),
                    ),
                    const SizedBox(height: 32),
                  ],
                  // Characters Section
                  if (_characters.isNotEmpty) ...[
                    _DetailSectionHeader(title: 'Cast & Characters'),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _characters.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final char = _characters[index];
                          return _CharacterCard(character: char);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // More Like This (Similar Anime)
                  if (_similar.isNotEmpty) ...[
                    _DetailSectionHeader(title: 'More Like This'),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _similar.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = _similar[index];
                          return _SimilarMediaCard(media: item);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Badge({required this.label, required this.color, this.textColor = Colors.white});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  const _GenreChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14))),
        ],
      ),
    );
  }
}

class _EpisodeTracker extends StatelessWidget {
  final int current;
  final int total;
  final ValueChanged<int> onChanged;
  const _EpisodeTracker({required this.current, required this.total, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Text('Episode Progress', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)), const Spacer(), Text('$current / $total', style: const TextStyle(color: Colors.white70))]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Colors.amber))),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(onPressed: current > 0 ? () => onChanged(current - 1) : null, icon: const Icon(Icons.remove_circle_outline, color: Colors.amber)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.amber, inactiveTrackColor: Colors.white10, thumbColor: Colors.amber, overlayColor: Colors.amber.withOpacity(0.2)),
                  child: Slider(value: current.toDouble(), min: 0, max: total.toDouble(), divisions: total > 0 ? total : 1, onChanged: (v) => onChanged(v.round())),
                ),
              ),
              IconButton(onPressed: current < total ? () => onChanged(current + 1) : null, icon: const Icon(Icons.add_circle_outline, color: Colors.amber)),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserRatingCard extends StatelessWidget {
  final double rating;
  final String? review;
  final VoidCallback onEdit;
  const _UserRatingCard({required this.rating, this.review, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 24), const SizedBox(width: 8), const Text('Your Rating', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(), Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)), const Text(' / 10', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 12), IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.white70, size: 20)),
            ],
          ),
          if (review != null && review!.isNotEmpty) ...[const SizedBox(height: 8), Text(review!, style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic))],
        ],
      ),
    );
  }
}

class _WhereToWatchSection extends StatelessWidget {
  final Anime anime;
  final Future<List<StreamingLink>> streamingFuture;
  final bool showHeader;
  final void Function(StreamingLink) onLaunch;
  final VoidCallback onLaunchMal;

  const _WhereToWatchSection({super.key, required this.anime, required this.streamingFuture, this.showHeader = true, required this.onLaunch, required this.onLaunchMal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[const Divider(height: 32), Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text('🎬 Where to Watch', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)))],
        FutureBuilder<List<StreamingLink>>(
          future: streamingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()));
            final links = snapshot.data ?? [];
            if (links.isEmpty) return _EmptyStreamingState(anime: anime, colorScheme: colorScheme, onLaunchMal: onLaunchMal);
            return Column(
              children: [
                ...links.asMap().entries.map((e) => _StreamingLinkTile(link: e.value, index: e.key, animeTitle: anime.displayTitle, onTap: () => onLaunch(e.value))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [colorScheme.primary.withOpacity(0.85), colorScheme.secondary.withOpacity(0.85)]), borderRadius: BorderRadius.circular(16)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: onLaunchMal, borderRadius: BorderRadius.circular(16), child: const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.link, color: Colors.white), SizedBox(width: 8), Text('View on MyAnimeList', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyStreamingState extends StatelessWidget {
  final Anime anime;
  final ColorScheme colorScheme;
  final VoidCallback onLaunchMal;
  const _EmptyStreamingState({required this.anime, required this.colorScheme, required this.onLaunchMal});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Colors.white.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.live_tv_outlined, size: 40, color: Colors.white24), const SizedBox(height: 12), const Text('No streaming links available', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16), TextButton.icon(onPressed: onLaunchMal, icon: const Icon(Icons.open_in_new), label: const Text('Open on MyAnimeList')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingLinkTile extends StatelessWidget {
  final StreamingLink link;
  final int index;
  final String animeTitle;
  final VoidCallback onTap;
  const _StreamingLinkTile({required this.link, required this.index, required this.animeTitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white10)),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _StreamingIcon(link: link), const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(link.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(link.url, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12))])),
                const Icon(Icons.play_arrow, color: Colors.amber),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingIcon extends StatelessWidget {
  final StreamingLink link;
  const _StreamingIcon({required this.link});
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use a themed material icon for web to bypass CORS favicon issues
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.play_circle_fill_rounded, color: Colors.amber, size: 20),
      );
    }
    final host = Uri.tryParse(link.url)?.host ?? '';
    final faviconUrl = 'https://www.google.com/s2/favicons?sz=64&domain=$host';
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 32, height: 32, child: PremiumImage(imageUrl: faviconUrl, fit: BoxFit.cover)),
    );
  }
}

class _DetailSectionHeader extends StatelessWidget {
  final String title;
  const _DetailSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final dynamic character;
  const _CharacterCard({required this.character});

  @override
  Widget build(BuildContext context) {
    // Both AnimeCharacter and MangaCharacter have imageUrl, name, and role fields
    final String imageUrl = character.imageUrl;
    final String name = character.name;
    final String role = character.role;

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              image: DecorationImage(
                image: NetworkImage(ImageUtils.getCORSUrl(imageUrl)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(role, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
        ],
      ),
    );
  }
}

class _SimilarMediaCard extends StatelessWidget {
  final MediaBase media;
  const _SimilarMediaCard({required this.media});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetailScreen(malId: media.malId, isManga: media is Manga))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PremiumImage(
                imageUrl: media.displayImageUrl,
                title: media.displayTitle,
                height: 180,
                width: 140,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(media.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text(media.genres.take(1).join(''), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}