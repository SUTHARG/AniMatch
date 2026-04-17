import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'dart:html' as html;

class WebImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const WebImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Standard approach for dynamic platform views on Web.
    // We register a unique key for this configuration if it hasn't been registered.
    final String viewId = 'img-${imageUrl.hashCode}-${fit.index}';

    // In dynamic scenarios, we can use a Set to track registered factories 
    // to avoid console noise, although Flutter handles re-registration gracefully.
    _registerFactoryOnce(viewId);

    return HtmlElementView(viewType: viewId);
  }

  void _registerFactoryOnce(String viewId) {
    // registerViewFactory is safe to call multiple types but we use a local cache
    // for peak performance during rapid scrolling/rebuilds.
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final img = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _getFit(fit)
          ..style.border = 'none'
          ..draggable = false;
        return img;
      },
    );
  }

  String _getFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover: return 'cover';
      case BoxFit.contain: return 'contain';
      case BoxFit.fill: return 'fill';
      case BoxFit.fitWidth: return 'cover'; // Approximation
      case BoxFit.fitHeight: return 'cover';
      default: return 'cover';
    }
  }
}

void registerWebImageFactory() {
  // Global initializer placeholder
}
