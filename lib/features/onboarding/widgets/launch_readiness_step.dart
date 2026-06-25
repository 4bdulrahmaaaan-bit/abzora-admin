import 'package:flutter/material.dart';
import '../../../../core/vendor/theme/vendor_theme.dart';

class LaunchReadinessStep extends StatelessWidget {
  final String storeName;
  final String ownerName;
  final String specializationsSummary;
  final int portfolioCount;
  final String capacitySummary;
  final double kycConfidence;
  final Map<String, dynamic> aadhaarOcr;
  final Map<String, dynamic> panOcr;
  final bool kycProcessed;
  
  final bool agreedToTruth;
  final bool agreedToTerms;
  final ValueChanged<bool?> onAgreedToTruth;
  final ValueChanged<bool?> onAgreedToTerms;
  
  final void Function(int step) onJumpToStep;
  final VoidCallback onRetryKyc;

  const LaunchReadinessStep({
    super.key,
    required this.storeName,
    required this.ownerName,
    required this.specializationsSummary,
    required this.portfolioCount,
    required this.capacitySummary,
    required this.kycConfidence,
    required this.aadhaarOcr,
    required this.panOcr,
    required this.kycProcessed,
    required this.agreedToTruth,
    required this.agreedToTerms,
    required this.onAgreedToTruth,
    required this.onAgreedToTerms,
    required this.onJumpToStep,
    required this.onRetryKyc,
  });

  @override
  Widget build(BuildContext context) {
    int score = 0;
    if (storeName.isNotEmpty && ownerName.isNotEmpty) score += 25;
    if (specializationsSummary.isNotEmpty) score += 25;
    if (capacitySummary.isNotEmpty) score += 20;
    if (kycProcessed && kycConfidence > 50) score += 30;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          context: context,
          title: 'Launch Readiness Dashboard',
          children: [
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 12,
                      color: VendorTheme.onboardingElevatedSurface,
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: score / 100),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, _) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          color: score >= 90 ? VendorTheme.onboardingSuccess : (score >= 60 ? VendorTheme.onboardingGold : VendorTheme.onboardingWarning),
                          strokeCap: StrokeCap.round,
                        );
                      },
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$score%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: VendorTheme.onboardingPrimaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Ready',
                            style: TextStyle(
                              color: VendorTheme.onboardingSecondaryText.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildReviewRow(context, 'Business', storeName.isNotEmpty ? storeName : 'Missing', () => onJumpToStep(0)),
            _buildReviewRow(context, 'Expertise', specializationsSummary.isNotEmpty ? specializationsSummary : 'Missing', () => onJumpToStep(1)),
            _buildReviewRow(context, 'Portfolio', portfolioCount > 0 ? '$portfolioCount files' : 'None', () => onJumpToStep(2), isWarning: false),
            _buildReviewRow(context, 'Operations', capacitySummary.isNotEmpty ? capacitySummary : 'Missing', () => onJumpToStep(3)),
            
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5)),
            ),
            
            Text(
              'Compliance Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VendorTheme.onboardingPrimaryText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            _buildReviewRow(context, 'KYC Score', '${kycConfidence.toStringAsFixed(1)}%', () => onJumpToStep(4), isWarning: kycConfidence < 70),
            _buildReviewRow(context, 'Aadhaar', _resolveAadhaarDisplay(aadhaarOcr), () => onJumpToStep(4)),
            _buildReviewRow(context, 'PAN', _resolvePanDisplay(panOcr), () => onJumpToStep(4)),

            if (kycProcessed && kycConfidence < 70)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VendorTheme.onboardingError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
                    border: Border.all(color: VendorTheme.onboardingError.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: VendorTheme.onboardingError, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Low confidence score. Please retry document upload for faster approval.',
                              style: TextStyle(color: VendorTheme.onboardingError, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: onRetryKyc,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: VendorTheme.onboardingError),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VendorTheme.radiusSmall)),
                          ),
                          child: const Text('Retry Document Upload', style: TextStyle(color: VendorTheme.onboardingError, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
            Text(
              'Agreements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: VendorTheme.onboardingPrimaryText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildCheckbox('I certify that the information provided is accurate and true.', agreedToTruth, onAgreedToTruth),
            const SizedBox(height: 12),
            _buildCheckbox('I agree to the Abzora Vendor Marketplace Terms and Conditions.', agreedToTerms, onAgreedToTerms),
          ],
        ),
      ],
    );
  }

  String _resolveAadhaarDisplay(Map<String, dynamic> data) {
    final direct = data['aadhaarNumber']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final recognized = data['recognizedText']?.toString() ?? data['rawText']?.toString() ?? '';
    final match = RegExp(r'\\b\\d{12}\\b').firstMatch(recognized.replaceAll(RegExp(r'\\s+'), ''));
    if (match != null) return match.group(0)!;
    return recognized.trim().isNotEmpty ? recognized.trim() : 'Pending';
  }

  String _resolvePanDisplay(Map<String, dynamic> data) {
    final direct = data['panNumber']?.toString().trim().toUpperCase() ?? '';
    if (direct.isNotEmpty) return direct;
    final recognized = (data['recognizedText']?.toString() ?? data['rawText']?.toString() ?? '').toUpperCase();
    final match = RegExp(r'\\b[A-Z]{5}\\d{4}[A-Z]\\b').firstMatch(recognized);
    if (match != null) return match.group(0)!;
    return recognized.trim().isNotEmpty ? recognized.trim() : 'Pending';
  }

  Widget _buildCard({required BuildContext context, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: VendorTheme.onboardingSurface,
        borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
        border: Border.all(color: VendorTheme.onboardingElevatedSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: VendorTheme.onboardingPrimaryText,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(BuildContext context, String label, String value, VoidCallback onEdit, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: VendorTheme.onboardingSecondaryText, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? VendorTheme.onboardingWarning : VendorTheme.onboardingPrimaryText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.edit_outlined, size: 18, color: VendorTheme.onboardingSecondaryText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String title, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: VendorTheme.onboardingElevatedSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VendorTheme.radiusSmall),
        border: Border.all(
          color: value ? VendorTheme.onboardingSuccess.withValues(alpha: 0.5) : VendorTheme.onboardingElevatedSurface,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(color: VendorTheme.onboardingPrimaryText, fontSize: 13),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        activeColor: VendorTheme.onboardingSuccess,
        checkColor: VendorTheme.onboardingBackground,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
