import 'package:flutter/material.dart';
import '../services/image_url_service.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final String? phone;
  final String? address;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double deliveryRadiusKm;
  final String? locationUpdatedAt;
  final String? createdAt;
  final String role;
  final bool isActive;
  final String? storeId;
  final double walletBalance;
  final Map<String, bool> roles;
  final String riderApprovalStatus;
  final String? riderVehicleType;
  final String? riderLicenseNumber;
  final String? riderCity;
  final String? referralCode;
  final String? referredBy;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.phone,
    this.address,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
    this.deliveryRadiusKm = 10,
    this.locationUpdatedAt,
    this.createdAt,
    required this.role,
    this.isActive = true,
    this.storeId,
    this.walletBalance = 0,
    this.roles = const {},
    this.riderApprovalStatus = 'pending',
    this.riderVehicleType,
    this.riderLicenseNumber,
    this.riderCity,
    this.referralCode,
    this.referredBy,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'phone': phone,
        'phone_number': phone,
        'address': address,
        'area': area,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'deliveryRadiusKm': deliveryRadiusKm,
        'locationUpdatedAt': locationUpdatedAt,
        'created_at': createdAt,
        'role': role,
        'isActive': isActive,
          'storeId': storeId,
          'walletBalance': walletBalance,
          'roles': roles,
        'riderApprovalStatus': riderApprovalStatus,
        'riderVehicleType': riderVehicleType,
        'riderLicenseNumber': riderLicenseNumber,
        'riderCity': riderCity,
        'referralCode': referralCode,
        'referredBy': referredBy,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        email: map['email'] ?? '',
        profileImageUrl: map['profileImageUrl'],
        phone: map['phone'] ?? map['phone_number'],
        address: map['address'],
        area: map['area'],
        city: map['city'],
        latitude: map['latitude'] == null ? null : (map['latitude'] as num).toDouble(),
        longitude: map['longitude'] == null ? null : (map['longitude'] as num).toDouble(),
        deliveryRadiusKm: (map['deliveryRadiusKm'] ?? 10).toDouble(),
        locationUpdatedAt: map['locationUpdatedAt'],
        createdAt: map['created_at'],
        role: map['role'] ?? 'user',
        isActive: map['isActive'] ?? true,
          storeId: map['storeId'],
          walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
        roles: Map<String, bool>.from((map['roles'] as Map?) ?? const {}),
        riderApprovalStatus: map['riderApprovalStatus'] ?? 'pending',
        riderVehicleType: map['riderVehicleType'],
        riderLicenseNumber: map['riderLicenseNumber'],
        riderCity: map['riderCity'],
        referralCode: map['referralCode'] ?? (map['growth'] is Map ? (map['growth']['referralCode']) : null),
        referredBy: map['referredBy'],
      );

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImageUrl,
    String? phone,
    String? address,
    String? area,
    String? city,
    double? latitude,
    double? longitude,
    double? deliveryRadiusKm,
    String? locationUpdatedAt,
    String? createdAt,
    String? role,
    bool? isActive,
      String? storeId,
      double? walletBalance,
    Map<String, bool>? roles,
    String? riderApprovalStatus,
    String? riderVehicleType,
    String? riderLicenseNumber,
    String? riderCity,
    String? referralCode,
    String? referredBy,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      area: area ?? this.area,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
        storeId: storeId ?? this.storeId,
        walletBalance: walletBalance ?? this.walletBalance,
        roles: roles ?? this.roles,
      riderApprovalStatus: riderApprovalStatus ?? this.riderApprovalStatus,
      riderVehicleType: riderVehicleType ?? this.riderVehicleType,
      riderLicenseNumber: riderLicenseNumber ?? this.riderLicenseNumber,
      riderCity: riderCity ?? this.riderCity,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
    );
  }
}

class Store {
  final String id;
  final String storeId;
  final String ownerId;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final String address;
  final String city;
  final bool isApproved;
  final bool isActive;
  final bool isFeatured;
  final String approvalStatus;
  final String logoUrl;
  final String bannerImageUrl;
  final String tagline;
  final double commissionRate;
  final double walletBalance;
  final double? latitude;
  final double? longitude;
  final String category;
  final double vendorScore;
  final int vendorRank;
  final String vendorVisibility;
  final VendorPerformanceMetrics performanceMetrics;

  Store({
    required this.id,
    String? storeId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    this.reviewCount = 0,
    required this.address,
    this.city = '',
    this.isApproved = true,
    this.isActive = true,
    this.isFeatured = false,
    this.approvalStatus = 'approved',
    this.logoUrl = '',
    this.bannerImageUrl = '',
    this.tagline = '',
    this.commissionRate = 0.12,
    this.walletBalance = 0,
    this.latitude,
    this.longitude,
    this.category = '',
    this.vendorScore = 0,
    this.vendorRank = 0,
    this.vendorVisibility = 'normal',
    this.performanceMetrics = const VendorPerformanceMetrics(),
  }) : storeId = storeId ?? id;

  Map<String, dynamic> toMap() => {
        'id': id,
        'store_id': storeId,
        'ownerId': ownerId,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'address': address,
        'city': city,
        'isApproved': isApproved,
        'isActive': isActive,
        'isFeatured': isFeatured,
        'approvalStatus': approvalStatus,
        'logoUrl': logoUrl,
        'bannerImageUrl': bannerImageUrl,
        'tagline': tagline,
        'commissionRate': commissionRate,
        'walletBalance': walletBalance,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'vendorScore': vendorScore,
        'vendorRank': vendorRank,
        'vendorVisibility': vendorVisibility,
        'performanceMetrics': performanceMetrics.toMap(),
      };

  factory Store.fromMap(Map<String, dynamic> map, String docId) => Store(
        id: docId,
        storeId: map['store_id'] ?? map['id'] ?? docId,
        ownerId: map['ownerId'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        rating: (map['rating'] ?? 0.0).toDouble(),
        reviewCount: map['reviewCount'] ?? 0,
        address: map['address'] ?? map['location'] ?? '',
        city: map['city'] ?? '',
        isApproved: map['isApproved'] ?? true,
        isActive: map['isActive'] ?? true,
        isFeatured: map['isFeatured'] ?? false,
        approvalStatus: map['approvalStatus'] ?? ((map['isApproved'] ?? true) ? 'approved' : 'pending'),
        logoUrl: map['logoUrl'] ?? '',
        bannerImageUrl: map['bannerImageUrl'] ?? '',
        tagline: map['tagline'] ?? '',
        commissionRate: (map['commissionRate'] ?? 0.12).toDouble(),
        walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
        latitude: map['latitude'] == null ? null : (map['latitude'] as num).toDouble(),
        longitude: map['longitude'] == null ? null : (map['longitude'] as num).toDouble(),
        category: map['category'] ?? '',
        vendorScore: (map['vendorScore'] ?? 0.0).toDouble(),
        vendorRank: map['vendorRank'] ?? 0,
        vendorVisibility: map['vendorVisibility'] ?? 'normal',
        performanceMetrics: VendorPerformanceMetrics.fromMap(
          Map<String, dynamic>.from(map['performanceMetrics'] ?? const {}),
        ),
      );

  Store copyWith({
    String? id,
    String? storeId,
    String? ownerId,
    String? name,
    String? description,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    String? address,
    String? city,
    bool? isApproved,
    bool? isActive,
    bool? isFeatured,
    String? approvalStatus,
    String? logoUrl,
    String? bannerImageUrl,
    String? tagline,
    double? commissionRate,
    double? walletBalance,
    double? latitude,
    double? longitude,
    String? category,
    double? vendorScore,
    int? vendorRank,
    String? vendorVisibility,
    VendorPerformanceMetrics? performanceMetrics,
  }) {
    return Store(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      address: address ?? this.address,
      city: city ?? this.city,
      isApproved: isApproved ?? this.isApproved,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      tagline: tagline ?? this.tagline,
      commissionRate: commissionRate ?? this.commissionRate,
      walletBalance: walletBalance ?? this.walletBalance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      vendorScore: vendorScore ?? this.vendorScore,
      vendorRank: vendorRank ?? this.vendorRank,
      vendorVisibility: vendorVisibility ?? this.vendorVisibility,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
    );
  }
}

class VendorPerformanceMetrics {
  final int totalOrders;
  final int completedOrders;
  final double cancellationRate;
  final double returnRate;
  final double averageRating;
  final double reviewSentiment;
  final double averageDeliveryHours;
  final double averageResponseHours;
  final double totalRevenue;
  final double repeatCustomerRate;
  final String updatedAt;

  const VendorPerformanceMetrics({
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.cancellationRate = 0,
    this.returnRate = 0,
    this.averageRating = 0,
    this.reviewSentiment = 0,
    this.averageDeliveryHours = 0,
    this.averageResponseHours = 0,
    this.totalRevenue = 0,
    this.repeatCustomerRate = 0,
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'cancellationRate': cancellationRate,
        'returnRate': returnRate,
        'averageRating': averageRating,
        'reviewSentiment': reviewSentiment,
        'averageDeliveryHours': averageDeliveryHours,
        'averageResponseHours': averageResponseHours,
        'totalRevenue': totalRevenue,
        'repeatCustomerRate': repeatCustomerRate,
        'updatedAt': updatedAt,
      };

  factory VendorPerformanceMetrics.fromMap(Map<String, dynamic> map) => VendorPerformanceMetrics(
        totalOrders: map['totalOrders'] ?? 0,
        completedOrders: map['completedOrders'] ?? 0,
        cancellationRate: (map['cancellationRate'] ?? 0.0).toDouble(),
        returnRate: (map['returnRate'] ?? 0.0).toDouble(),
        averageRating: (map['averageRating'] ?? 0.0).toDouble(),
        reviewSentiment: (map['reviewSentiment'] ?? 0.0).toDouble(),
        averageDeliveryHours: (map['averageDeliveryHours'] ?? 0.0).toDouble(),
        averageResponseHours: (map['averageResponseHours'] ?? 0.0).toDouble(),
        totalRevenue: (map['totalRevenue'] ?? 0.0).toDouble(),
        repeatCustomerRate: (map['repeatCustomerRate'] ?? 0.0).toDouble(),
        updatedAt: map['updatedAt'] ?? '',
      );
}

class NearbyStore {
  final Store store;
  final double distanceKm;

  const NearbyStore({
    required this.store,
    required this.distanceKm,
  });
}

class WishlistItem {
  final String productId;
  final String storeId;
  final String name;
  final double price;
  final String image;
  final DateTime addedAt;

