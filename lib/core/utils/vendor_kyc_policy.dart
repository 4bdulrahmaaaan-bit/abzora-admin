class VendorKycPolicy {
  static const double minConfidenceForAutoSubmit = 75;

  static double confidenceFromVerification(Map<String, dynamic> verification) {
    final score = verification['confidenceScore'];
    if (score is num) {
      return score.toDouble();
    }
    return 0;
  }

  static String statusFromVerification(Map<String, dynamic> verification) {
    return (verification['status'] ?? '').toString().trim().toLowerCase();
  }

  static bool requiresManualReview(
    Map<String, dynamic> verification, {
    double minConfidence = minConfidenceForAutoSubmit,
  }) {
    final status = statusFromVerification(verification);
    final confidence = confidenceFromVerification(verification);
    return status == 'manual_review' || confidence < minConfidence;
  }
}
