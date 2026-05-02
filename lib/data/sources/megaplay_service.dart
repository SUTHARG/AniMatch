class MegaPlayService {
  MegaPlayService._privateConstructor();
  static final MegaPlayService instance = MegaPlayService._privateConstructor();

  static const String _base = 'https://megaplay.buzz/stream/mal';

  String embedUrl({
    required int malId,
    required int episode,
    required String language, // "sub" or "dub"
  }) {
    return '$_base/$malId/$episode/$language';
  }

  bool isValidMalId(int malId) => malId > 0;
}