  const WishlistItem({
    required this.productId,
    required this.storeId,
    required this.name,
    required this.price,
    required this.image,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'storeId': storeId,
        'name': name,
        'price': price,
        'image': image,
        'addedAt': addedAt.toIso8601String(),
      };

  factory WishlistItem.fromMap(Map<String, dynamic> map, String id) {
    return WishlistItem(
      productId: map['productId'] ?? id,
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      image: map['image'] ?? '',
      addedAt: DateTime.tryParse(map['addedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class UserAddress {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String addressLine;
  final String city;
  final String state;
  final String pincode;
  final String houseDetails;
  final String landmark;
  final String locality;
  final double? latitude;
  final double? longitude;
  final String type;
  final String createdAt;

  const UserAddress({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.pincode,
    this.houseDetails = '',
    this.landmark = '',
    this.locality = '',
    this.latitude,
    this.longitude,
    this.type = 'home',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'phone': phone,
        'addressLine': addressLine,
        'city': city,
        'state': state,
        'pincode': pincode,
        'houseDetails': houseDetails,
        'landmark': landmark,
        'locality': locality,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'createdAt': createdAt,
      };

  factory UserAddress.fromMap(Map<String, dynamic> map, String id) => UserAddress(
        id: id,
        userId: map['userId'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        addressLine: map['addressLine'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        pincode: map['pincode'] ?? '',
        houseDetails: map['houseDetails'] ?? '',
        landmark: map['landmark'] ?? '',
        locality: map['locality'] ?? '',
        latitude: map['latitude'] == null ? null : (map['latitude'] as num).toDouble(),
        longitude: map['longitude'] == null ? null : (map['longitude'] as num).toDouble(),
        type: map['type'] ?? 'home',
        createdAt: map['createdAt'] ?? DateTime.now().toIso8601String(),
      );
}

class Product {
  final String id;
  final String storeId;
  final String name;
  final String brand;
  final String description;
  final double price;
  final double? basePrice;
  final double? dynamicPrice;
  final double? originalPrice;
  final double demandScore;
  final int viewCount;
  final int cartCount;
  final int purchaseCount;
  final List<String> images;
  final List<String> sizes;
  final int stock;
  final String category;
  final String subcategory;
  final bool isActive;
  final String? createdAt;
  final double rating;
  final int reviewCount;
  final String? lastPriceUpdated;
  final bool isCustomTailoring;
  final String? outfitType;
  final String? fabric;
  final Map<String, String> attributes;
  final Map<String, String> customizations;
  final Map<String, double> measurements;
  final List<String> addons;
  final String? measurementProfileLabel;
  final DateTime? neededBy;
  final String? tailoringDeliveryMode;
  final double tailoringExtraCost;

  Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.brand = '',
    required this.description,
    required this.price,
    this.basePrice,
    this.dynamicPrice,
    this.originalPrice,
    this.demandScore = 0,
    this.viewCount = 0,
    this.cartCount = 0,
    this.purchaseCount = 0,
    required this.images,
    required this.sizes,
    required this.stock,
    required this.category,
    this.subcategory = '',
    this.isActive = true,
    this.createdAt,
    this.rating = 0,
    this.reviewCount = 0,
    this.lastPriceUpdated,
    this.isCustomTailoring = false,
    this.outfitType,
    this.fabric,
    this.attributes = const {},
    this.customizations = const {},
    this.measurements = const {},
    this.addons = const [],
    this.measurementProfileLabel,
    this.neededBy,
    this.tailoringDeliveryMode,
    this.tailoringExtraCost = 0,
  });

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'name': name,
        'brand': brand,
        'description': description,
        'price': price,
        'basePrice': basePrice,
        'dynamicPrice': dynamicPrice,
        'originalPrice': originalPrice,
        'demandScore': demandScore,
        'viewCount': viewCount,
        'cartCount': cartCount,
        'purchaseCount': purchaseCount,
        'images': images,
        'sizes': sizes,
        'stock': stock,
        'category': category,
        'subcategory': subcategory,
        'isActive': isActive,
        'createdAt': createdAt,
        'rating': rating,
        'reviewCount': reviewCount,
        'lastPriceUpdated': lastPriceUpdated,
        'isCustomTailoring': isCustomTailoring,
        'outfitType': outfitType,
        'fabric': fabric,
        'attributes': attributes,
        'customizations': customizations,
        'measurements': measurements,
        'addons': addons,
        'measurementProfileLabel': measurementProfileLabel,
        'neededBy': neededBy?.toIso8601String(),
        'tailoringDeliveryMode': tailoringDeliveryMode,
        'tailoringExtraCost': tailoringExtraCost,
      };

  factory Product.fromMap(Map<String, dynamic> map, String docId) => Product(
        id: docId,
        storeId: map['storeId'] ?? '',
        name: map['name'] ?? '',
        brand: (() {
          final candidates = <String?>[
            map['brand']?.toString(),
            map['brandName']?.toString(),
          ];
          for (final candidate in candidates) {
            final value = candidate?.trim() ?? '';
            if (value.isNotEmpty) {
              return value;
            }
          }
          return '';
        })(),
        description: map['description'] ?? '',
        price: (map['price'] ?? 0.0).toDouble(),
        basePrice: map['basePrice'] == null ? null : (map['basePrice'] as num).toDouble(),
        dynamicPrice: map['dynamicPrice'] == null ? null : (map['dynamicPrice'] as num).toDouble(),
        originalPrice: map['originalPrice'] == null ? null : (map['originalPrice'] as num).toDouble(),
        demandScore: (map['demandScore'] ?? 0.0).toDouble(),
        viewCount: map['viewCount'] ?? 0,
        cartCount: map['cartCount'] ?? 0,
        purchaseCount: map['purchaseCount'] ?? 0,
        images: ImageUrlService.normalizeStoredImages(map['images'] as List? ?? const []),
        sizes: List<String>.from(map['sizes'] ?? []),
        stock: map['stock'] ?? 0,
        category: map['category'] ?? '',
        subcategory: map['subcategory'] ?? '',
        isActive: map['isActive'] ?? true,
        createdAt: map['createdAt'],
        rating: (map['rating'] ?? 0.0).toDouble(),
        reviewCount: map['reviewCount'] ?? 0,
        lastPriceUpdated: map['lastPriceUpdated'],
        isCustomTailoring: map['isCustomTailoring'] ?? false,
        outfitType: map['outfitType'],
        fabric: map['fabric'],
        attributes: Map<String, String>.from((map['attributes'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        )),
        customizations: Map<String, String>.from(map['customizations'] ?? const {}),
        measurements: (map['measurements'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        addons: List<String>.from(map['addons'] ?? const []),
        measurementProfileLabel: map['measurementProfileLabel'],
        neededBy: map['neededBy'] != null ? DateTime.tryParse(map['neededBy']) : null,
        tailoringDeliveryMode: map['tailoringDeliveryMode'],
        tailoringExtraCost: (map['tailoringExtraCost'] ?? 0.0).toDouble(),
      );

  double get effectivePrice => dynamicPrice ?? price;

  bool get hasDynamicDiscount =>
      basePrice != null &&
      effectivePrice < (basePrice ?? effectivePrice);

  bool get isLimitedStock => stock > 0 && stock <= 5;
}

class OrderModel {
  final String id;
  final String userId;
  final String storeId;
  final String? riderId;
  final double totalAmount;
  final String status;
  final String paymentMethod;
  final DateTime timestamp;
  final List<OrderItem> items;
  final String shippingLabel;
  final String shippingAddress;
  final double extraCharges;
  final double subtotal;
  final double taxAmount;
  final double platformCommission;
  final double vendorEarnings;
  final String payoutStatus;
  final String? payoutId;
  final String trackingId;
  final String deliveryStatus;
  final String assignedDeliveryPartner;
  final String invoiceNumber;
  final String orderType;
  final Map<String, String> trackingTimestamps;
  final double? riderLatitude;
  final double? riderLongitude;
  final String? riderLocationUpdatedAt;
  final String? createdAt;
  final String? updatedAt;
  final String? deliveredAt;
  final bool isConfirmed;
  final bool isDelivered;
  final bool payoutProcessed;
  final String? paymentReference;
  final String? idempotencyKey;
  final bool isPaymentVerified;
  final String refundStatus;
  final String returnStatus;
  final double walletCreditUsed;

  OrderModel({
    required this.id,
    required this.userId,
    required this.storeId,
    this.riderId,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.timestamp,
    required this.items,
    this.shippingLabel = '',
    this.shippingAddress = '',
    this.extraCharges = 0,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.platformCommission = 0,
    this.vendorEarnings = 0,
    this.payoutStatus = 'Pending',
    this.payoutId,
    this.trackingId = '',
    this.deliveryStatus = 'Pending',
    this.assignedDeliveryPartner = 'Unassigned',
    this.invoiceNumber = '',
    this.orderType = 'marketplace',
    this.trackingTimestamps = const {},
    this.riderLatitude,
    this.riderLongitude,
    this.riderLocationUpdatedAt,
    this.createdAt,
    this.updatedAt,
    this.deliveredAt,
    this.isConfirmed = false,
    this.isDelivered = false,
    this.payoutProcessed = false,
    this.paymentReference,
    this.idempotencyKey,
      this.isPaymentVerified = false,
      this.refundStatus = '',
      this.returnStatus = '',
      this.walletCreditUsed = 0,
    });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'storeId': storeId,
        'riderId': riderId,
        'totalAmount': totalAmount,
        'status': status,
        'paymentMethod': paymentMethod,
        'timestamp': timestamp.toIso8601String(),
        'items': items.map((item) => item.toMap()).toList(),
        'shippingLabel': shippingLabel,
        'shippingAddress': shippingAddress,
        'extraCharges': extraCharges,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'platformCommission': platformCommission,
        'vendorEarnings': vendorEarnings,
        'payoutStatus': payoutStatus,
        'payoutId': payoutId,
        'trackingId': trackingId,
        'deliveryStatus': deliveryStatus,
        'assignedDeliveryPartner': assignedDeliveryPartner,
        'invoiceNumber': invoiceNumber,
        'orderType': orderType,
          'trackingTimestamps': trackingTimestamps,
          'riderLatitude': riderLatitude,
          'riderLongitude': riderLongitude,
          'riderLocationUpdatedAt': riderLocationUpdatedAt,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'deliveredAt': deliveredAt,
          'isConfirmed': isConfirmed,
          'isDelivered': isDelivered,
          'payoutProcessed': payoutProcessed,
          'paymentReference': paymentReference,
          'idempotencyKey': idempotencyKey,
            'isPaymentVerified': isPaymentVerified,
            'refundStatus': refundStatus,
            'returnStatus': returnStatus,
            'walletCreditUsed': walletCreditUsed,
          };

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) => OrderModel(
        id: docId,
        userId: map['userId'] ?? '',
        storeId: map['storeId'] ?? '',
        riderId: map['riderId'],
        totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
        status: map['status'] ?? 'Placed',
        paymentMethod: map['paymentMethod'] ?? 'COD',
        timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
        items: (map['items'] as List? ?? const []).map((item) => OrderItem.fromMap(item)).toList(),
        shippingLabel: map['shippingLabel'] ?? '',
        shippingAddress: map['shippingAddress'] ?? '',
        extraCharges: (map['extraCharges'] ?? 0.0).toDouble(),
        subtotal: (map['subtotal'] ?? 0.0).toDouble(),
        taxAmount: (map['taxAmount'] ?? 0.0).toDouble(),
        platformCommission: (map['platformCommission'] ?? 0.0).toDouble(),
        vendorEarnings: (map['vendorEarnings'] ?? 0.0).toDouble(),
        payoutStatus: map['payoutStatus'] ?? 'Pending',
        payoutId: map['payoutId'],
        trackingId: map['trackingId'] ?? '',
        deliveryStatus: map['deliveryStatus'] ?? 'Pending',
        assignedDeliveryPartner: map['assignedDeliveryPartner'] ?? 'Unassigned',
        invoiceNumber: map['invoiceNumber'] ?? '',
        orderType: map['orderType'] ?? 'marketplace',
          trackingTimestamps: Map<String, String>.from(map['trackingTimestamps'] ?? const {}),
          riderLatitude: map['riderLatitude'] == null ? null : (map['riderLatitude'] as num).toDouble(),
          riderLongitude: map['riderLongitude'] == null ? null : (map['riderLongitude'] as num).toDouble(),
          riderLocationUpdatedAt: map['riderLocationUpdatedAt'],
          createdAt: map['createdAt'],
          updatedAt: map['updatedAt'],
          deliveredAt: map['deliveredAt'],
          isConfirmed: map['isConfirmed'] ?? false,
          isDelivered: map['isDelivered'] ?? false,
          payoutProcessed: map['payoutProcessed'] ?? false,
          paymentReference: map['paymentReference'],
          idempotencyKey: map['idempotencyKey'],
        isPaymentVerified: map['isPaymentVerified'] ?? false,
        refundStatus: map['refundStatus'] ?? '',
        returnStatus: map['returnStatus'] ?? '',
        walletCreditUsed: ((map['walletCreditUsed'] ?? 0) as num).toDouble(),
      );
  }

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String size;
  final String imageUrl;
  final bool isCustomTailoring;
  final DateTime? neededBy;
  final String? tailoringDeliveryMode;
  final String? measurementProfileLabel;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.size = '',
    this.imageUrl = '',
    this.isCustomTailoring = false,
    this.neededBy,
    this.tailoringDeliveryMode,
    this.measurementProfileLabel,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'price': price,
        'size': size,
        'imageUrl': imageUrl,
        'isCustomTailoring': isCustomTailoring,
        'neededBy': neededBy?.toIso8601String(),
        'tailoringDeliveryMode': tailoringDeliveryMode,
        'measurementProfileLabel': measurementProfileLabel,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        quantity: map['quantity'] ?? 1,
        price: (map['price'] ?? 0.0).toDouble(),
        size: map['size'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        isCustomTailoring: map['isCustomTailoring'] ?? false,
        neededBy: map['neededBy'] != null ? DateTime.tryParse(map['neededBy']) : null,
        tailoringDeliveryMode: map['tailoringDeliveryMode'],
        measurementProfileLabel: map['measurementProfileLabel'],
      );
}

class RefundRequest {
  final String id;
  final String orderId;
  final String userId;
  final String reason;
  final String status;
  final String createdAt;
  final String? processedAt;
  final String? processedBy;
  final String? rejectionReason;
  final String? gatewayRefundId;
  final int fraudScore;
  final String fraudDecision;
  final List<String> fraudReasons;

  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
    this.gatewayRefundId,
    this.fraudScore = 0,
    this.fraudDecision = 'approve',
    this.fraudReasons = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'userId': userId,
        'reason': reason,
        'status': status,
        'createdAt': createdAt,
        'processedAt': processedAt,
        'processedBy': processedBy,
        'rejectionReason': rejectionReason,
        'gatewayRefundId': gatewayRefundId,
        'fraudScore': fraudScore,
        'fraudDecision': fraudDecision,
        'fraudReasons': fraudReasons,
      };

  factory RefundRequest.fromMap(Map<String, dynamic> map, String id) => RefundRequest(
        id: id,
        orderId: map['orderId'] ?? '',
        userId: map['userId'] ?? '',
        reason: map['reason'] ?? '',
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] ?? '',
        processedAt: map['processedAt'],
        processedBy: map['processedBy'],
        rejectionReason: map['rejectionReason'],
        gatewayRefundId: map['gatewayRefundId'],
        fraudScore: map['fraudScore'] ?? 0,
        fraudDecision: map['fraudDecision'] ?? 'approve',
        fraudReasons: List<String>.from((map['fraudReasons'] as List?) ?? const []),
      );

  RefundRequest copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? reason,
    String? status,
    String? createdAt,
    String? processedAt,
    String? processedBy,
    String? rejectionReason,
    String? gatewayRefundId,
    int? fraudScore,
    String? fraudDecision,
    List<String>? fraudReasons,
  }) {
    return RefundRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      gatewayRefundId: gatewayRefundId ?? this.gatewayRefundId,
      fraudScore: fraudScore ?? this.fraudScore,
      fraudDecision: fraudDecision ?? this.fraudDecision,
      fraudReasons: fraudReasons ?? this.fraudReasons,
    );
  }
}

class ReturnRequest {
  final String id;
  final String orderId;
  final String userId;
  final String address;
  final String reason;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? riderId;
  final String? pickupTaskId;
  final String? approvedAt;
  final String? pickedAt;
  final String? completedAt;
  final String? processedBy;
  final String? imageUrl;
  final String? rejectionReason;
  final String? refundRequestId;

  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.address,
    required this.reason,
    this.status = 'requested',
    required this.createdAt,
    required this.updatedAt,
    this.riderId,
    this.pickupTaskId,
    this.approvedAt,
    this.pickedAt,
    this.completedAt,
    this.processedBy,
    this.imageUrl,
    this.rejectionReason,
    this.refundRequestId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'userId': userId,
        'address': address,
        'reason': reason,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'riderId': riderId,
        'pickupTaskId': pickupTaskId,
        'approvedAt': approvedAt,
        'pickedAt': pickedAt,
        'completedAt': completedAt,
        'processedBy': processedBy,
        'imageUrl': imageUrl,
        'rejectionReason': rejectionReason,
        'refundRequestId': refundRequestId,
      };

