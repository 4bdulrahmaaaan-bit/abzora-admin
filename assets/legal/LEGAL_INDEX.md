# Abianzo Legal Index

**Effective Date:** 12 May 2026  
**Default Policy Version:** v1.0.0

## Document IDs
1. customer_terms
2. customer_privacy
3. vendor_terms
4. vendor_privacy
5. rider_terms
6. rider_privacy
7. refund_policy
8. delivery_policy
9. account_deletion_policy
10. community_guidelines
11. cookie_policy
12. vendor_agreement
13. rider_agreement

## Consent Version Control
Abianzo apps enforce legal re-consent using audience-level versions.

### Default App Versions
- Customer: v1.0.0
- Vendor: v1.0.0
- Rider: v1.0.0

### Remote Override (Admin-Manageable)
Set values in Firebase Realtime Database path:

`platform/legalPolicyVersions/customer`
`platform/legalPolicyVersions/vendor`
`platform/legalPolicyVersions/rider`

When version changes, users are prompted to re-accept Terms and Privacy on next app launch.

## Contacts
- Support: support@abianzo.in
- Privacy: privacy@abianzo.in
