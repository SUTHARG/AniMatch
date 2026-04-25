import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animatch/data/models/anime.dart';
import 'package:animatch/presentation/providers/service_providers.dart';

final topAnimeProvider =
    FutureProvider.family<List<Anime>, String>((ref, tab) async {
  final animeRepository = ref.watch(animeRepositoryProvider);

  try {
    return animeRepository.getTopAnime(tab: tab);
  } catch (error) {
    throw Exception('Failed to load top anime: $error');
  }
});
