import 'package:flutter/foundation.dart';

// ── Episode ────────────────────────────────────────────────────────────────
@immutable
class HianimeEpisode {
  final String episodeId; // e.g. "attack-on-titan-112?ep=230"
  final int number;
  final String? title;
  final bool isFiller;

  const HianimeEpisode({
    required this.episodeId,
    required this.number,
    this.title,
    this.isFiller = false,
  });

  factory HianimeEpisode.fromJson(Map<String, dynamic> j) {
    return HianimeEpisode(
      episodeId: j['episodeId'] as String? ?? '',
      number: (j['number'] as num?)?.toInt() ?? 0,
      title: j['title'] as String?,
      isFiller: j['isFiller'] as bool? ?? false,
    );
  }
}

// ── Episode list ───────────────────────────────────────────────────────────
@immutable
class HianimeEpisodeList {
  final int totalEpisodes;
  final List<HianimeEpisode> episodes;

  const HianimeEpisodeList({
    required this.totalEpisodes,
    required this.episodes,
  });

  factory HianimeEpisodeList.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? j;
    final list = (data['episodes'] as List<dynamic>?) ?? [];
    return HianimeEpisodeList(
      totalEpisodes: (data['totalEpisodes'] as num?)?.toInt() ?? list.length,
      episodes: list
          .map((e) => HianimeEpisode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  HianimeEpisode? episodeByNumber(int number) {
    try {
      return episodes.firstWhere((e) => e.number == number);
    } catch (_) {
      return null;
    }
  }
}

// ── Streaming source ───────────────────────────────────────────────────────
@immutable
class HianimeSource {
  final String url;
  final bool isM3U8;
  final String? quality;

  const HianimeSource({
    required this.url,
    required this.isM3U8,
    this.quality,
  });

  factory HianimeSource.fromJson(Map<String, dynamic> j) {
    return HianimeSource(
      url: j['url'] as String? ?? '',
      isM3U8: j['isM3U8'] as bool? ?? false,
      quality: j['quality'] as String?,
    );
  }
}

// ── Subtitle ───────────────────────────────────────────────────────────────
@immutable
class HianimeSubtitle {
  final String url;
  final String lang;

  const HianimeSubtitle({required this.url, required this.lang});

  factory HianimeSubtitle.fromJson(Map<String, dynamic> j) {
    return HianimeSubtitle(
      url: j['url'] as String? ?? '',
      lang: j['lang'] as String? ?? 'Unknown',
    );
  }
}

// ── Full streaming sources response ───────────────────────────────────────
@immutable
class HianimeStreamSources {
  final List<HianimeSource> sources;
  final List<HianimeSubtitle> subtitles;
  final Map<String, String> headers;

  const HianimeStreamSources({
    required this.sources,
    required this.subtitles,
    required this.headers,
  });

  factory HianimeStreamSources.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? j;
    return HianimeStreamSources(
      sources: ((data['sources'] as List<dynamic>?) ?? [])
          .map((s) => HianimeSource.fromJson(s as Map<String, dynamic>))
          .toList(),
      subtitles: ((data['subtitles'] as List<dynamic>?) ?? [])
          .map((s) => HianimeSubtitle.fromJson(s as Map<String, dynamic>))
          .toList(),
      headers: ((data['headers'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  // Best HLS source: prefer non-null quality, then first m3u8, then first
  HianimeSource? get bestSource {
    if (sources.isEmpty) return null;
    final m3u8 = sources.where((s) => s.isM3U8).toList();
    if (m3u8.isEmpty) return sources.first;
    return m3u8.first;
  }

  // English subtitle URL for better_player
  String? get englishSubtitleUrl {
    try {
      return subtitles
          .firstWhere((s) => s.lang.toLowerCase().contains('english'))
          .url;
    } catch (_) {
      return subtitles.isNotEmpty ? subtitles.first.url : null;
    }
  }
}

// ── AniSkip skip time ──────────────────────────────────────────────────────
@immutable
class AniSkipInterval {
  final double startTime; // in seconds
  final double endTime;   // in seconds
  final String skipType;  // "op" or "ed"

  const AniSkipInterval({
    required this.startTime,
    required this.endTime,
    required this.skipType,
  });

  factory AniSkipInterval.fromJson(Map<String, dynamic> j) {
    final interval = j['interval'] as Map<String, dynamic>? ?? {};
    return AniSkipInterval(
      startTime: (interval['startTime'] as num?)?.toDouble() ?? 0,
      endTime: (interval['endTime'] as num?)?.toDouble() ?? 0,
      skipType: j['skipType'] as String? ?? 'op',
    );
  }

  bool isActiveAt(double positionSeconds) {
    return positionSeconds >= startTime && positionSeconds <= endTime;
  }

  Duration get start => Duration(milliseconds: (startTime * 1000).toInt());
  Duration get end => Duration(milliseconds: (endTime * 1000).toInt());
}

@immutable
class AniSkipResult {
  final bool found;
  final List<AniSkipInterval> intervals;

  const AniSkipResult({required this.found, required this.intervals});

  factory AniSkipResult.fromJson(Map<String, dynamic> j) {
    return AniSkipResult(
      found: j['found'] as bool? ?? false,
      intervals: ((j['results'] as List<dynamic>?) ?? [])
          .map((r) => AniSkipInterval.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  AniSkipInterval? get opening {
    try {
      return intervals.firstWhere((i) => i.skipType == 'op');
    } catch (_) {
      return null;
    }
  }

  AniSkipInterval? get ending {
    try {
      return intervals.firstWhere((i) => i.skipType == 'ed');
    } catch (_) {
      return null;
    }
  }
}
