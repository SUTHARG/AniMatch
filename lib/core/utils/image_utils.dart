import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:animatch/core/utils/web_image_stub.dart'
    if (dart.library.html) 'package:animatch/core/utils/web_image_web.dart';

/// Robust utilities for handling image assets and network images across platforms,
/// specifically solving CORS and path issues on Flutter Web.
class ImageUtils {
  /// Routes a network image URL through a CORS-safe proxy when running on Web.
  /// Uses 'images.weserv.nl' for high-speed, reliable proxying.
  static String getCORSUrl(String url) {
    // Proxy disabled as per user request.
    // This strategy requires running the app with --web-renderer html
    return url;
  }

  /// Resolves an asset path, ensuring that on Flutter Web it doesn't double-prefix
  /// with 'assets/'.
  static String resolveAsset(String path) {
    if (!kIsWeb) return path;

    // On many web hosting environments, the 'assets/' prefix is handled by the
    // static server or double-added by the build tools.
    // Using simple relative mapping for Web is often more reliable.
    return path.startsWith('assets/') ? path.replaceFirst('assets/', '') : path;
  }

  /// Loads an asset image with a resilient fallback if the asset is missing or fails.
  static Widget safeBackground(String path, {BoxFit fit = BoxFit.cover}) {
    return Image.asset(
      resolveAsset(path),
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: A beautiful premium gradient if the asset is missing
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1E2E).withValues(alpha: 1.0),
                const Color(0xFF11111B).withValues(alpha: 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A high-fidelity, resilient image widget that handles CORS on Web and
/// provides premium glassmorphic loading states.
class PremiumImage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;

  const PremiumImage({
    super.key,
    required this.imageUrl,
    this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = ImageUtils.getCORSUrl(imageUrl);

    Widget image;
    if (kIsWeb) {
      // Use raw <img> tag via HtmlElementView to bypass CORS without a proxy
      image = SizedBox(
        width: width,
        height: height,
        child: buildWebImage(
          imageUrl: imageUrl,
          fit: fit,
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: proxiedUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        memCacheWidth: width != null ? (width! * 2).toInt() : 240,
        memCacheHeight: height != null ? (height! * 2).toInt() : 360,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildError(),
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.image_outlined, color: Colors.white10, size: 40),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      color: Colors.white10,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 30),
          const SizedBox(height: 8),
          if (title != null)
            Text(
              title!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          const Text(
            'Unavailable',
            style: TextStyle(color: Colors.white24, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
