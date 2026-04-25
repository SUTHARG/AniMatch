import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildWebImage({required String imageUrl, BoxFit fit = BoxFit.cover}) {
  final String viewID = imageUrl.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  ui.platformViewRegistry.registerViewFactory(viewID, (int viewId) {
    final element = web.HTMLImageElement()
      ..src = imageUrl
      ..style.objectFit = _getFit(fit)
      ..style.width = '100%'
      ..style.height = '100%';
    return element;
  });

  return HtmlElementView(viewType: viewID);
}

String _getFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain: return 'contain';
    case BoxFit.fill: return 'fill';
    case BoxFit.cover: return 'cover';
    default: return 'cover';
  }
}
