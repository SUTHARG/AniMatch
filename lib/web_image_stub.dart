import 'package:flutter/material.dart';

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
    return const SizedBox.shrink(); // No-op on mobile
  }
}

void registerWebImageFactory() {
  // No-op on mobile
}
