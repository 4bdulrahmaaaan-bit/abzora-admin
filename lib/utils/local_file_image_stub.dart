import 'package:flutter/material.dart';

String localFileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/').where((part) => part.isNotEmpty);
  return parts.isEmpty ? 'selected-image' : parts.last;
}

Widget localFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
}) {
  final uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme) {
    return Image.network(path, height: height, width: width, fit: fit);
  }

  return Container(
    height: height,
    width: width,
    color: Colors.black12,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined),
  );
}
