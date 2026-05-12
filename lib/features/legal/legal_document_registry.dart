class LegalDocumentMeta {
  const LegalDocumentMeta({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.audience,
  });

  final String id;
  final String title;
  final String assetPath;
  final LegalAudience audience;
}

enum LegalAudience { customer, vendor, rider, common }

class LegalDocumentRegistry {
  static const List<LegalDocumentMeta> all = <LegalDocumentMeta>[
    LegalDocumentMeta(
      id: 'customer_terms',
      title: 'Customer Terms & Conditions',
      assetPath: 'assets/legal/customer_terms_and_conditions.md',
      audience: LegalAudience.customer,
    ),
    LegalDocumentMeta(
      id: 'customer_privacy',
      title: 'Customer Privacy Policy',
      assetPath: 'assets/legal/customer_privacy_policy.md',
      audience: LegalAudience.customer,
    ),
    LegalDocumentMeta(
      id: 'vendor_terms',
      title: 'Vendor Terms & Conditions',
      assetPath: 'assets/legal/vendor_terms_and_conditions.md',
      audience: LegalAudience.vendor,
    ),
    LegalDocumentMeta(
      id: 'vendor_privacy',
      title: 'Vendor Privacy Policy',
      assetPath: 'assets/legal/vendor_privacy_policy.md',
      audience: LegalAudience.vendor,
    ),
    LegalDocumentMeta(
      id: 'rider_terms',
      title: 'Rider Terms & Conditions',
      assetPath: 'assets/legal/rider_terms_and_conditions.md',
      audience: LegalAudience.rider,
    ),
    LegalDocumentMeta(
      id: 'rider_privacy',
      title: 'Rider Privacy Policy',
      assetPath: 'assets/legal/rider_privacy_policy.md',
      audience: LegalAudience.rider,
    ),
    LegalDocumentMeta(
      id: 'refund_policy',
      title: 'Refund & Cancellation Policy',
      assetPath: 'assets/legal/refund_and_cancellation_policy.md',
      audience: LegalAudience.common,
    ),
    LegalDocumentMeta(
      id: 'delivery_policy',
      title: 'Delivery Policy',
      assetPath: 'assets/legal/delivery_policy.md',
      audience: LegalAudience.common,
    ),
    LegalDocumentMeta(
      id: 'account_deletion_policy',
      title: 'Account Deletion Policy',
      assetPath: 'assets/legal/account_deletion_policy.md',
      audience: LegalAudience.common,
    ),
    LegalDocumentMeta(
      id: 'community_guidelines',
      title: 'Community Guidelines',
      assetPath: 'assets/legal/community_guidelines.md',
      audience: LegalAudience.common,
    ),
    LegalDocumentMeta(
      id: 'cookie_policy',
      title: 'Cookie Policy',
      assetPath: 'assets/legal/cookie_policy.md',
      audience: LegalAudience.common,
    ),
    LegalDocumentMeta(
      id: 'vendor_agreement',
      title: 'Vendor Agreement',
      assetPath: 'assets/legal/vendor_agreement.md',
      audience: LegalAudience.vendor,
    ),
    LegalDocumentMeta(
      id: 'rider_agreement',
      title: 'Rider Agreement',
      assetPath: 'assets/legal/rider_agreement.md',
      audience: LegalAudience.rider,
    ),
  ];

  static List<LegalDocumentMeta> forAudience(LegalAudience audience) {
    return all
        .where(
          (doc) =>
              doc.audience == LegalAudience.common || doc.audience == audience,
        )
        .toList(growable: false);
  }
}
