import '../../domain/entities/invoice_entity.dart';

class InvoiceModel extends InvoiceEntity {
  const InvoiceModel({
    required super.id,
    required super.invoiceNumber,
    required super.orderId,
    required super.grandTotal,
    required super.status,
    required super.paymentStatus,
    required super.generatedAt,
    required super.cgst,
    required super.sgst,
    required super.igst,
    required super.tax,
    super.versionLabel = 'v1',
    super.verificationHash = '',
    super.creditNoteNumber = '',
    super.refundStatus = '',
    super.freezeState = 'none',
    super.legalHold = false,
    super.cloudinaryPublicId = '',
    super.cloudinaryUrl = '',
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final cloudAsset = Map<String, dynamic>.from(
      (json['cloudinaryAsset'] as Map?) ?? const {},
    );
    return InvoiceModel(
      id: (json['id'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()) ?? DateTime.now(),
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      versionLabel: (json['versionLabel'] ?? 'v1').toString(),
      verificationHash: (json['signedHash'] ?? '').toString(),
      creditNoteNumber: (json['creditNoteNumber'] ?? '').toString(),
      refundStatus: (json['status'] ?? '').toString(),
      freezeState: (json['freezeState'] ?? 'none').toString(),
      legalHold: json['legalHold'] == true,
      cloudinaryPublicId: (cloudAsset['publicId'] ?? '').toString(),
      cloudinaryUrl: (cloudAsset['secureUrl'] ?? '').toString(),
    );
  }
}
