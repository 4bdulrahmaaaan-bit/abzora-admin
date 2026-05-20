class InvoiceEntity {
  final String id;
  final String invoiceNumber;
  final String orderId;
  final double grandTotal;
  final String status;
  final String paymentStatus;
  final DateTime generatedAt;
  final double cgst;
  final double sgst;
  final double igst;
  final double tax;
  final String versionLabel;
  final String verificationHash;
  final String creditNoteNumber;
  final String refundStatus;
  final String freezeState;
  final bool legalHold;
  final String cloudinaryPublicId;
  final String cloudinaryUrl;

  const InvoiceEntity({
    required this.id,
    required this.invoiceNumber,
    required this.orderId,
    required this.grandTotal,
    required this.status,
    required this.paymentStatus,
    required this.generatedAt,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.tax,
    this.versionLabel = 'v1',
    this.verificationHash = '',
    this.creditNoteNumber = '',
    this.refundStatus = '',
    this.freezeState = 'none',
    this.legalHold = false,
    this.cloudinaryPublicId = '',
    this.cloudinaryUrl = '',
  });
}
