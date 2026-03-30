class ImageUrlService {
  static String optimizeForDelivery(
    String url, {
    int width = 1400,
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

    return raw.replaceFirst(
      marker,
      '/image/upload/f_auto,q_auto:good,c_limit,w_$width/',
    );
  }

  static List<String> optimizeAll(Iterable<String> urls, {int width = 1400}) {
    return urls.map((url) => optimizeForDelivery(url, width: width)).toList();
  }

  static List<String> normalizeStoredImages(Iterable<dynamic> values, {int width = 1400}) {
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

    return optimizeAll(normalized, width: width);
  }

  static String _sanitizeUrl(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(',/', '/')
        .replaceAll(',,', ',')
        .trim();
  }
}
