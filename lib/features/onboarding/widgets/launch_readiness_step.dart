import 'package:flutter/material.dart';

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
    if (storeName.isNotEmpty && ownerName.isNotEmpty) score += 20;
    if (specializationsSummary.isNotEmpty) score += 20;
    if (portfolioCount >= 5) score += 20;
    if (capacitySummary.isNotEmpty) score += 10;
    if (kycProcessed && kycConfidence > 50) score += 30;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: [
        _buildCard(
          title: 'Launch Readiness',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Readiness Score', style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  '$score / 100',
                  style: TextStyle(
                    color: score >= 90 ? Colors.green : (score >= 60 ? Colors.orange : Colors.redAccent),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(
                  score >= 90 ? Colors.green : (score >= 60 ? Colors.orange : Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildReviewRow('Business', storeName.isNotEmpty ? storeName : 'Missing', () => onJumpToStep(0)),
            _buildReviewRow('Expertise', specializationsSummary.isNotEmpty ? specializationsSummary : 'Missing', () => onJumpToStep(1)),
            _buildReviewRow('Portfolio', '$portfolioCount files', () => onJumpToStep(2), isWarning: portfolioCount < 5),
            _buildReviewRow('Operations', capacitySummary.isNotEmpty ? capacitySummary : 'Missing', () => onJumpToStep(3)),
            
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12)),
            
            const Text(
              'Compliance Summary',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildReviewRow('KYC Score', '${kycConfidence.toStringAsFixed(1)}%', () => onJumpToStep(4), isWarning: kycConfidence < 70),
            _buildReviewRow('Aadhaar', aadhaarOcr['aadhaarNumber']?.toString() ?? 'Pending', () => onJumpToStep(4)),
            _buildReviewRow('PAN', panOcr['panNumber']?.toString() ?? 'Pending', () => onJumpToStep(4)),

            if (kycProcessed && kycConfidence < 70)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Low confidence score. Please retry document upload for faster approval.',
                              style: TextStyle(color: Colors.redAccent.shade100, fontSize: 13),
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
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Retry Document Upload', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
            const Text(
              'Agreements',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildCheckbox('I certify that the information provided is accurate and true.', agreedToTruth, onAgreedToTruth),
            const SizedBox(height: 8),
            _buildCheckbox('I agree to the Abzora Vendor Marketplace Terms and Conditions.', agreedToTerms, onAgreedToTerms),
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

  Widget _buildReviewRow(String label, String value, VoidCallback onEdit, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isWarning ? Colors.orangeAccent : Colors.white,
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
                child: Icon(Icons.edit_outlined, size: 18, color: Colors.white54),
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
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.green.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        activeColor: Colors.green,
        checkColor: Colors.white,
        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
