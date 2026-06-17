import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

enum DocumentStatus {
  required,
  uploaded,
  underReview,
  verified,
  actionRequired,
}

class ComplianceStep extends StatelessWidget {
  final String? ownerPhotoUrl;
  final DocumentStatus ownerStatus;
  final String? storePhotoUrl;
  final DocumentStatus storeStatus;
  final String? aadhaarUrl;
  final DocumentStatus aadhaarStatus;
  final String? panUrl;
  final DocumentStatus panStatus;
  
  final VoidCallback onUploadOwner;
  final VoidCallback onUploadStore;
  final VoidCallback onUploadAadhaar;
  final VoidCallback onUploadPan;

  const ComplianceStep({
    super.key,
    required this.ownerPhotoUrl,
    this.ownerStatus = DocumentStatus.required,
    required this.storePhotoUrl,
    this.storeStatus = DocumentStatus.required,
    required this.aadhaarUrl,
    this.aadhaarStatus = DocumentStatus.required,
    required this.panUrl,
    this.panStatus = DocumentStatus.required,
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
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: VendorTheme.onboardingSurface,
            borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
            border: Border.all(color: VendorTheme.onboardingElevatedSurface),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_person_outlined, color: VendorTheme.onboardingGold, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure Document Verification',
                      style: TextStyle(color: VendorTheme.onboardingPrimaryText, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your documents are encrypted and verified instantly by our OCR systems. Data is never shared.',
                      style: TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildVisualCard(
          context: context,
          label: 'Owner Photo',
          description: 'A clear photo of the primary business owner.',
          imageUrl: ownerPhotoUrl,
          status: ownerStatus,
          onTap: onUploadOwner,
        ),
        const SizedBox(height: 16),
        _buildVisualCard(
          context: context,
          label: 'Storefront Photo',
          description: 'A photo of your physical store or manufacturing unit.',
          imageUrl: storePhotoUrl,
          status: storeStatus,
          onTap: onUploadStore,
        ),
        const SizedBox(height: 16),
        _buildVisualCard(
          context: context,
          label: 'Aadhaar Card',
          description: 'Front and back photo of the owner\'s Aadhaar.',
          imageUrl: aadhaarUrl,
          status: aadhaarStatus,
          onTap: onUploadAadhaar,
        ),
        const SizedBox(height: 16),
        _buildVisualCard(
          context: context,
          label: 'PAN Card',
          description: 'Clear photo of the business or individual PAN card.',
          imageUrl: panUrl,
          status: panStatus,
          onTap: onUploadPan,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildVisualCard({
    required BuildContext context,
    required String label,
    required String description,
    required String? imageUrl,
    required DocumentStatus status,
    required VoidCallback onTap,
  }) {
    final bool done = imageUrl != null;
    
    Color statusColor;
    String statusText;
    
    switch (status) {
      case DocumentStatus.required:
        statusColor = VendorTheme.onboardingWarning;
        statusText = 'Required';
        break;
      case DocumentStatus.uploaded:
        statusColor = Colors.blue;
        statusText = 'Uploaded';
        break;
      case DocumentStatus.underReview:
        statusColor = Colors.orange;
        statusText = 'Under Review';
        break;
      case DocumentStatus.verified:
        statusColor = VendorTheme.onboardingSuccess;
        statusText = 'Verified';
        break;
      case DocumentStatus.actionRequired:
        statusColor = VendorTheme.onboardingError;
        statusText = 'Action Required';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: VendorTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: Border.all(color: done ? statusColor.withValues(alpha: 0.3) : VendorTheme.onboardingElevatedSurface),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (done)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VendorTheme.onboardingSuccess.withValues(alpha: 0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: VendorTheme.onboardingElevatedSurface,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2, color: VendorTheme.onboardingGold),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: VendorTheme.onboardingElevatedSurface,
                          child: const Icon(Icons.error, color: VendorTheme.onboardingSecondaryText),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VendorTheme.onboardingElevatedSurface, style: BorderStyle.solid),
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.5), size: 28),
                  ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: VendorTheme.onboardingPrimaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (status == DocumentStatus.verified) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle, color: statusColor, size: 16),
                          ] else if (status == DocumentStatus.actionRequired) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.error, color: statusColor, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.8), fontSize: 13, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  done ? Icons.refresh_rounded : Icons.arrow_forward_ios_rounded,
                  color: done ? VendorTheme.onboardingSecondaryText : VendorTheme.onboardingGold,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
