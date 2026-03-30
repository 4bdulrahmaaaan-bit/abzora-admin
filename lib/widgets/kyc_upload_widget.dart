import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class KycUploadWidget extends StatelessWidget {
  const KycUploadWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.file,
    this.networkUrl,
    required this.onPickCamera,
    required this.onPickGallery,
    this.requiredLabel = true,
  });

  final String title;
  final String subtitle;
  final XFile? file;
  final String? networkUrl;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final bool requiredLabel;

  @override
  Widget build(BuildContext context) {
    final hasPreview = file != null || ((networkUrl ?? '').trim().isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (requiredLabel)
                const Text(
                  'Required',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6F6F6F), height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            height: 164,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPreview ? _preview() : const _EmptyPreview(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (file != null) {
      return FutureBuilder<Uint8List>(
        future: file!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    return Image.network(networkUrl!, fit: BoxFit.cover);
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.upload_file_outlined, size: 34, color: Color(0xFF9A9A9A)),
          SizedBox(height: 8),
          Text(
            'Preview will appear here',
            style: TextStyle(color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}
