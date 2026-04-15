class ImageUrlService {
  static String optimizeForDelivery(
    String url, {
    int width = 1400,
    String quality = 'good',
  }) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }

    if (!uri.host.contains('res.cloudinary.com')) {
      return trimmed;
    }

    const marker = '/image/upload/';
    final raw = uri.toString();
    if (raw.contains('/image/upload/f_auto,')) {
      return raw;
    }
    if (!raw.contains(marker)) {
      return raw;
    }

    final normalizedQuality = quality.trim().isEmpty ? 'good' : quality.trim();
    final qualityParam = RegExp(r'^\d+$').hasMatch(normalizedQuality)
        ? 'q_$normalizedQuality'
        : 'q_auto:$normalizedQuality';

    return raw.replaceFirst(
      marker,
      '/image/upload/f_auto,$qualityParam,c_limit,w_$width/',
    );
  }

  static List<String> optimizeAll(
    Iterable<String> urls, {
    int width = 1400,
    String quality = 'good',
  }) {
    return urls
        .map((url) => optimizeForDelivery(url, width: width, quality: quality))
        .toList();
  }

  static List<String> normalizeStoredImages(
    Iterable<dynamic> values, {
    int width = 1400,
    String quality = 'good',
  }) {
    final rawParts = values
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();

    final normalized = <String>[];
    String? current;

    for (final part in rawParts) {
      final cleanedPart = part
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll("'", '')
          .replaceAll('"', '')
          .trim();

      if (cleanedPart.startsWith('http://') || cleanedPart.startsWith('https://')) {
        if (current != null && current.isNotEmpty) {
          normalized.add(_sanitizeUrl(current));
        }
        current = cleanedPart;
        continue;
      }

      if (current != null && current.isNotEmpty) {
        current = '$current,$cleanedPart';
      }
    }

    if (current != null && current.isNotEmpty) {
      normalized.add(_sanitizeUrl(current));
    }

    if (normalized.isEmpty && rawParts.isNotEmpty) {
      final combined = _sanitizeUrl(rawParts.join(','));
      if (combined.startsWith('http://') || combined.startsWith('https://')) {
        normalized.add(combined);
      }
    }

    return optimizeAll(normalized, width: width, quality: quality);
  }

  static String _sanitizeUrl(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',/', '/')
        .replaceAll(',,', ',')
        .trim();
  }
}