  factory ReturnRequest.fromMap(Map<String, dynamic> map, String id) => ReturnRequest(
        id: id,
        orderId: map['orderId'] ?? '',
        userId: map['userId'] ?? '',
        address: map['address'] ?? '',
        reason: map['reason'] ?? '',
        status: map['status'] ?? 'requested',
        createdAt: map['createdAt'] ?? '',
        updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
        riderId: map['riderId'],
        pickupTaskId: map['pickupTaskId'],
        approvedAt: map['approvedAt'],
        pickedAt: map['pickedAt'],
        completedAt: map['completedAt'],
        processedBy: map['processedBy'],
        imageUrl: map['imageUrl'],
        rejectionReason: map['rejectionReason'],
        refundRequestId: map['refundRequestId'],
      );

  ReturnRequest copyWith({
    String? id,
    String? orderId,
    String? userId,
    String? address,
    String? reason,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? riderId,
    String? pickupTaskId,
    String? approvedAt,
    String? pickedAt,
    String? completedAt,
    String? processedBy,
    String? imageUrl,
    String? rejectionReason,
    String? refundRequestId,
  }) {
    return ReturnRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      address: address ?? this.address,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      riderId: riderId ?? this.riderId,
      pickupTaskId: pickupTaskId ?? this.pickupTaskId,
      approvedAt: approvedAt ?? this.approvedAt,
      pickedAt: pickedAt ?? this.pickedAt,
      completedAt: completedAt ?? this.completedAt,
      processedBy: processedBy ?? this.processedBy,
      imageUrl: imageUrl ?? this.imageUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      refundRequestId: refundRequestId ?? this.refundRequestId,
    );
  }
}

class PickupTask {
  final String id;
  final String returnId;
  final String riderId;
  final String status;
  final String pickupLocation;
  final String createdAt;
  final String updatedAt;

