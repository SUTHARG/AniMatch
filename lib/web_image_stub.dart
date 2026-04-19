import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget buildWebImage({required String imageUrl, BoxFit fit = BoxFit.cover}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    placeholder: (context, url) => Container(color: Colors.grey[900]),
    errorWidget: (context, url, error) => const Icon(Icons.error),
  );
}
