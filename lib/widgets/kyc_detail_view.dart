import 'package:flutter/material.dart';

import '../models/models.dart';
import 'kyc_document_viewer.dart';

class KycDetailData {
  const KycDetailData({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.city,
    required this.status,
    required this.createdAt,
    this.address = '',
    this.subtitle = '',
    this.rejectionReason = '',
    this.primaryPhotoUrl = '',
    this.secondaryPhotoUrl = '',
    this.primaryPhotoLabel = 'Photo',
    this.secondaryPhotoLabel = 'Secondary',
    this.documents = const [],
    this.riskFlags = const [],
    this.reviewedByName = '',
    this.reviewedAt = '',
    this.actionHistory = const [],
  });

  final String id;
  final String name;
  final String phone;
  final String role;
  final String city;
  final String status;
  final String createdAt;
  final String address;
  final String subtitle;
  final String rejectionReason;
  final String primaryPhotoUrl;
  final String secondaryPhotoUrl;
  final String primaryPhotoLabel;
  final String secondaryPhotoLabel;
  final List<KycDocumentEntry> documents;
  final List<String> riskFlags;
  final String reviewedByName;
  final String reviewedAt;
  final List<KycActionEntry> actionHistory;
}

class KycDocumentEntry {
  const KycDocumentEntry({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;
}

class KycDetailView extends StatelessWidget {
  const KycDetailView({
    super.key,
    required this.data,
    this.onApprove,
    this.onReject,
  });

  final KycDetailData? data;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEAEAEA)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Select a KYC request to review full details, photos, and documents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF727272), height: 1.45),
            ),
          ),
        ),
      );
    }

    final statusColor = switch (data!.status) {
      'approved' => const Color(0xFF067647),
      'rejected' => const Color(0xFFB42318),
      _ => const Color(0xFFB76E00),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data!.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data!.subtitle.isEmpty ? data!.role : data!.subtitle,
                        style: const TextStyle(color: Color(0xFF666666), height: 1.45),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    data!.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionCard(
                  title: 'Basic Details',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _DetailTile(label: 'Name', value: data!.name),
                      _DetailTile(label: 'Phone', value: data!.phone),
                      _DetailTile(label: 'Role', value: data!.role),
                      _DetailTile(label: 'City', value: data!.city),
                      _DetailTile(label: 'Submitted', value: data!.createdAt),
                      if (data!.address.trim().isNotEmpty)
                        _DetailTile(
                          label: 'Address',
                          value: data!.address,
                          wide: true,
                        ),
                    ],
                  ),
                ),
                if (data!.riskFlags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Risk Flags',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: data!.riskFlags
                          .map(
                            (flag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Color(0xFFB76E00),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    flag,
                                    style: const TextStyle(
                                      color: Color(0xFF9A6700),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Photos',
                  child: Row(
                    children: [
                      Expanded(
                        child: _photoCard(
                          context,
                          url: data!.primaryPhotoUrl,
                          label: data!.primaryPhotoLabel,
                        ),
                      ),
                      if (data!.secondaryPhotoUrl.trim().isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _photoCard(
                            context,
                            url: data!.secondaryPhotoUrl,
                            label: data!.secondaryPhotoLabel,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Documents',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final docs = data!.documents
                          .where((doc) => doc.url.trim().isNotEmpty)
                          .toList();
                      final wide = constraints.maxWidth > 640;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: docs
                              .map(
                                (doc) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(right: doc == docs.last ? 0 : 12),
                                    child: SizedBox(
                                      height: 220,
                                      child: KycDocumentViewer(
                                        url: doc.url,
                                        label: doc.label,
                                        onTap: () => showKycDocumentViewer(
                                          context,
                                          imageUrl: doc.url,
                                          title: doc.label,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: docs
                            .map(
                              (doc) => SizedBox(
                                width: 180,
                                height: 200,
                                child: KycDocumentViewer(
                                  url: doc.url,
                                  label: doc.label,
                                  onTap: () => showKycDocumentViewer(
                                    context,
                                    imageUrl: doc.url,
                                    title: doc.label,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Action History',
                  child: Column(
                    children: [
                      if (data!.reviewedByName.trim().isNotEmpty ||
                          data!.reviewedAt.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Reviewed by: ${data!.reviewedByName.trim().isEmpty ? 'Awaiting review' : data!.reviewedByName}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (data!.reviewedAt.trim().isNotEmpty)
                                Text(
                                  data!.reviewedAt,
                                  style: const TextStyle(color: Color(0xFF6E6E6E)),
                                ),
                            ],
                          ),
                        ),
                      if (data!.actionHistory.isEmpty)
                        const Text(
                          'No action history yet.',
                          style: TextStyle(color: Color(0xFF737373)),
                        )
                      else
                        ...data!.actionHistory.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4AF37),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.action.toUpperCase()} - ${entry.actorName}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        entry.timestamp,
                                        style: const TextStyle(
                                          color: Color(0xFF737373),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (entry.note.trim().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          entry.note,
                                          style: const TextStyle(
                                            color: Color(0xFF5E5E5E),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (data!.rejectionReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Rejection Reason',
                    child: Text(
                      data!.rejectionReason,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: data!.status == 'pending' ? onReject : null,
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFB42318)),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: data!.status == 'pending' ? onApprove : null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF067647),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard(
    BuildContext context, {
    required String url,
    required String label,
  }) {
    if (url.trim().isEmpty) {
      return Container(
        height: 190,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label not provided',
          style: const TextStyle(color: Color(0xFF7B7B7B)),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: KycDocumentViewer(
        url: url,
        label: label,
        onTap: () => showKycDocumentViewer(
          context,
          imageUrl: url,
          title: label,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 420 : 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B7B7B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
