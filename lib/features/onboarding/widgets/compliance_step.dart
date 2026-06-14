import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ComplianceStep extends StatelessWidget {
  final String? ownerPhotoUrl;
  final String? storePhotoUrl;
  final String? aadhaarUrl;
  final String? panUrl;
  
  final VoidCallback onUploadOwner;
  final VoidCallback onUploadStore;
  final VoidCallback onUploadAadhaar;
  final VoidCallback onUploadPan;

  const ComplianceStep({
    super.key,
    required this.ownerPhotoUrl,
    required this.storePhotoUrl,
    required this.aadhaarUrl,
    required this.panUrl,
    required this.onUploadOwner,
    required this.onUploadStore,
    required this.onUploadAadhaar,
    required this.onUploadPan,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'KYC Documents',
          children: [
            const Text(
              'Please upload clear photos. These will be verified instantly using our OCR system.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildUploadTile(
              label: 'Owner Photo',
              imageUrl: ownerPhotoUrl,
              onTap: onUploadOwner,
            ),
            _buildUploadTile(
              label: 'Storefront Photo',
              imageUrl: storePhotoUrl,
              onTap: onUploadStore,
            ),
            _buildUploadTile(
              label: 'Aadhaar Card',
              imageUrl: aadhaarUrl,
              onTap: onUploadAadhaar,
            ),
            _buildUploadTile(
              label: 'PAN Card',
              imageUrl: panUrl,
              onTap: onUploadPan,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildUploadTile({
    required String label,
    required String? imageUrl,
    required VoidCallback onTap,
  }) {
    final bool done = imageUrl != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: done ? Colors.green.withValues(alpha: 0.4) : Colors.white12,
              ),
              borderRadius: BorderRadius.circular(12),
              color: done ? Colors.green.withValues(alpha: 0.05) : Colors.transparent,
            ),
            child: Row(
              children: [
                if (done)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 48, height: 48,
                        color: Colors.white10,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 48, height: 48,
                        color: Colors.white10,
                        child: const Icon(Icons.error, color: Colors.white38),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload_file_rounded, color: Colors.white54, size: 24),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done ? 'Uploaded successfully' : 'Tap to upload',
                        style: TextStyle(
                          color: done ? Colors.green : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!done)
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16)
                else
                  const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
