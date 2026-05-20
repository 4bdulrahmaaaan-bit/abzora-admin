import 'dart:io';

import 'package:flutter/material.dart';

String localFileName(String path) => File(path).uri.pathSegments.last;

Widget localFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
}) {
  return Image.file(
    File(path),
    height: height,
    width: width,
    fit: fit,
  );
}
