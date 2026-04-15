import 'models.dart';

class TrialSessionItem {
  const TrialSessionItem({
    required this.productId,
    required this.name,
    this.imageUrl = '',
    this.price = 0,
    this.recommendedSize = '',
    this.fitConfidence = 0,
    this.styledForYou = false,
    this.source = 'selected',
  });

  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  final String recommendedSize;
  final double fitConfidence;
  final bool styledForYou;
  final String source;

  factory TrialSessionItem.fromMap(Map<String, dynamic> map) {
    return TrialSessionItem(
      productId: map['productId']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'ABZORA Item',
      imageUrl: map['imageUrl']?.toString() ?? map['image']?.toString() ?? '',
      price: ((map['price'] ?? 0) as num).toDouble(),
      recommendedSize:
          map['recommendedSize']?.toString() ?? map['size']?.toString() ?? '',
      fitConfidence: ((map['fitConfidence'] ?? map['matchScore'] ?? 0) as num)
          .toDouble(),
      styledForYou: map['styledForYou'] == true,
      source: map['source']?.toString() ?? 'selected',
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'price': price,
        'recommendedSize': recommendedSize,
        'fitConfidence': fitConfidence,
        'styledForYou': styledForYou,
        'source': source,
      };

  factory TrialSessionItem.fromProduct(
    Product product, {
    String recommendedSize = '',
    double fitConfidence = 0,
    bool styledForYou = false,
    String source = 'selected',
  }) {
    return TrialSessionItem(
      productId: product.id,
      name: product.name,
      imageUrl: product.images.isEmpty ? '' : product.images.first,
      price: product.effectivePrice,
      recommendedSize: recommendedSize,
      fitConfidence: fitConfidence,
      styledForYou: styledForYou,
      source: source,
    );
  }
}

class TrialSession {
  const TrialSession({
    required this.id,
    required this.userId,
    this.userName = '',
    this.userPhone = '',
    this.userCity = '',
    this.userTrialScore = 0,
    this.userRiskScore = 0,
    this.userFlagged = false,
    required this.status,
    this.approvalStatus = 'approved',
    this.approvedBy = '',
    this.approvalReason = '',
    required this.items,
    this.recommendedItems = const <TrialSessionItem>[],
    this.recommendedSize = '',
    this.fitConfidence = 0,
    this.keptItems = const <String>[],
    this.returnedItems = const <String>[],
    this.addressLabel = '',
    this.deliverySlot = '',
    this.deliveryWindowLabel = '',
    this.experienceType = 'premium',
    this.trialFee = 99,
    this.subtotal = 0,
    this.paymentStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userCity;
  final double userTrialScore;
  final double userRiskScore;
  final bool userFlagged;
  final String status;
  final String approvalStatus;
  final String approvedBy;
  final String approvalReason;
  final List<TrialSessionItem> items;
  final List<TrialSessionItem> recommendedItems;
  final String recommendedSize;
  final double fitConfidence;
  final List<String> keptItems;
  final List<String> returnedItems;
  final String addressLabel;
  final String deliverySlot;
  final String deliveryWindowLabel;
  final String experienceType;
  final double trialFee;
  final double subtotal;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isBooked =>
      status == 'booked' ||
      status == 'confirmed' ||
      status == 'out_for_trial_delivery';
  bool get isApprovalPending => approvalStatus == 'pending';
  bool get isApprovalRejected => approvalStatus == 'rejected';
  bool get isApprovalApproved => approvalStatus == 'approved';
  bool get isInProgress => status == 'trial_in_progress';
  bool get isCompleted => status == 'completed';
  bool get isResolved =>
      status == 'converted_to_order' ||
      status == 'converted_to_tailoring' ||
      status == 'cancelled';

  factory TrialSession.fromMap(Map<String, dynamic> map) {
    final itemMaps = (map['items'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => TrialSessionItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final recommendedItemMaps =
        (map['recommendedItems'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) =>
                TrialSessionItem.fromMap(Map<String, dynamic>.from(item)))
            .toList();
    final derivedPrimary = [
      ...itemMaps,
      ...recommendedItemMaps,
    ].fold<TrialSessionItem?>(
      null,
      (current, item) => item.fitConfidence > (current?.fitConfidence ?? -1)
          ? item
          : current,
    );

    return TrialSession(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      userPhone: map['userPhone']?.toString() ?? '',
      userCity: map['userCity']?.toString() ?? '',
      userTrialScore: ((map['userTrialScore'] ?? 0) as num).toDouble(),
      userRiskScore: ((map['userRiskScore'] ?? 0) as num).toDouble(),
      userFlagged: map['userFlagged'] == true,
      status: map['status']?.toString() ?? 'booked',
      approvalStatus: map['approvalStatus']?.toString() ?? 'approved',
      approvedBy: map['approvedBy']?.toString() ?? '',
      approvalReason: map['approvalReason']?.toString() ?? '',
      items: itemMaps,
      recommendedItems: recommendedItemMaps,
      recommendedSize:
          map['recommendedSize']?.toString() ?? derivedPrimary?.recommendedSize ?? '',
      fitConfidence:
          ((map['fitConfidence'] ?? derivedPrimary?.fitConfidence ?? 0) as num)
              .toDouble(),
      keptItems: (map['keptItems'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      returnedItems: (map['returnedItems'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      addressLabel: map['addressLabel']?.toString() ?? '',
      deliverySlot: map['deliverySlot']?.toString() ?? '',
      deliveryWindowLabel: map['deliveryWindowLabel']?.toString() ?? '',
      experienceType: map['experienceType']?.toString() ?? 'premium',
      trialFee: ((map['trialFee'] ?? 99) as num).toDouble(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      paymentStatus: map['paymentStatus']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }
}
