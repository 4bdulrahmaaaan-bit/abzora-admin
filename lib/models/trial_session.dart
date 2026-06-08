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
    this.storeId = '',
  });

  final String productId;
  final String name;
  final String imageUrl;
  final double price;
  final String recommendedSize;
  final double fitConfidence;
  final bool styledForYou;
  final String source;
  final String storeId;

  factory TrialSessionItem.fromMap(Map<String, dynamic> map) {
    return TrialSessionItem(
      productId: map['productId']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Abianzo Item',
      imageUrl: map['imageUrl']?.toString() ?? map['image']?.toString() ?? '',
      price: ((map['price'] ?? 0) as num).toDouble(),
      recommendedSize:
          map['recommendedSize']?.toString() ?? map['size']?.toString() ?? '',
      fitConfidence: ((map['fitConfidence'] ?? map['matchScore'] ?? 0) as num)
          .toDouble(),
      styledForYou: map['styledForYou'] == true,
      source: map['source']?.toString() ?? 'selected',
      storeId: map['storeId']?.toString() ?? '',
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
        'storeId': storeId,
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
      storeId: product.storeId,
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
    required this.status,
    required this.items,
    this.recommendedItems = const <TrialSessionItem>[],
    this.recommendedSize = '',
    this.fitConfidence = 0,
    this.keptItems = const <String>[],
    this.returnedItems = const <String>[],
    this.addressLabel = '',
    this.deliverySlot = '',
    this.bookingPaymentId,
    this.bookingOrderId,
    this.bookingFeeAmount = 99.0,
    this.finalPaymentId,
    this.finalOrderId,
    this.finalAmount,
    this.deliveryWindowLabel = '',
    this.trialFee = 99,
    this.subtotal = 0,
    this.bookingFeePaid = false,
    this.feeAdjustmentAmount = 0,
    this.trialDurationMinutes = 30,
    this.trialStartedAt,
    this.paymentStatus = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userCity;
  final String status;
  final List<TrialSessionItem> items;
  final List<TrialSessionItem> recommendedItems;
  final String recommendedSize;
  final double fitConfidence;
  final List<String> keptItems;
  final List<String> returnedItems;
  final String addressLabel;
  final String deliverySlot;
  final String? bookingPaymentId;
  final String? bookingOrderId;
  final double bookingFeeAmount;
  final String? finalPaymentId;
  final String? finalOrderId;
  final double? finalAmount;
  final String deliveryWindowLabel;
  final double trialFee;
  final double subtotal;
  final bool bookingFeePaid;
  final double feeAdjustmentAmount;
  final int trialDurationMinutes;
  final DateTime? trialStartedAt;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isBooked =>
      status == 'booked' ||
      status == 'rider_assigned' ||
      status == 'confirmed' ||
      status == 'out_for_trial_delivery';
  bool get isInProgress => status == 'trial_in_progress';
  bool get isAwaitingPayment => status == 'awaiting_final_payment';
  bool get isCompleted => status == 'completed';
  bool get isResolved =>
      status == 'converted_to_order' ||
      status == 'converted_to_tailoring' ||
      status == 'cancelled' ||
      status == 'no_show';

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
      status: map['status']?.toString() ?? 'booked',
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
      bookingPaymentId: map['bookingPaymentId']?.toString(),
      bookingOrderId: map['bookingOrderId']?.toString(),
      bookingFeeAmount: (map['bookingFeeAmount'] as num?)?.toDouble() ?? 99.0,
      finalPaymentId: map['finalPaymentId']?.toString(),
      finalOrderId: map['finalOrderId']?.toString(),
      finalAmount: (map['finalAmount'] as num?)?.toDouble(),
      deliveryWindowLabel: map['deliveryWindowLabel']?.toString() ?? '',
      trialFee: ((map['trialFee'] ?? 99) as num).toDouble(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      bookingFeePaid: map['bookingFeePaid'] == true,
      feeAdjustmentAmount: ((map['feeAdjustmentAmount'] ?? 0) as num).toDouble(),
      trialDurationMinutes: ((map['trialDurationMinutes'] ?? 30) as num).toInt(),
      trialStartedAt: DateTime.tryParse(map['trialStartedAt']?.toString() ?? ''),
      paymentStatus: map['paymentStatus']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }
}