  const PickupTask({
    required this.id,
    required this.returnId,
    required this.riderId,
    required this.status,
    required this.pickupLocation,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'returnId': returnId,
        'riderId': riderId,
        'status': status,
        'pickupLocation': pickupLocation,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory PickupTask.fromMap(Map<String, dynamic> map, String id) => PickupTask(
        id: id,
        returnId: map['returnId'] ?? '',
        riderId: map['riderId'] ?? '',
        status: map['status'] ?? 'assigned',
        pickupLocation: map['pickupLocation'] ?? '',
        createdAt: map['createdAt'] ?? '',
        updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
      );
}

class UnifiedRiderTask {
  final String id;
  final String type;
  final String? orderId;
  final String? returnId;
  final String userId;
  final String address;
  final String status;
  final String riderId;
  final String createdAt;
  final String updatedAt;

  const UnifiedRiderTask({
    required this.id,
    required this.type,
    this.orderId,
    this.returnId,
    required this.userId,
    required this.address,
    required this.status,
    required this.riderId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'orderId': orderId,
        'returnId': returnId,
        'userId': userId,
        'address': address,
        'status': status,
        'riderId': riderId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory UnifiedRiderTask.fromMap(Map<String, dynamic> map, String id) => UnifiedRiderTask(
        id: id,
        type: map['type'] ?? 'delivery',
        orderId: map['orderId'],
        returnId: map['returnId'],
        userId: map['userId'] ?? '',
        address: map['address'] ?? '',
        status: map['status'] ?? 'assigned',
        riderId: map['riderId'] ?? '',
        createdAt: map['createdAt'] ?? '',
        updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
      );
}

class RefundFraudLog {
  final String id;
  final String refundId;
  final String orderId;
  final String userId;
  final int riskScore;
  final String decision;
  final List<String> reasons;
  final String createdAt;

  const RefundFraudLog({
    required this.id,
    required this.refundId,
    required this.orderId,
    required this.userId,
    required this.riskScore,
    required this.decision,
    required this.reasons,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'refundId': refundId,
        'orderId': orderId,
        'userId': userId,
        'riskScore': riskScore,
        'decision': decision,
        'reasons': reasons,
        'createdAt': createdAt,
      };

  factory RefundFraudLog.fromMap(Map<String, dynamic> map, String id) => RefundFraudLog(
        id: id,
        refundId: map['refundId'] ?? '',
        orderId: map['orderId'] ?? '',
        userId: map['userId'] ?? '',
        riskScore: map['riskScore'] ?? 0,
        decision: map['decision'] ?? 'review',
        reasons: List<String>.from((map['reasons'] as List?) ?? const []),
        createdAt: map['createdAt'] ?? '',
      );
}

class BookingModel {
  final String id;
  final String userId;
  final String tailorId;
  final String tailorName;
  final String outfitType;
  final DateTime appointmentDate;
  final String timeSlot;
  final String status;
  final String notes;

  BookingModel({
    required this.id,
    required this.userId,
    required this.tailorId,
    required this.tailorName,
    required this.outfitType,
    required this.appointmentDate,
    required this.timeSlot,
    required this.status,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'tailorId': tailorId,
        'tailorName': tailorName,
        'outfitType': outfitType,
        'appointmentDate': appointmentDate.toIso8601String(),
        'timeSlot': timeSlot,
        'status': status,
        'notes': notes,
      };

  factory BookingModel.fromMap(Map<String, dynamic> map, String docId) => BookingModel(
        id: docId,
        userId: map['userId'] ?? '',
        tailorId: map['tailorId'] ?? '',
        tailorName: map['tailorName'] ?? '',
        outfitType: map['outfitType'] ?? '',
        appointmentDate: DateTime.parse(map['appointmentDate'] ?? DateTime.now().toIso8601String()),
        timeSlot: map['timeSlot'] ?? '',
        status: map['status'] ?? 'Pending',
        notes: map['notes'] ?? '',
      );
}

class MeasurementProfile {
  final String id;
  final String userId;
  final String label;
  final String method;
  final String unit;
  final double chest;
  final double shoulder;
  final double waist;
  final double sleeve;
  final double length;
  final String? standardSize;
  final String? recommendedSize;
  final String? sourceProfileId;

  MeasurementProfile({
    required this.id,
    required this.userId,
    required this.label,
    this.method = 'manual',
    this.unit = 'cm',
    required this.chest,
    required this.shoulder,
    required this.waist,
    required this.sleeve,
    required this.length,
    this.standardSize,
    this.recommendedSize,
    this.sourceProfileId,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'label': label,
        'method': method,
        'unit': unit,
        'chest': chest,
        'shoulder': shoulder,
        'waist': waist,
        'sleeve': sleeve,
        'length': length,
        'standardSize': standardSize,
        'recommendedSize': recommendedSize,
        'sourceProfileId': sourceProfileId,
      };

  factory MeasurementProfile.fromMap(Map<String, dynamic> map, String docId) => MeasurementProfile(
        id: docId,
        userId: map['userId'] ?? '',
        label: map['label'] ?? '',
        method: map['method'] ?? 'manual',
        unit: map['unit'] ?? 'cm',
        chest: (map['chest'] ?? 0.0).toDouble(),
        shoulder: (map['shoulder'] ?? 0.0).toDouble(),
        waist: (map['waist'] ?? 0.0).toDouble(),
        sleeve: (map['sleeve'] ?? 0.0).toDouble(),
        length: (map['length'] ?? 0.0).toDouble(),
        standardSize: map['standardSize'],
        recommendedSize: map['recommendedSize'],
        sourceProfileId: map['sourceProfileId'],
      );
}

class BodyProfile {
  final double heightCm;
  final double weightKg;
  final String bodyType;
  final String recommendedSize;
  final String pantSize;
  final double? shoulderCm;
  final double? chestCm;
  final double? waistCm;
  final double? hipCm;
  final double? confidence;
  final String updatedAt;

  const BodyProfile({
    required this.heightCm,
    required this.weightKg,
    required this.bodyType,
    required this.recommendedSize,
    this.pantSize = '',
    this.shoulderCm,
    this.chestCm,
    this.waistCm,
    this.hipCm,
    this.confidence,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bodyType': bodyType,
        'size': recommendedSize,
        'recommendedSize': recommendedSize,
        'pantSize': pantSize,
        'shoulderCm': shoulderCm,
        'chestCm': chestCm,
        'waistCm': waistCm,
        'hipCm': hipCm,
        'confidence': confidence,
        'updatedAt': updatedAt,
      };

  factory BodyProfile.fromMap(Map<String, dynamic> map) => BodyProfile(
        heightCm: (map['heightCm'] ?? map['height'] ?? 0.0).toDouble(),
        weightKg: (map['weightKg'] ?? map['weight'] ?? 0.0).toDouble(),
        bodyType: map['bodyType'] ?? 'regular',
        recommendedSize:
            (map['recommendedSize'] ?? map['size'] ?? '').toString(),
        pantSize: (map['pantSize'] ?? '').toString(),
        shoulderCm: map['shoulderCm'] == null
            ? null
            : (map['shoulderCm'] as num).toDouble(),
        chestCm: map['chestCm'] == null
            ? null
            : (map['chestCm'] as num).toDouble(),
        waistCm: map['waistCm'] == null
            ? null
            : (map['waistCm'] as num).toDouble(),
        hipCm: map['hipCm'] == null ? null : (map['hipCm'] as num).toDouble(),
        confidence: map['confidence'] == null
            ? null
            : (map['confidence'] as num).toDouble(),
        updatedAt:
            (map['updatedAt'] ?? DateTime.now().toIso8601String()).toString(),
      );

  BodyProfile copyWith({
    double? heightCm,
    double? weightKg,
    String? bodyType,
    String? recommendedSize,
    String? pantSize,
    double? shoulderCm,
    double? chestCm,
    double? waistCm,
    double? hipCm,
    double? confidence,
    String? updatedAt,
  }) {
    return BodyProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bodyType: bodyType ?? this.bodyType,
      recommendedSize: recommendedSize ?? this.recommendedSize,
      pantSize: pantSize ?? this.pantSize,
      shoulderCm: shoulderCm ?? this.shoulderCm,
      chestCm: chestCm ?? this.chestCm,
      waistCm: waistCm ?? this.waistCm,
      hipCm: hipCm ?? this.hipCm,
      confidence: confidence ?? this.confidence,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String targetId;
  final String targetType;
  final double rating;
  final String comment;
  final String? imagePath;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.targetId,
    required this.targetType,
    required this.rating,
    required this.comment,
    this.imagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'targetId': targetId,
        'targetType': targetType,
        'rating': rating,
        'comment': comment,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) => ReviewModel(
        id: docId,
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? '',
        targetId: map['targetId'] ?? '',
        targetType: map['targetType'] ?? 'product',
        rating: (map['rating'] ?? 0.0).toDouble(),
        comment: map['comment'] ?? '',
        imagePath: map['imagePath'],
        createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime timestamp;
  final String audienceRole;
  final String? userId;
  final String? storeId;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.timestamp,
    this.audienceRole = 'user',
    this.userId,
    this.storeId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'timestamp': timestamp.toIso8601String(),
        'audienceRole': audienceRole,
        'userId': userId,
        'storeId': storeId,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        type: map['type'] ?? 'general',
        isRead: map['isRead'] ?? false,
        timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
        audienceRole: map['audienceRole'] ?? 'user',
        userId: map['userId'],
        storeId: map['storeId'],
      );
}

class UserActivitySummary {
  final String userId;
  final int loginCount;
  final int productViewCount;
  final int cartItemCount;
  final int orderCount;
  final double totalSpend;
  final String? lastLoginAt;
  final String? lastActiveAt;
  final String? lastProductViewAt;
  final String? lastCartActivityAt;
  final String? lastOrderAt;
  final String? cartAbandonedAt;
  final String? lastViewedProductId;
  final bool cartAbandoned;
  final String segment;
  final String? favoriteCategory;
  final List<String> behaviorFlags;

  const UserActivitySummary({
    required this.userId,
    this.loginCount = 0,
    this.productViewCount = 0,
    this.cartItemCount = 0,
    this.orderCount = 0,
    this.totalSpend = 0,
    this.lastLoginAt,
    this.lastActiveAt,
    this.lastProductViewAt,
    this.lastCartActivityAt,
    this.lastOrderAt,
    this.cartAbandonedAt,
    this.lastViewedProductId,
    this.cartAbandoned = false,
    this.segment = 'new',
    this.favoriteCategory,
    this.behaviorFlags = const [],
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'loginCount': loginCount,
        'productViewCount': productViewCount,
        'cartItemCount': cartItemCount,
        'orderCount': orderCount,
        'totalSpend': totalSpend,
        'lastLoginAt': lastLoginAt,
        'lastActiveAt': lastActiveAt,
        'lastProductViewAt': lastProductViewAt,
        'lastCartActivityAt': lastCartActivityAt,
        'lastOrderAt': lastOrderAt,
        'cartAbandonedAt': cartAbandonedAt,
        'lastViewedProductId': lastViewedProductId,
        'cartAbandoned': cartAbandoned,
        'segment': segment,
        'favoriteCategory': favoriteCategory,
        'behaviorFlags': behaviorFlags,
      };

  factory UserActivitySummary.fromMap(Map<String, dynamic> map, String userId) => UserActivitySummary(
        userId: map['userId'] ?? userId,
        loginCount: ((map['loginCount'] ?? 0) as num).toInt(),
        productViewCount: ((map['productViewCount'] ?? 0) as num).toInt(),
        cartItemCount: ((map['cartItemCount'] ?? 0) as num).toInt(),
        orderCount: ((map['orderCount'] ?? 0) as num).toInt(),
        totalSpend: ((map['totalSpend'] ?? 0) as num).toDouble(),
        lastLoginAt: map['lastLoginAt'],
        lastActiveAt: map['lastActiveAt'],
        lastProductViewAt: map['lastProductViewAt'],
        lastCartActivityAt: map['lastCartActivityAt'],
        lastOrderAt: map['lastOrderAt'],
        cartAbandonedAt: map['cartAbandonedAt'],
        lastViewedProductId: map['lastViewedProductId'],
        cartAbandoned: map['cartAbandoned'] ?? false,
        segment: map['segment'] ?? 'new',
        favoriteCategory: map['favoriteCategory'],
        behaviorFlags: List<String>.from(map['behaviorFlags'] ?? const []),
      );

  UserActivitySummary copyWith({
    String? userId,
    int? loginCount,
    int? productViewCount,
    int? cartItemCount,
    int? orderCount,
    double? totalSpend,
    String? lastLoginAt,
    String? lastActiveAt,
    String? lastProductViewAt,
    String? lastCartActivityAt,
    String? lastOrderAt,
    String? cartAbandonedAt,
    String? lastViewedProductId,
    bool? cartAbandoned,
    String? segment,
    String? favoriteCategory,
    List<String>? behaviorFlags,
  }) {
    return UserActivitySummary(
      userId: userId ?? this.userId,
      loginCount: loginCount ?? this.loginCount,
      productViewCount: productViewCount ?? this.productViewCount,
      cartItemCount: cartItemCount ?? this.cartItemCount,
      orderCount: orderCount ?? this.orderCount,
      totalSpend: totalSpend ?? this.totalSpend,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastProductViewAt: lastProductViewAt ?? this.lastProductViewAt,
      lastCartActivityAt: lastCartActivityAt ?? this.lastCartActivityAt,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
      cartAbandonedAt: cartAbandonedAt ?? this.cartAbandonedAt,
      lastViewedProductId: lastViewedProductId ?? this.lastViewedProductId,
      cartAbandoned: cartAbandoned ?? this.cartAbandoned,
      segment: segment ?? this.segment,
      favoriteCategory: favoriteCategory ?? this.favoriteCategory,
      behaviorFlags: behaviorFlags ?? this.behaviorFlags,
    );
  }
}

class GrowthTrigger {
  final String id;
  final String userId;
  final String type;
  final String status;
  final String title;
  final String message;
  final String actionType;
  final String createdAt;
  final String? scheduledAt;
  final Map<String, dynamic> metadata;

  const GrowthTrigger({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.title,
    required this.message,
    required this.actionType,
    required this.createdAt,
    this.scheduledAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type,
        'status': status,
        'title': title,
        'message': message,
        'actionType': actionType,
        'createdAt': createdAt,
        'scheduledAt': scheduledAt,
        'metadata': metadata,
      };

  factory GrowthTrigger.fromMap(Map<String, dynamic> map, String id) => GrowthTrigger(
        id: map['id'] ?? id,
        userId: map['userId'] ?? '',
        type: map['type'] ?? 'generic',
        status: map['status'] ?? 'pending',
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        actionType: map['actionType'] ?? 'notify',
        createdAt: map['createdAt'] ?? '',
        scheduledAt: map['scheduledAt'],
        metadata: Map<String, dynamic>.from((map['metadata'] as Map?) ?? const {}),
      );
}

class GrowthOffer {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String subtitle;
  final String code;
  final double discountPercent;
  final double discountAmount;
  final double minOrderValue;
  final bool autoApply;
  final bool isClaimed;
  final String createdAt;
  final String? expiresAt;
  final Map<String, dynamic> metadata;

  const GrowthOffer({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.code,
    required this.discountPercent,
    this.discountAmount = 0,
    this.minOrderValue = 0,
    this.autoApply = false,
    required this.createdAt,
    this.isClaimed = false,
    this.expiresAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'code': code,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'minOrderValue': minOrderValue,
        'autoApply': autoApply,
        'isClaimed': isClaimed,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'metadata': metadata,
      };

  factory GrowthOffer.fromMap(Map<String, dynamic> map, String id) => GrowthOffer(
        id: map['id'] ?? id,
        userId: map['userId'] ?? '',
        type: map['type'] ?? 'discount',
        title: map['title'] ?? '',
        subtitle: map['subtitle'] ?? '',
        code: map['code'] ?? '',
        discountPercent: ((map['discountPercent'] ?? 0) as num).toDouble(),
        discountAmount: ((map['discountAmount'] ?? 0) as num).toDouble(),
        minOrderValue: ((map['minOrderValue'] ?? 0) as num).toDouble(),
        autoApply: map['autoApply'] ?? false,
        isClaimed: map['isClaimed'] ?? false,
        createdAt: map['createdAt'] ?? '',
        expiresAt: map['expiresAt'],
        metadata: Map<String, dynamic>.from((map['metadata'] as Map?) ?? const {}),
        );
  }

class ReferralRecord {
  final String id;
  final String referrerId;
  final String referredUserId;
  final String referralCode;
  final String status;
  final bool rewardGiven;
  final double referrerReward;
  final double friendReward;
  final String createdAt;
  final String? completedAt;
  final String? qualifyingOrderId;
  final double? qualifyingOrderAmount;
  final List<String> fraudFlags;

  const ReferralRecord({
    required this.id,
    required this.referrerId,
    required this.referredUserId,
    required this.referralCode,
    required this.createdAt,
    this.status = 'pending',
    this.rewardGiven = false,
    this.referrerReward = 0,
    this.friendReward = 0,
    this.completedAt,
    this.qualifyingOrderId,
    this.qualifyingOrderAmount,
    this.fraudFlags = const <String>[],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'referrerId': referrerId,
        'referredUserId': referredUserId,
        'referralCode': referralCode,
        'status': status,
        'rewardGiven': rewardGiven,
        'referrerReward': referrerReward,
        'friendReward': friendReward,
        'createdAt': createdAt,
        'completedAt': completedAt,
        'qualifyingOrderId': qualifyingOrderId,
        'qualifyingOrderAmount': qualifyingOrderAmount,
        'fraudFlags': fraudFlags,
      };

  factory ReferralRecord.fromMap(Map<String, dynamic> map, String id) => ReferralRecord(
        id: map['id'] ?? id,
        referrerId: map['referrerId'] ?? '',
        referredUserId: map['referredUserId'] ?? '',
        referralCode: map['referralCode'] ?? '',
        status: map['status'] ?? 'pending',
        rewardGiven: map['rewardGiven'] ?? false,
        referrerReward: ((map['referrerReward'] ?? 0) as num).toDouble(),
        friendReward: ((map['friendReward'] ?? 0) as num).toDouble(),
        createdAt: map['createdAt'] ?? '',
        completedAt: map['completedAt'],
        qualifyingOrderId: map['qualifyingOrderId'],
        qualifyingOrderAmount:
            map['qualifyingOrderAmount'] == null ? null : (map['qualifyingOrderAmount'] as num).toDouble(),
        fraudFlags: List<String>.from((map['fraudFlags'] as List?) ?? const <String>[]),
      );
}

class ReferralDashboardData {
  final String referralCode;
  final int invitedCount;
  final int completedCount;
  final int pendingCount;
  final double earnedCredits;
  final double walletBalance;
  final String tier;
  final double nextTierProgress;
  final int invitesToNextTier;
  final List<ReferralRecord> history;

  const ReferralDashboardData({
    required this.referralCode,
    required this.invitedCount,
    required this.completedCount,
    required this.pendingCount,
    required this.earnedCredits,
    required this.walletBalance,
    required this.tier,
    required this.nextTierProgress,
    required this.invitesToNextTier,
    required this.history,
  });
}

class SmartCreditDecision {
  final double availableCredits;
  final double appliedCredits;
  final bool autoApplied;
  final bool eligible;
  final String message;

  const SmartCreditDecision({
    required this.availableCredits,
    required this.appliedCredits,
    required this.autoApplied,
    required this.eligible,
    required this.message,
  });
}

class MasterPricingDecision {
  final double originalPrice;
  final double dynamicPrice;
  final double dynamicAdjustment;
  final double couponAmount;
  final String? couponCode;
  final double creditsApplied;
  final double discountedSubtotal;
  final double taxAmount;
  final double extraCharges;
  final double finalPrice;
  final double maxDiscountCap;
  final String summary;

  const MasterPricingDecision({
    required this.originalPrice,
    required this.dynamicPrice,
    required this.dynamicAdjustment,
    required this.couponAmount,
    required this.couponCode,
    required this.creditsApplied,
    required this.discountedSubtotal,
    required this.taxAmount,
    required this.extraCharges,
    required this.finalPrice,
    required this.maxDiscountCap,
    required this.summary,
  });

  Map<String, dynamic> toMap() => {
        'originalPrice': originalPrice,
        'dynamicPrice': dynamicPrice,
        'dynamicAdjustment': dynamicAdjustment,
        'couponAmount': couponAmount,
        'couponCode': couponCode,
        'creditsApplied': creditsApplied,
        'discountedSubtotal': discountedSubtotal,
        'taxAmount': taxAmount,
        'extraCharges': extraCharges,
        'finalPrice': finalPrice,
        'maxDiscountCap': maxDiscountCap,
        'summary': summary,
      };
}

class SupportChat {
  final String id;
  final String userId;
  final String type;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String lastMessage;
  final String lastMessageAt;
  final String lastSenderId;
  final String lastSenderRole;
  final String userName;
  final String userPhone;
  final String ticketId;
  final String? orderId;
  final int unreadCountUser;
  final int unreadCountAdmin;
  final Map<String, bool> participantIds;

  const SupportChat({
    required this.id,
    required this.userId,
    required this.type,
    this.status = 'open',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
    this.lastMessageAt = '',
    this.lastSenderId = '',
    this.lastSenderRole = '',
    this.userName = '',
    this.userPhone = '',
    this.ticketId = '',
    this.orderId,
    this.unreadCountUser = 0,
    this.unreadCountAdmin = 0,
    this.participantIds = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt,
        'lastSenderId': lastSenderId,
        'lastSenderRole': lastSenderRole,
        'userName': userName,
        'userPhone': userPhone,
        'ticketId': ticketId,
        'orderId': orderId,
        'unreadCountUser': unreadCountUser,
        'unreadCountAdmin': unreadCountAdmin,
        'participantIds': participantIds,
      };

  factory SupportChat.fromMap(Map<String, dynamic> map, String id) => SupportChat(
        id: id,
        userId: map['userId'] ?? '',
        type: map['type'] ?? 'general',
        status: map['status'] ?? 'open',
        createdAt: map['createdAt'] ?? '',
        updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
        lastMessage: map['lastMessage'] ?? '',
        lastMessageAt: map['lastMessageAt'] ?? '',
        lastSenderId: map['lastSenderId'] ?? '',
        lastSenderRole: map['lastSenderRole'] ?? '',
        userName: map['userName'] ?? '',
        userPhone: map['userPhone'] ?? '',
        ticketId: map['ticketId'] ?? '',
        orderId: map['orderId'],
        unreadCountUser: map['unreadCountUser'] ?? 0,
        unreadCountAdmin: map['unreadCountAdmin'] ?? 0,
        participantIds: Map<String, bool>.from((map['participantIds'] as Map?) ?? const {}),
      );

  SupportChat copyWith({
    String? id,
    String? userId,
    String? type,
    String? status,
    String? createdAt,
    String? updatedAt,
    String? lastMessage,
    String? lastMessageAt,
    String? lastSenderId,
    String? lastSenderRole,
    String? userName,
    String? userPhone,
    String? ticketId,
    String? orderId,
    int? unreadCountUser,
    int? unreadCountAdmin,
    Map<String, bool>? participantIds,
  }) {
    return SupportChat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastSenderRole: lastSenderRole ?? this.lastSenderRole,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      ticketId: ticketId ?? this.ticketId,
      orderId: orderId ?? this.orderId,
      unreadCountUser: unreadCountUser ?? this.unreadCountUser,
      unreadCountAdmin: unreadCountAdmin ?? this.unreadCountAdmin,
      participantIds: participantIds ?? this.participantIds,
    );
  }
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final String imageUrl;
  final String timestamp;
  final bool read;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    this.text = '',
    this.imageUrl = '',
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderRole': senderRole,
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': timestamp,
        'read': read,
      };

  factory SupportMessage.fromMap(Map<String, dynamic> map, String id) => SupportMessage(
        id: id,
        senderId: map['senderId'] ?? '',
        senderRole: map['senderRole'] ?? 'user',
        text: map['text'] ?? '',
        imageUrl: map['imageUrl'] ?? '',
        timestamp: map['timestamp'] ?? '',
        read: map['read'] ?? false,
      );

  SupportMessage copyWith({
    String? id,
    String? senderId,
    String? senderRole,
    String? text,
    String? imageUrl,
    String? timestamp,
    bool? read,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }
}

class SupportTicket {
  final String id;
  final String chatId;
  final String userId;
  final String issueType;
  final String status;
  final String createdAt;
  final String? resolvedAt;

  const SupportTicket({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.issueType,
    this.status = 'open',
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'chatId': chatId,
        'userId': userId,
        'issueType': issueType,
        'status': status,
        'createdAt': createdAt,
        'resolvedAt': resolvedAt,
      };

  factory SupportTicket.fromMap(Map<String, dynamic> map, String id) => SupportTicket(
        id: id,
        chatId: map['chatId'] ?? '',
        userId: map['userId'] ?? '',
        issueType: map['issueType'] ?? 'general',
        status: map['status'] ?? 'open',
        createdAt: map['createdAt'] ?? '',
        resolvedAt: map['resolvedAt'],
      );

  SupportTicket copyWith({
    String? id,
    String? chatId,
    String? userId,
    String? issueType,
    String? status,
    String? createdAt,
    String? resolvedAt,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      issueType: issueType ?? this.issueType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class UserMemory {
  final String userId;
  final String name;
  final String preferredStyle;
  final String size;
  final List<String> pastIssues;
  final String lastOrderId;
  final String lastConversationSummary;
  final String updatedAt;

  const UserMemory({
    required this.userId,
    this.name = '',
    this.preferredStyle = '',
    this.size = '',
    this.pastIssues = const [],
    this.lastOrderId = '',
    this.lastConversationSummary = '',
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'preferredStyle': preferredStyle,
        'size': size,
        'pastIssues': pastIssues,
        'lastOrderId': lastOrderId,
        'lastConversationSummary': lastConversationSummary,
        'updatedAt': updatedAt,
      };

  factory UserMemory.fromMap(Map<String, dynamic> map, String userId) =>
      UserMemory(
        userId: userId,
        name: (map['name'] ?? '').toString(),
        preferredStyle: (map['preferredStyle'] ?? '').toString(),
        size: (map['size'] ?? '').toString(),
        pastIssues: ((map['pastIssues'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(),
        lastOrderId: (map['lastOrderId'] ?? '').toString(),
        lastConversationSummary:
            (map['lastConversationSummary'] ?? '').toString(),
        updatedAt: (map['updatedAt'] ?? '').toString(),
      );

  UserMemory copyWith({
    String? userId,
    String? name,
    String? preferredStyle,
    String? size,
    List<String>? pastIssues,
    String? lastOrderId,
    String? lastConversationSummary,
    String? updatedAt,
  }) {
    return UserMemory(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      preferredStyle: preferredStyle ?? this.preferredStyle,
      size: size ?? this.size,
      pastIssues: pastIssues ?? this.pastIssues,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      lastConversationSummary:
          lastConversationSummary ?? this.lastConversationSummary,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ConversationMemoryMessage {
  final String id;
  final String role;
  final String text;
  final String timestamp;

  const ConversationMemoryMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'text': text,
        'timestamp': timestamp,
      };

  factory ConversationMemoryMessage.fromMap(Map<String, dynamic> map, String id) {
    return ConversationMemoryMessage(
      id: id,
      role: (map['role'] ?? 'user').toString(),
      text: (map['text'] ?? '').toString(),
      timestamp: (map['timestamp'] ?? '').toString(),
    );
  }
}

class FaqItem {
  final String id;
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.category = 'general',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'answer': answer,
        'category': category,
      };

  factory FaqItem.fromMap(Map<String, dynamic> map, String id) => FaqItem(
        id: id,
        question: map['question'] ?? '',
        answer: map['answer'] ?? '',
        category: map['category'] ?? 'general',
      );
}

class KycDocuments {
  final String ownerPhotoUrl;
  final String storeImageUrl;
  final String aadhaarUrl;
  final String panUrl;
  final String selfieUrl;
  final String profilePhotoUrl;
  final String licenseUrl;

  const KycDocuments({
    this.ownerPhotoUrl = '',
    this.storeImageUrl = '',
    this.aadhaarUrl = '',
    this.panUrl = '',
    this.selfieUrl = '',
    this.profilePhotoUrl = '',
    this.licenseUrl = '',
  });

  Map<String, dynamic> toMap() => {
        'ownerPhotoUrl': ownerPhotoUrl,
        'storeImageUrl': storeImageUrl,
        'aadhaarUrl': aadhaarUrl,
        'panUrl': panUrl,
        'selfieUrl': selfieUrl,
        'profilePhotoUrl': profilePhotoUrl,
        'licenseUrl': licenseUrl,
      };

  factory KycDocuments.fromMap(Map<String, dynamic> map) => KycDocuments(
        ownerPhotoUrl: map['ownerPhotoUrl'] ?? '',
        storeImageUrl: map['storeImageUrl'] ?? '',
        aadhaarUrl: map['aadhaarUrl'] ?? '',
        panUrl: map['panUrl'] ?? '',
        selfieUrl: map['selfieUrl'] ?? '',
        profilePhotoUrl: map['profilePhotoUrl'] ?? '',
        licenseUrl: map['licenseUrl'] ?? '',
      );

  KycDocuments copyWith({
    String? ownerPhotoUrl,
    String? storeImageUrl,
    String? aadhaarUrl,
    String? panUrl,
    String? selfieUrl,
    String? profilePhotoUrl,
    String? licenseUrl,
  }) {
    return KycDocuments(
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      storeImageUrl: storeImageUrl ?? this.storeImageUrl,
      aadhaarUrl: aadhaarUrl ?? this.aadhaarUrl,
      panUrl: panUrl ?? this.panUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      licenseUrl: licenseUrl ?? this.licenseUrl,
    );
  }
}

class KycActionEntry {
  final String action;
  final String actorId;
  final String actorName;
  final String timestamp;
  final String note;

  const KycActionEntry({
    required this.action,
    required this.actorId,
    required this.actorName,
    required this.timestamp,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'action': action,
        'actorId': actorId,
        'actorName': actorName,
        'timestamp': timestamp,
        'note': note,
      };

  factory KycActionEntry.fromMap(Map<String, dynamic> map) => KycActionEntry(
        action: map['action'] ?? '',
        actorId: map['actorId'] ?? '',
        actorName: map['actorName'] ?? '',
        timestamp: map['timestamp'] ?? '',
        note: map['note'] ?? '',
      );
}

class KycVerificationSummary {
  final String extractedName;
  final String aadhaarNumber;
  final String panNumber;
  final double confidenceScore;
  final bool aadhaarValid;
  final bool panValid;
  final String autoReviewStatus;
  final bool duplicateDetected;
  final List<String> duplicateMatches;
  final List<String> flags;
  final String provider;
  final String analyzedAt;
  final String reviewSummary;
  final bool livenessPassed;
  final bool faceVerified;
  final double matchScore;
  final String livenessMode;
  final int selfieRetryCount;
  final String selfieVerifiedAt;
  final int riskScore;
  final String riskDecision;
  final List<String> riskReasons;
  final bool gpsValid;
  final bool nameMatch;
  final bool addressMatch;

  const KycVerificationSummary({
    this.extractedName = '',
    this.aadhaarNumber = '',
    this.panNumber = '',
    this.confidenceScore = 0,
    this.aadhaarValid = false,
    this.panValid = false,
    this.autoReviewStatus = 'pending_review',
    this.duplicateDetected = false,
    this.duplicateMatches = const [],
    this.flags = const [],
    this.provider = 'local',
    this.analyzedAt = '',
    this.reviewSummary = '',
    this.livenessPassed = false,
    this.faceVerified = false,
    this.matchScore = 0,
    this.livenessMode = '',
    this.selfieRetryCount = 0,
    this.selfieVerifiedAt = '',
    this.riskScore = 0,
    this.riskDecision = 'review',
    this.riskReasons = const [],
    this.gpsValid = false,
    this.nameMatch = false,
    this.addressMatch = false,
  });

  Map<String, dynamic> toMap() => {
        'extractedName': extractedName,
        'aadhaarNumber': aadhaarNumber,
        'panNumber': panNumber,
        'confidenceScore': confidenceScore,
        'aadhaarValid': aadhaarValid,
        'panValid': panValid,
        'autoReviewStatus': autoReviewStatus,
        'duplicateDetected': duplicateDetected,
        'duplicateMatches': duplicateMatches,
        'flags': flags,
        'provider': provider,
        'analyzedAt': analyzedAt,
        'reviewSummary': reviewSummary,
        'livenessPassed': livenessPassed,
        'faceVerified': faceVerified,
        'matchScore': matchScore,
        'livenessMode': livenessMode,
        'selfieRetryCount': selfieRetryCount,
        'selfieVerifiedAt': selfieVerifiedAt,
        'riskScore': riskScore,
        'riskDecision': riskDecision,
        'riskReasons': riskReasons,
        'gpsValid': gpsValid,
        'nameMatch': nameMatch,
        'addressMatch': addressMatch,
      };

  factory KycVerificationSummary.fromMap(Map<String, dynamic> map) =>
      KycVerificationSummary(
        extractedName: map['extractedName'] ?? '',
        aadhaarNumber: map['aadhaarNumber'] ?? '',
        panNumber: map['panNumber'] ?? '',
        confidenceScore: (map['confidenceScore'] ?? 0).toDouble(),
        aadhaarValid: map['aadhaarValid'] ?? false,
        panValid: map['panValid'] ?? false,
        autoReviewStatus: map['autoReviewStatus'] ?? 'pending_review',
        duplicateDetected: map['duplicateDetected'] ?? false,
        duplicateMatches:
            List<String>.from((map['duplicateMatches'] as List?) ?? const []),
        flags: List<String>.from((map['flags'] as List?) ?? const []),
        provider: map['provider'] ?? 'local',
        analyzedAt: map['analyzedAt'] ?? '',
        reviewSummary: map['reviewSummary'] ?? '',
        livenessPassed: map['livenessPassed'] ?? false,
        faceVerified: map['faceVerified'] ?? false,
        matchScore: (map['matchScore'] ?? 0).toDouble(),
        livenessMode: map['livenessMode'] ?? '',
        selfieRetryCount: map['selfieRetryCount'] ?? 0,
        selfieVerifiedAt: map['selfieVerifiedAt'] ?? '',
        riskScore: map['riskScore'] ?? 0,
        riskDecision: map['riskDecision'] ?? 'review',
        riskReasons: List<String>.from((map['riskReasons'] as List?) ?? const []),
        gpsValid: map['gpsValid'] ?? false,
        nameMatch: map['nameMatch'] ?? false,
        addressMatch: map['addressMatch'] ?? false,
      );

  KycVerificationSummary copyWith({
    String? extractedName,
    String? aadhaarNumber,
    String? panNumber,
    double? confidenceScore,
    bool? aadhaarValid,
    bool? panValid,
    String? autoReviewStatus,
    bool? duplicateDetected,
    List<String>? duplicateMatches,
    List<String>? flags,
    String? provider,
    String? analyzedAt,
    String? reviewSummary,
    bool? livenessPassed,
    bool? faceVerified,
    double? matchScore,
    String? livenessMode,
    int? selfieRetryCount,
    String? selfieVerifiedAt,
    int? riskScore,
    String? riskDecision,
    List<String>? riskReasons,
    bool? gpsValid,
    bool? nameMatch,
    bool? addressMatch,
  }) {
    return KycVerificationSummary(
      extractedName: extractedName ?? this.extractedName,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      panNumber: panNumber ?? this.panNumber,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      aadhaarValid: aadhaarValid ?? this.aadhaarValid,
      panValid: panValid ?? this.panValid,
      autoReviewStatus: autoReviewStatus ?? this.autoReviewStatus,
      duplicateDetected: duplicateDetected ?? this.duplicateDetected,
      duplicateMatches: duplicateMatches ?? this.duplicateMatches,
      flags: flags ?? this.flags,
      provider: provider ?? this.provider,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      livenessPassed: livenessPassed ?? this.livenessPassed,
      faceVerified: faceVerified ?? this.faceVerified,
      matchScore: matchScore ?? this.matchScore,
      livenessMode: livenessMode ?? this.livenessMode,
      selfieRetryCount: selfieRetryCount ?? this.selfieRetryCount,
      selfieVerifiedAt: selfieVerifiedAt ?? this.selfieVerifiedAt,
      riskScore: riskScore ?? this.riskScore,
      riskDecision: riskDecision ?? this.riskDecision,
      riskReasons: riskReasons ?? this.riskReasons,
      gpsValid: gpsValid ?? this.gpsValid,
      nameMatch: nameMatch ?? this.nameMatch,
      addressMatch: addressMatch ?? this.addressMatch,
    );
  }
}

class VendorKycRequest {
  final String id;
  final String userId;
  final String storeName;
  final String ownerName;
  final String phone;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final KycDocuments kyc;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String rejectionReason;
  final String reviewedBy;
  final String reviewedByName;
  final String reviewedAt;
  final List<KycActionEntry> actionHistory;
  final KycVerificationSummary verification;

  const VendorKycRequest({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.kyc,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason = '',
    this.reviewedBy = '',
    this.reviewedByName = '',
    this.reviewedAt = '',
    this.actionHistory = const [],
    this.verification = const KycVerificationSummary(),
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'storeName': storeName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'kyc': kyc.toMap(),
        'status': status,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'rejectionReason': rejectionReason,
          'reviewedBy': reviewedBy,
          'reviewedByName': reviewedByName,
          'reviewedAt': reviewedAt,
          'actionHistory': actionHistory.map((entry) => entry.toMap()).toList(),
          'verification': verification.toMap(),
        };

  factory VendorKycRequest.fromMap(Map<String, dynamic> map, String id) => VendorKycRequest(
        id: id,
        userId: map['userId'] ?? '',
        storeName: map['storeName'] ?? '',
        ownerName: map['ownerName'] ?? '',
        phone: map['phone'] ?? '',
        address: map['address'] ?? '',
        city: map['city'] ?? '',
        latitude: (map['latitude'] ?? 0).toDouble(),
        longitude: (map['longitude'] ?? 0).toDouble(),
        kyc: KycDocuments.fromMap(Map<String, dynamic>.from((map['kyc'] as Map?) ?? const {})),
          status: map['status'] ?? 'pending',
          createdAt: map['createdAt'] ?? '',
          updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
          rejectionReason: map['rejectionReason'] ?? '',
          reviewedBy: map['reviewedBy'] ?? '',
          reviewedByName: map['reviewedByName'] ?? '',
          reviewedAt: map['reviewedAt'] ?? '',
          actionHistory: ((map['actionHistory'] as List?) ?? const [])
              .map((entry) => KycActionEntry.fromMap(Map<String, dynamic>.from(entry as Map)))
              .toList(),
          verification: KycVerificationSummary.fromMap(
            Map<String, dynamic>.from((map['verification'] as Map?) ?? const {}),
          ),
        );

  VendorKycRequest copyWith({
    String? id,
    String? userId,
    String? storeName,
    String? ownerName,
    String? phone,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    KycDocuments? kyc,
    String? status,
      String? createdAt,
      String? updatedAt,
      String? rejectionReason,
      String? reviewedBy,
      String? reviewedByName,
      String? reviewedAt,
      List<KycActionEntry>? actionHistory,
      KycVerificationSummary? verification,
    }) {
    return VendorKycRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storeName: storeName ?? this.storeName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      kyc: kyc ?? this.kyc,
      status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewedByName: reviewedByName ?? this.reviewedByName,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        actionHistory: actionHistory ?? this.actionHistory,
        verification: verification ?? this.verification,
      );
    }
  }

class RiderKycRequest {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String vehicle;
  final String city;
  final KycDocuments kyc;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String rejectionReason;
  final String reviewedBy;
  final String reviewedByName;
  final String reviewedAt;
  final List<KycActionEntry> actionHistory;

  const RiderKycRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.city,
    required this.kyc,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason = '',
    this.reviewedBy = '',
    this.reviewedByName = '',
    this.reviewedAt = '',
    this.actionHistory = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'phone': phone,
        'vehicle': vehicle,
        'city': city,
        'kyc': kyc.toMap(),
        'status': status,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'rejectionReason': rejectionReason,
          'reviewedBy': reviewedBy,
          'reviewedByName': reviewedByName,
          'reviewedAt': reviewedAt,
          'actionHistory': actionHistory.map((entry) => entry.toMap()).toList(),
        };

  factory RiderKycRequest.fromMap(Map<String, dynamic> map, String id) => RiderKycRequest(
        id: id,
        userId: map['userId'] ?? '',
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        vehicle: map['vehicle'] ?? '',
        city: map['city'] ?? '',
        kyc: KycDocuments.fromMap(Map<String, dynamic>.from((map['kyc'] as Map?) ?? const {})),
          status: map['status'] ?? 'pending',
          createdAt: map['createdAt'] ?? '',
          updatedAt: map['updatedAt'] ?? map['createdAt'] ?? '',
          rejectionReason: map['rejectionReason'] ?? '',
          reviewedBy: map['reviewedBy'] ?? '',
          reviewedByName: map['reviewedByName'] ?? '',
          reviewedAt: map['reviewedAt'] ?? '',
          actionHistory: ((map['actionHistory'] as List?) ?? const [])
              .map((entry) => KycActionEntry.fromMap(Map<String, dynamic>.from(entry as Map)))
              .toList(),
        );

  RiderKycRequest copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? vehicle,
    String? city,
    KycDocuments? kyc,
    String? status,
      String? createdAt,
      String? updatedAt,
      String? rejectionReason,
      String? reviewedBy,
      String? reviewedByName,
      String? reviewedAt,
      List<KycActionEntry>? actionHistory,
    }) {
    return RiderKycRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicle: vehicle ?? this.vehicle,
      city: city ?? this.city,
      kyc: kyc ?? this.kyc,
      status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewedByName: reviewedByName ?? this.reviewedByName,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        actionHistory: actionHistory ?? this.actionHistory,
      );
    }
  }

class PayoutModel {
  final String id;
  final String storeId;
  final String processedBy;
  final double amount;
  final String periodLabel;
  final DateTime createdAt;
  final List<String> orderIds;
  final String status;

  PayoutModel({
    required this.id,
    required this.storeId,
    required this.processedBy,
    required this.amount,
    required this.periodLabel,
    required this.createdAt,
    this.orderIds = const [],
    this.status = 'Processed',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'storeId': storeId,
        'processedBy': processedBy,
        'amount': amount,
        'periodLabel': periodLabel,
        'createdAt': createdAt.toIso8601String(),
        'orderIds': orderIds,
        'status': status,
      };

  factory PayoutModel.fromMap(Map<String, dynamic> map, String docId) => PayoutModel(
        id: docId,
        storeId: map['storeId'] ?? '',
        processedBy: map['processedBy'] ?? '',
        amount: (map['amount'] ?? 0.0).toDouble(),
        periodLabel: map['periodLabel'] ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        orderIds: List<String>.from(map['orderIds'] ?? const []),
        status: map['status'] ?? 'Processed',
      );
}

class WalletTransaction {
  final String id;
  final String type;
  final String userType;
  final String userId;
  final double amount;
  final String status;
  final String note;
  final String orderId;
  final String payoutId;
  final String storeId;
  final String riderId;
  final String createdAt;
  final Map<String, dynamic> metadata;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.userType,
    required this.userId,
    required this.amount,
    required this.status,
    required this.note,
    required this.orderId,
    required this.payoutId,
    required this.storeId,
    required this.riderId,
    required this.createdAt,
    this.metadata = const {},
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) => WalletTransaction(
        id: map['id'] ?? '',
        type: map['type'] ?? 'order',
        userType: map['userType'] ?? 'vendor',
        userId: map['userId'] ?? '',
        amount: ((map['amount'] ?? 0) as num).toDouble(),
        status: map['status'] ?? 'pending',
        note: map['note'] ?? '',
        orderId: map['orderId'] ?? '',
        payoutId: map['payoutId'] ?? '',
        storeId: map['storeId'] ?? '',
        riderId: map['riderId'] ?? '',
        createdAt: map['createdAt'] ?? '',
        metadata: Map<String, dynamic>.from(map['metadata'] ?? const {}),
      );
}

class WalletSummary {
  final String id;
  final String kind;
  final String linkedId;
  final double balance;
  final double pendingAmount;
  final double totalEarnings;
  final double totalWithdrawn;
  final String lastSettlementDate;
  final double? commissionRate;
  final List<WalletTransaction> transactions;

  const WalletSummary({
    required this.id,
    required this.kind,
    required this.linkedId,
    required this.balance,
    required this.pendingAmount,
    required this.totalEarnings,
    required this.totalWithdrawn,
    required this.lastSettlementDate,
    this.commissionRate,
    this.transactions = const [],
  });
}

class AdminFinanceSummary {
  final double totalCommission;
  final double totalRevenue;
  final double payoutsDone;
  final double vendorSettlementsDone;
  final double riderSettlementsDone;
  final double vendorPending;
  final double riderPending;
  final List<WalletSummary> vendorWallets;
  final List<WalletSummary> riderWallets;
  final List<WalletTransaction> transactions;

  const AdminFinanceSummary({
    required this.totalCommission,
    required this.totalRevenue,
    required this.payoutsDone,
    required this.vendorSettlementsDone,
    required this.riderSettlementsDone,
    required this.vendorPending,
    required this.riderPending,
    this.vendorWallets = const [],
    this.riderWallets = const [],
    this.transactions = const [],
  });
}

class AnalyticsPoint {
  final String label;
  final double value;

  AnalyticsPoint({
    required this.label,
    required this.value,
  });
}

class AiUsageLogEntry {
  final String id;
  final String userId;
  final String message;
  final int responseLength;
  final int tokensUsed;
  final double cost;
  final double costPerRequest;
  final String timestamp;
  final String intentType;
  final bool usedAi;

  const AiUsageLogEntry({
    required this.id,
    required this.userId,
    required this.message,
    required this.responseLength,
    required this.tokensUsed,
    required this.cost,
    required this.costPerRequest,
    required this.timestamp,
    required this.intentType,
    required this.usedAi,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'message': message,
        'responseLength': responseLength,
        'tokensUsed': tokensUsed,
        'cost': cost,
        'costPerRequest': costPerRequest,
        'timestamp': timestamp,
        'intentType': intentType,
        'usedAi': usedAi,
      };

  factory AiUsageLogEntry.fromMap(Map<String, dynamic> map, String id) {
    return AiUsageLogEntry(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      responseLength: ((map['responseLength'] ?? 0) as num).toInt(),
      tokensUsed: ((map['tokensUsed'] ?? 0) as num).toInt(),
      cost: ((map['cost'] ?? 0) as num).toDouble(),
      costPerRequest: ((map['costPerRequest'] ?? 0) as num).toDouble(),
      timestamp: (map['timestamp'] ?? '').toString(),
      intentType: (map['intentType'] ?? 'ai_needed').toString(),
      usedAi: map['usedAi'] == true,
    );
  }
}

class AiDailyStat {
  final String date;
  final int totalRequests;
  final double totalCost;
  final int aiRequests;
  final int logicRequests;

  const AiDailyStat({
    required this.date,
    required this.totalRequests,
    required this.totalCost,
    required this.aiRequests,
    required this.logicRequests,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'totalRequests': totalRequests,
        'totalCost': totalCost,
        'aiRequests': aiRequests,
        'logicRequests': logicRequests,
      };

  factory AiDailyStat.fromMap(Map<String, dynamic> map, String date) {
    return AiDailyStat(
      date: date,
      totalRequests: ((map['totalRequests'] ?? 0) as num).toInt(),
      totalCost: ((map['totalCost'] ?? 0) as num).toDouble(),
      aiRequests: ((map['aiRequests'] ?? 0) as num).toInt(),
      logicRequests: ((map['logicRequests'] ?? 0) as num).toInt(),
    );
  }
}

class UserAiUsageStat {
  final String userId;
  final int totalMessages;
  final int aiMessages;
  final String lastUsed;
  final int dailyUsage;

  const UserAiUsageStat({
    required this.userId,
    required this.totalMessages,
    required this.aiMessages,
    required this.lastUsed,
    required this.dailyUsage,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'totalMessages': totalMessages,
        'aiMessages': aiMessages,
        'lastUsed': lastUsed,
        'dailyUsage': dailyUsage,
      };

  factory UserAiUsageStat.fromMap(Map<String, dynamic> map, String userId) {
    return UserAiUsageStat(
      userId: userId,
      totalMessages: ((map['totalMessages'] ?? 0) as num).toInt(),
      aiMessages: ((map['aiMessages'] ?? 0) as num).toInt(),
      lastUsed: (map['lastUsed'] ?? '').toString(),
      dailyUsage: ((map['dailyUsage'] ?? 0) as num).toInt(),
    );
  }
}

class AdminAnalytics {
  final double totalRevenue;
  final double platformCommissionRevenue;
  final int totalOrders;
  final List<Store> topStores;
  final List<AnalyticsPoint> dailySales;
  final List<AnalyticsPoint> weeklySales;

  AdminAnalytics({
    required this.totalRevenue,
    required this.platformCommissionRevenue,
    required this.totalOrders,
    required this.topStores,
    required this.dailySales,
    required this.weeklySales,
  });
}

class VendorAnalytics {
  final double totalSales;
  final double availableBalance;
  final double totalEarnings;
  final int orders;
  final List<Product> bestSellingProducts;
  final List<AnalyticsPoint> salesTrend;

  VendorAnalytics({
    required this.totalSales,
    required this.availableBalance,
    required this.totalEarnings,
    required this.orders,
    required this.bestSellingProducts,
    required this.salesTrend,
  });
}

class SearchFilter {
  final String query;
  final RangeValues priceRange;
  final String category;
  final String occasion;
  final String storeId;

  const SearchFilter({
    this.query = '',
    this.priceRange = const RangeValues(0, 10000),
    this.category = 'All',
    this.occasion = 'All',
    this.storeId = 'All',
  });

  SearchFilter copyWith({
    String? query,
    RangeValues? priceRange,
    String? category,
    String? occasion,
    String? storeId,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      priceRange: priceRange ?? this.priceRange,
      category: category ?? this.category,
      occasion: occasion ?? this.occasion,
      storeId: storeId ?? this.storeId,
    );
  }
}

class DisputeRecord {
  final String id;
  final String orderId;
  final String userId;
  final String storeId;
  final String type;
  final String status;
  final double amount;
  final String reason;
  final DateTime createdAt;

  DisputeRecord({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.storeId,
    required this.type,
    required this.status,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'userId': userId,
        'storeId': storeId,
        'type': type,
        'status': status,
        'amount': amount,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DisputeRecord.fromMap(Map<String, dynamic> map, String docId) => DisputeRecord(
        id: docId,
        orderId: map['orderId'] ?? '',
        userId: map['userId'] ?? '',
        storeId: map['storeId'] ?? '',
        type: map['type'] ?? 'Dispute',
        status: map['status'] ?? 'Open',
        amount: (map['amount'] ?? 0.0).toDouble(),
        reason: map['reason'] ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class ActivityLogEntry {
  final String id;
  final String actorId;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final String message;
  final DateTime timestamp;

  ActivityLogEntry({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'actorId': actorId,
        'actorRole': actorRole,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map, String docId) => ActivityLogEntry(
        id: docId,
        actorId: map['actorId'] ?? '',
        actorRole: map['actorRole'] ?? '',
        action: map['action'] ?? '',
        targetType: map['targetType'] ?? '',
        targetId: map['targetId'] ?? '',
        message: map['message'] ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      );
}

class PlatformSettings {
  final bool customTailoringEnabled;
  final bool reelsEnabled;
  final bool offersEnabled;
  final bool checkoutEnabled;
  final bool marketplaceEnabled;
  final bool riderDispatchEnabled;
  final Map<String, bool> cities;
  final Map<String, bool> regionVendorAvailability;
  final List<String> allowedAdminDevices;
  final int adminIdleTimeoutMinutes;
  final bool adminPinEnabled;
  final String adminPin;
  final double aiDailyCostAlertThreshold;
  final double aiDailyCostLimit;
  final bool aiAssistantEnabled;

  const PlatformSettings({
    this.customTailoringEnabled = true,
    this.reelsEnabled = true,
    this.offersEnabled = true,
    this.checkoutEnabled = true,
    this.marketplaceEnabled = true,
    this.riderDispatchEnabled = true,
    this.cities = const {
      'Mumbai': true,
      'Delhi': true,
      'Bangalore': true,
      'Hyderabad': true,
    },
    this.regionVendorAvailability = const {
      'Mumbai': true,
      'Delhi': true,
      'Bangalore': true,
      'Hyderabad': true,
    },
    this.allowedAdminDevices = const ['web-chrome', 'windows-desktop'],
    this.adminIdleTimeoutMinutes = 10,
    this.adminPinEnabled = false,
    this.adminPin = '1234',
    this.aiDailyCostAlertThreshold = 1.0,
    this.aiDailyCostLimit = 500,
    this.aiAssistantEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'customTailoringEnabled': customTailoringEnabled,
        'reelsEnabled': reelsEnabled,
        'offersEnabled': offersEnabled,
        'checkoutEnabled': checkoutEnabled,
        'marketplaceEnabled': marketplaceEnabled,
        'riderDispatchEnabled': riderDispatchEnabled,
        'cities': cities,
        'regionVendorAvailability': regionVendorAvailability,
        'allowedAdminDevices': allowedAdminDevices,
        'adminIdleTimeoutMinutes': adminIdleTimeoutMinutes,
        'adminPinEnabled': adminPinEnabled,
        'adminPin': adminPin,
        'aiDailyCostAlertThreshold': aiDailyCostAlertThreshold,
        'aiDailyCostLimit': aiDailyCostLimit,
        'aiAssistantEnabled': aiAssistantEnabled,
      };

  PlatformSettings copyWith({
    bool? customTailoringEnabled,
    bool? reelsEnabled,
    bool? offersEnabled,
    bool? checkoutEnabled,
    bool? marketplaceEnabled,
    bool? riderDispatchEnabled,
    Map<String, bool>? cities,
    Map<String, bool>? regionVendorAvailability,
    List<String>? allowedAdminDevices,
    int? adminIdleTimeoutMinutes,
    bool? adminPinEnabled,
    String? adminPin,
    double? aiDailyCostAlertThreshold,
    double? aiDailyCostLimit,
    bool? aiAssistantEnabled,
  }) {
    return PlatformSettings(
      customTailoringEnabled: customTailoringEnabled ?? this.customTailoringEnabled,
      reelsEnabled: reelsEnabled ?? this.reelsEnabled,
      offersEnabled: offersEnabled ?? this.offersEnabled,
      checkoutEnabled: checkoutEnabled ?? this.checkoutEnabled,
      marketplaceEnabled: marketplaceEnabled ?? this.marketplaceEnabled,
      riderDispatchEnabled: riderDispatchEnabled ?? this.riderDispatchEnabled,
      cities: cities ?? this.cities,
      regionVendorAvailability: regionVendorAvailability ?? this.regionVendorAvailability,
      allowedAdminDevices: allowedAdminDevices ?? this.allowedAdminDevices,
      adminIdleTimeoutMinutes: adminIdleTimeoutMinutes ?? this.adminIdleTimeoutMinutes,
      adminPinEnabled: adminPinEnabled ?? this.adminPinEnabled,
      adminPin: adminPin ?? this.adminPin,
      aiDailyCostAlertThreshold:
          aiDailyCostAlertThreshold ?? this.aiDailyCostAlertThreshold,
      aiDailyCostLimit: aiDailyCostLimit ?? this.aiDailyCostLimit,
      aiAssistantEnabled: aiAssistantEnabled ?? this.aiAssistantEnabled,
    );
  }

  factory PlatformSettings.fromMap(Map<String, dynamic> map) => PlatformSettings(
        customTailoringEnabled: map['customTailoringEnabled'] ?? true,
        reelsEnabled: map['reelsEnabled'] ?? true,
        offersEnabled: map['offersEnabled'] ?? true,
        checkoutEnabled: map['checkoutEnabled'] ?? true,
        marketplaceEnabled: map['marketplaceEnabled'] ?? true,
        riderDispatchEnabled: map['riderDispatchEnabled'] ?? true,
        cities: Map<String, bool>.from(map['cities'] ?? const {
          'Mumbai': true,
          'Delhi': true,
          'Bangalore': true,
          'Hyderabad': true,
        }),
        regionVendorAvailability: Map<String, bool>.from(map['regionVendorAvailability'] ?? const {
          'Mumbai': true,
          'Delhi': true,
          'Bangalore': true,
          'Hyderabad': true,
        }),
        allowedAdminDevices: List<String>.from(map['allowedAdminDevices'] ?? const ['web-chrome', 'windows-desktop']),
        adminIdleTimeoutMinutes: map['adminIdleTimeoutMinutes'] ?? 10,
        adminPinEnabled: map['adminPinEnabled'] ?? false,
        adminPin: map['adminPin'] ?? '1234',
        aiDailyCostAlertThreshold:
            ((map['aiDailyCostAlertThreshold'] ?? 1.0) as num).toDouble(),
        aiDailyCostLimit:
            ((map['aiDailyCostLimit'] ?? 500) as num).toDouble(),
        aiAssistantEnabled: map['aiAssistantEnabled'] ?? true,
      );
}

class GlobalSearchResults {
  final List<AppUser> users;
  final List<Store> stores;
  final List<OrderModel> orders;

  const GlobalSearchResults({
    this.users = const [],
    this.stores = const [],
    this.orders = const [],
  });
}

class CustomBrand {
  final String id;
  final String name;
  final String logoUrl;
  final String bannerUrl;
  final String type;
  final bool isPremium;
  final List<String> categories;

  const CustomBrand({
    required this.id,
    required this.name,
    this.logoUrl = '',
    this.bannerUrl = '',
    this.type = 'custom_clothing',
    this.isPremium = true,
    this.categories = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'type': type,
        'is_premium': isPremium,
        'categories': categories,
      };

  factory CustomBrand.fromMap(Map<String, dynamic> map, String id) => CustomBrand(
        id: id,
        name: map['name'] ?? '',
        logoUrl: map['logo_url'] ?? '',
        bannerUrl: map['banner_url'] ?? '',
        type: map['type'] ?? 'custom_clothing',
        isPremium: map['is_premium'] ?? true,
        categories: List<String>.from(map['categories'] ?? const <String>[]),
      );
}

class CustomBrandProduct {
  final String id;
  final String brandId;
  final String name;
  final double basePrice;
  final String category;

  const CustomBrandProduct({
    required this.id,
    required this.brandId,
    required this.name,
    required this.basePrice,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
        'brand_id': brandId,
        'name': name,
        'base_price': basePrice,
        'category': category,
      };

  factory CustomBrandProduct.fromMap(Map<String, dynamic> map, String id) => CustomBrandProduct(
        id: id,
        brandId: map['brand_id'] ?? '',
        name: map['name'] ?? '',
        basePrice: (map['base_price'] ?? 0).toDouble(),
        category: map['category'] ?? '',
      );
}
