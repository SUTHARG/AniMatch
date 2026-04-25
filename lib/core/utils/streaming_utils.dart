// ---------------------------------------------------------------------------
// streaming_utils.dart — AniMatch
// Platform deep-link resolver for streaming services.
// ---------------------------------------------------------------------------

/// Maps known streaming platform display names to a function that converts
/// a web URL into the corresponding native deep-link scheme.
///
/// When the native app is not installed, url_launcher will automatically fall
/// back to the web URL via [launchUrl] with [LaunchMode.externalApplication].
const Map<String, String Function(String webUrl)> kPlatformDeepLinks = {
  'Crunchyroll': _crunchyroll,
  'Netflix': _netflix,
  'Amazon Prime Video': _amazonPrime,
  'Funimation': _funimation,
  'HIDIVE': _hidive,
  'Disney+': _disneyPlus,
};

String _crunchyroll(String url) =>
    url.replaceFirst('https://www.crunchyroll.com', 'crunchyroll://');

String _netflix(String url) =>
    url.replaceFirst('https://www.netflix.com', 'netflix://');

String _amazonPrime(String url) =>
    url.replaceFirst('https://www.amazon.com', 'aiv://');

String _funimation(String url) =>
    url.replaceFirst('https://www.funimation.com', 'funimation://');

// HIDIVE has no public deep-link scheme — always use browser
String _hidive(String url) => url;

String _disneyPlus(String url) =>
    url.replaceFirst('https://www.disneyplus.com', 'disneyplus://');

/// Returns the best URL to launch for a given streaming platform.
///
/// Tries the native deep-link by transforming [webUrl] with the platform's
/// scheme.  If [platformName] is not in the map, returns [webUrl] unchanged.
String resolveStreamingUrl(String platformName, String webUrl) {
  final transformer = kPlatformDeepLinks[platformName];
  if (transformer == null) return webUrl;
  try {
    return transformer(webUrl);
  } catch (_) {
    return webUrl;
  }
}
