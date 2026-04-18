import '../models/banner_model.dart';
import '../models/ar_try_on_models.dart';
import '../models/category_management_model.dart';
import '../models/models.dart';
import '../models/outfit_recommendation_model.dart';
import '../models/trial_session.dart';
import 'package:flutter/foundation.dart';
import 'backend_api_client.dart';

class BackendCommerceService {
  BackendCommerceService({BackendApiClient? client})
    : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  bool get isConfigured => _client.isConfigured;

  bool _isTransientNetworkIssue(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('backend unreachable') ||
        message.contains('socketexception') ||
        message.contains('connection closed') ||
        message.contains('timed out') ||
        message.contains('clientexception');
  }

  Map<String, dynamic> _optionalEntry(String key, Object? value) {
    if (value == null) {
      return const {};
    }
    return <String, dynamic>{key: value};
  }

  Future<AppUser> getCurrentUserProfile() async {
    final payload = await _client.get('/auth/me', authenticated: true);
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return _appUserFromBackend(map);
  }

  Future<AppUser> saveTestUserPhone(String phone) async {
    final payload = await _client.post(
      '/auth/test-user',
      body: {'phone': phone},
    );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return _appUserFromBackend(map);
  }

  Future<List<UserAddress>> getUserAddresses() async {
    final payload = await _client.get('/auth/addresses', authenticated: true);
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return UserAddress.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<UserAddress> saveUserAddress(UserAddress address) async {
    final payload = await _client.post(
      '/auth/addresses',
      authenticated: true,
      body: address.toMap(),
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return UserAddress.fromMap(map, map['id']?.toString() ?? address.id);
  }

  Future<void> deleteUserAddress(String addressId) async {
    await _client.delete('/auth/addresses/$addressId', authenticated: true);
  }

  Future<UserMemory?> getUserMemory() async {
    final payload = await _client.get('/auth/memory', authenticated: true);
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final userId = map['userId']?.toString() ?? '';
    if (userId.isEmpty) {
      return null;
    }
    return UserMemory.fromMap(map, userId);
  }

  Future<UserMemory> saveUserMemory(UserMemory memory) async {
    final payload = await _client.put(
      '/auth/memory',
      authenticated: true,
      body: memory.toMap(),
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return UserMemory.fromMap(map, map['userId']?.toString() ?? memory.userId);
  }

  Future<BodyProfile?> getBodyProfile() async {
    try {
      final payload = await _client.get(
        '/user/body-profile',
        authenticated: true,
      );
      if (payload == null) {
        return null;
      }
      final map = Map<String, dynamic>.from(payload as Map);
      if (map.isEmpty || map['heightCm'] == null) {
        return null;
      }
      return BodyProfile.fromMap(map);
    } catch (_) {
      final payload = await _client.get('/auth/memory', authenticated: true);
      if (payload == null) {
        return null;
      }
      final map = Map<String, dynamic>.from(payload as Map);
      final height = map['heightCm'];
      final weight = map['weightKg'];
      if (height == null || weight == null) {
        return null;
      }
      return BodyProfile.fromMap(map);
    }
  }

  Future<List<Map<String, dynamic>>> getSavedCartItems() async {
    final payload = await _client.get('/auth/memory', authenticated: true);
    if (payload == null) {
      return const [];
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final items = map['cartItems'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    await _client.put(
      '/auth/memory',
      authenticated: true,
      body: {
        'cartItems': items,
        'cartUpdatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<BodyProfile> saveBodyProfile(BodyProfile profile) async {
    try {
      final payload = await _client.post(
        '/user/body-profile',
        authenticated: true,
        body: {
          ...profile.toMap(),
          'size': profile.recommendedSize,
          'height': profile.heightCm,
          'shoulder': profile.shoulderCm,
          'chest': profile.chestCm,
          'waist': profile.waistCm,
          'hips': profile.hipCm,
        },
      );
      return BodyProfile.fromMap(Map<String, dynamic>.from(payload as Map));
    } catch (_) {
      final payload = await _client.put(
        '/auth/memory',
        authenticated: true,
        body: {...profile.toMap(), 'size': profile.recommendedSize},
      );
      return BodyProfile.fromMap(Map<String, dynamic>.from(payload as Map));
    }
  }

  Future<List<MeasurementProfile>> getMeasurementProfiles() async {
    final payload = await _client.get(
      '/auth/measurements',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return MeasurementProfile.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<MeasurementProfile> saveMeasurementProfile(
    MeasurementProfile profile,
  ) async {
    final payload = await _client.post(
      '/auth/measurements',
      authenticated: true,
      body: {'id': profile.id, ...profile.toMap()},
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return MeasurementProfile.fromMap(map, map['id']?.toString() ?? profile.id);
  }

  Future<void> deleteMeasurementProfile(String profileId) async {
    await _client.delete('/auth/measurements/$profileId', authenticated: true);
  }

  Future<ReferralDashboardData> getReferralDashboard() async {
    final payload = await _client.get(
      '/auth/referrals/dashboard',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    final history = (map['history'] as List? ?? const []).whereType<Map>().map((
      item,
    ) {
      final referralMap = Map<String, dynamic>.from(item);
      return ReferralRecord.fromMap(
        referralMap,
        referralMap['id']?.toString() ?? '',
      );
    }).toList();
    return ReferralDashboardData(
      referralCode: map['referralCode']?.toString() ?? '',
      invitedCount: ((map['invitedCount'] ?? 0) as num).toInt(),
      completedCount: ((map['completedCount'] ?? 0) as num).toInt(),
      pendingCount: ((map['pendingCount'] ?? 0) as num).toInt(),
      earnedCredits: ((map['earnedCredits'] ?? 0) as num).toDouble(),
      walletBalance: ((map['walletBalance'] ?? 0) as num).toDouble(),
      tier: map['tier']?.toString() ?? 'Bronze',
      nextTierProgress: ((map['nextTierProgress'] ?? 0) as num).toDouble(),
      invitesToNextTier: ((map['invitesToNextTier'] ?? 0) as num).toInt(),
      history: history,
    );
  }

  Future<List<ReferralRecord>> getReferralHistory() async {
    final payload = await _client.get(
      '/auth/referrals/history',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ReferralRecord.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<bool> applyReferralCode(String code) async {
    final payload = await _client.post(
      '/auth/referrals/apply',
      authenticated: true,
      body: {'code': code},
    );
    return payload != null;
  }

  Future<List<GrowthOffer>> getGrowthOffers() async {
    final payload = await _client.get(
      '/auth/growth-offers',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return GrowthOffer.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<GrowthOffer> saveGrowthOffer(GrowthOffer offer) async {
    final payload = await _client.post(
      '/auth/growth-offers',
      authenticated: true,
      body: offer.toMap(),
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return GrowthOffer.fromMap(map, map['id']?.toString() ?? offer.id);
  }

  Future<GrowthOffer?> validateGrowthOffer({
    required String code,
    required double cartValue,
  }) async {
    final payload = await _client.post(
      '/auth/growth-offers/validate',
      authenticated: true,
      body: {'code': code, 'cartValue': cartValue},
    );
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    return GrowthOffer.fromMap(map, map['id']?.toString() ?? '');
  }

  Future<void> claimGrowthOffer(String code) async {
    await _client.post(
      '/auth/growth-offers/claim',
      authenticated: true,
      body: {'code': code},
    );
  }

  Future<Map<String, dynamic>> recommendSize({
    required double heightCm,
    required double weightKg,
    required String bodyType,
    String? fitPreference,
    String? productFit,
    double? shoulderCm,
    double? chestCm,
    double? waistCm,
    double? hipCm,
    double? armLengthCm,
    double? inseamCm,
    List<String>? availableSizes,
    Map<String, String>? sizeChart,
  }) async {
    final body =
        <String, dynamic>{
          'heightCm': heightCm,
          'weightKg': weightKg,
          'bodyType': bodyType,
          'fitPreference': fitPreference?.trim(),
          'productFit': productFit?.trim(),
          'shoulderCm': shoulderCm,
          'chestCm': chestCm,
          'waistCm': waistCm,
          'hipCm': hipCm,
          'armLengthCm': armLengthCm,
          'inseamCm': inseamCm,
          'availableSizes':
              (availableSizes != null && availableSizes.isNotEmpty)
              ? availableSizes
              : null,
          'sizeChart': (sizeChart != null && sizeChart.isNotEmpty)
              ? sizeChart
              : null,
        }..removeWhere(
          (key, value) => value == null || (value is String && value.isEmpty),
        );
    final payload = await _client.post(
      '/ai/recommend-size',
      authenticated: true,
      body: body,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getStylistChatResponse({
    required String prompt,
    String? focusedProductId,
    String? location,
    BodyProfile? bodyProfile,
    UserMemory? memory,
    List<ConversationMemoryMessage> recentHistory = const [],
  }) async {
    final payload = await _client.post(
      '/ai/stylist-chat',
      authenticated: true,
      body: {
        'prompt': prompt,
        if (focusedProductId != null && focusedProductId.trim().isNotEmpty)
          'focusedProductId': focusedProductId.trim(),
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (bodyProfile != null) ...{
          'heightCm': bodyProfile.heightCm,
          'weightKg': bodyProfile.weightKg,
          'bodyType': bodyProfile.bodyType,
          'size': bodyProfile.recommendedSize,
          'chestCm': bodyProfile.chestCm,
          'waistCm': bodyProfile.waistCm,
          'hipCm': bodyProfile.hipCm,
        },
        if (memory != null && memory.preferredStyle.trim().isNotEmpty)
          'preferredStyle': memory.preferredStyle.trim(),
        if (recentHistory.isNotEmpty)
          'recentHistory': recentHistory
              .take(6)
              .map((entry) => entry.toMap())
              .toList(),
      },
    );
    final map = Map<String, dynamic>.from(payload as Map);
    final rawProducts = (map['products'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final products = rawProducts
        .map((item) => _productFromBackend(Map<String, dynamic>.from(item)))
        .toList();
    return {...map, 'rawProducts': rawProducts, 'products': products};
  }

  Future<Map<String, dynamic>> getStylistRecommendations({
    required String prompt,
    BodyProfile? bodyProfile,
    UserMemory? memory,
    int limit = 4,
  }) async {
    final payload = await _client.post(
      '/ai/stylist-recommendations',
      authenticated: true,
      body: {
        'prompt': prompt,
        'limit': limit,
        if (bodyProfile != null) ...{
          'heightCm': bodyProfile.heightCm,
          'bodyType': bodyProfile.bodyType,
        },
        if (memory != null && memory.preferredStyle.trim().isNotEmpty)
          'preferredStyle': memory.preferredStyle.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getAiSpecConfig({
    required String category,
    String? subcategory,
  }) async {
    final payload = await _client.get(
      '/ai/specs/config',
      authenticated: true,
      queryParameters: {
        'category': category,
        if (subcategory != null && subcategory.trim().isNotEmpty) 'subcategory': subcategory.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> generateAiProductSpecs({
    String? productId,
    String? name,
    String? brand,
    String? category,
    String? subcategory,
    String? description,
    Map<String, dynamic>? attributes,
  }) async {
    final body = <String, dynamic>{};
    final normalizedProductId = productId?.trim();
    body['productId'] = (normalizedProductId == null || normalizedProductId.isEmpty)
        ? null
        : normalizedProductId;
    body['name'] = name;
    body['brand'] = brand;
    body['category'] = category;
    body['subcategory'] = subcategory;
    body['description'] = description;
    body['attributes'] = attributes;
    body.removeWhere((key, value) => value == null);
    final payload = await _client.post(
      '/ai/specs',
      authenticated: true,
      body: Map<String, dynamic>.from(body),
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<Store>> getStores() async {
    final payload = await _client.get('/stores');
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _storeFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Store>> getRankedCustomStores({
    String? category,
    String? style,
    double? budgetMin,
    double? budgetMax,
    int? deliveryDays,
    double? latitude,
    double? longitude,
  }) async {
    final payload = await _client.get(
      '/stores/custom/ranked',
      queryParameters: {
        if (category?.trim().isNotEmpty == true) 'category': category!.trim(),
        if (style?.trim().isNotEmpty == true) 'style': style!.trim(),
        if (budgetMin != null) 'budgetMin': budgetMin.toString(),
        if (budgetMax != null) 'budgetMax': budgetMax.toString(),
        if (deliveryDays != null) 'deliveryDays': deliveryDays.toString(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _storeFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BannerModel>> getBanners({bool includeInactive = false}) async {
    final payload = await _client.get(
      '/banners',
      authenticated: includeInactive,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => BannerModel.fromMap(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
  }

  Future<BannerModel> createBanner(BannerModel banner) async {
    final payload = await _client.post(
      '/banners',
      authenticated: true,
      body: banner.toMap(),
    );
    return BannerModel.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<BannerModel> updateBanner(BannerModel banner) async {
    final payload = await _client.put(
      '/banners/${banner.id}',
      authenticated: true,
      body: banner.toMap(),
    );
    return BannerModel.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<void> deleteBanner(String bannerId) async {
    await _client.delete('/banners/$bannerId', authenticated: true);
  }

  Future<HomeVisualConfigModel> getHomeVisualConfig({
    bool adminView = false,
  }) async {
    final payload = await _client.get(
      adminView ? '/admin/home-visuals' : '/home-visuals',
      authenticated: adminView,
    );
    return HomeVisualConfigModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<HomeVisualConfigModel> saveHomeVisualConfig(
    HomeVisualConfigModel config,
  ) async {
    final payload = await _client.put(
      '/admin/home-visuals',
      authenticated: true,
      body: config.toMap(),
    );
    return HomeVisualConfigModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<List<CategoryManagementModel>> getAdminCategories() async {
    final payload = await _client.get('/api/categories', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              CategoryManagementModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
  }

  Future<CategoryManagementModel> createCategory(
    CategoryManagementModel category,
  ) async {
    final payload = await _client.post(
      '/api/categories',
      authenticated: true,
      body: category.toMap(),
    );
    return CategoryManagementModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CategoryManagementModel> updateCategory(
    CategoryManagementModel category,
  ) async {
    final payload = await _client.put(
      '/api/categories/${category.id}',
      authenticated: true,
      body: category.toMap(),
    );
    return CategoryManagementModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CategoryManagementModel> toggleCategoryStatus({
    required String categoryId,
    required bool isActive,
  }) async {
    final payload = await _client.patch(
      '/api/categories/$categoryId/status',
      authenticated: true,
      body: {'isActive': isActive},
    );
    return CategoryManagementModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client.delete('/api/categories/$categoryId', authenticated: true);
  }

  Future<SubcategoryManagementModel> addSubcategory({
    required String categoryId,
    required SubcategoryManagementModel subcategory,
  }) async {
    final payload = await _client.post(
      '/api/categories/$categoryId/subcategories',
      authenticated: true,
      body: subcategory.toMap(),
    );
    return SubcategoryManagementModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<SubcategoryManagementModel> updateSubcategory({
    required String categoryId,
    required SubcategoryManagementModel subcategory,
  }) async {
    final payload = await _client.put(
      '/api/categories/$categoryId/subcategories/${subcategory.id}',
      authenticated: true,
      body: subcategory.toMap(),
    );
    return SubcategoryManagementModel.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<void> deleteSubcategory({
    required String categoryId,
    required String subcategoryId,
  }) async {
    await _client.delete(
      '/api/categories/$categoryId/subcategories/$subcategoryId',
      authenticated: true,
    );
  }

  Future<List<Product>> getProducts() async {
    final payload = await _client.get('/products');
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _productFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OutfitRecommendation>> getOutfits({
    String? userId,
    String? productId,
    String? occasion,
    String? budget,
    String? style,
    int limit = 6,
    bool authenticated = false,
  }) async {
    final payload = await _client.get(
      '/api/outfits',
      authenticated: authenticated,
      queryParameters: {
        if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (productId != null && productId.trim().isNotEmpty)
          'productId': productId.trim(),
        if (occasion != null && occasion.trim().isNotEmpty)
          'occasion': occasion.trim(),
        if (budget != null && budget.trim().isNotEmpty) 'budget': budget.trim(),
        if (style != null && style.trim().isNotEmpty) 'style': style.trim(),
        'limit': '$limit',
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              OutfitRecommendation.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<OutfitRecommendation>> getCompleteLook(
    String productId, {
    String? userId,
    int limit = 3,
    bool authenticated = false,
  }) async {
    final payload = await _client.get(
      '/api/outfits/complete-look/$productId',
      authenticated: authenticated,
      queryParameters: {
        if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        'limit': '$limit',
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              OutfitRecommendation.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> getBodyTypeRecommendations({
    String? userId,
    int limit = 10,
    bool authenticated = true,
  }) async {
    final payload = await _client.get(
      '/api/outfits/body-type',
      authenticated: authenticated,
      queryParameters: {
        if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
        'limit': '$limit',
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<void> trackOutfitInteraction({
    required String action,
    String? outfitId,
    String? productId,
    List<String> itemIds = const [],
    Map<String, dynamic> filters = const {},
    Map<String, dynamic> metadata = const {},
  }) async {
    await _client.post(
      '/api/outfits/track',
      authenticated: true,
      body: {
        'action': action,
        if (outfitId != null && outfitId.trim().isNotEmpty)
          'outfitId': outfitId.trim(),
        if (productId != null && productId.trim().isNotEmpty)
          'productId': productId.trim(),
        'itemIds': itemIds,
        'filters': filters,
        'metadata': metadata,
      },
    );
  }

  Future<List<ReviewModel>> getProductReviews(String productId) async {
    final payload = await _client.get('/reviews/products/$productId');
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ReviewModel.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<List<ReviewModel>> getStoreReviews(String storeId) async {
    final payload = await _client.get('/reviews/stores/$storeId');
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ReviewModel.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<ReviewModel> saveReview(ReviewModel review) async {
    final payload = await _client.post(
      '/reviews',
      authenticated: true,
      body: {'id': review.id, ...review.toMap()},
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReviewModel.fromMap(map, map['id']?.toString() ?? review.id);
  }

  Future<void> deleteReview(String reviewId) async {
    await _client.delete('/reviews/$reviewId', authenticated: true);
  }

  Future<List<OrderModel>> getUserOrders() async {
    final payload = await _client.get('/orders', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BookingModel> createBooking(BookingModel booking) async {
    final payload = await _client.post(
      '/bookings',
      authenticated: true,
      body: booking.toMap(),
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return BookingModel.fromMap(map, map['id']?.toString() ?? booking.id);
  }

  Future<List<BookingModel>> getMyBookings() async {
    final payload = await _client.get('/bookings/me', authenticated: true);
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return BookingModel.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<List<SupportChat>> getSupportChats({
    String? status,
    String? type,
  }) async {
    final payload = await _client.get(
      '/support/chats',
      authenticated: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _supportChatFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SupportChat?> getSupportChatById(String chatId) async {
    try {
      final payload = await _client.get(
        '/support/chats/$chatId',
        authenticated: true,
      );
      return _supportChatFromBackend(Map<String, dynamic>.from(payload as Map));
    } catch (_) {
      return null;
    }
  }

  Future<List<SupportMessage>> getSupportMessages(
    String chatId, {
    int limit = 20,
    String? beforeTimestamp,
  }) async {
    final payload = await _client.get(
      '/support/chats/$chatId/messages',
      authenticated: true,
      queryParameters: {
        'limit': '$limit',
        if (beforeTimestamp != null && beforeTimestamp.isNotEmpty)
          'before': beforeTimestamp,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => _supportMessageFromBackend(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<SupportChat> createSupportChat(String issueType) async {
    final payload = await _client.post(
      '/support/chats',
      authenticated: true,
      body: {'issueType': issueType},
    );
    return _supportChatFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<SupportChat> sendSupportMessage({
    required String chatId,
    required String text,
    required String imageUrl,
    String? assistantReplyText,
    String? assistantTimestamp,
    String? status,
  }) async {
    final payload = await _client.post(
      '/support/chats/$chatId/messages',
      authenticated: true,
      body: {
        'text': text,
        'imageUrl': imageUrl,
        if (assistantReplyText != null && assistantReplyText.isNotEmpty)
          'assistantReplyText': assistantReplyText,
        if (assistantTimestamp != null && assistantTimestamp.isNotEmpty)
          'assistantTimestamp': assistantTimestamp,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _supportChatFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<void> markSupportChatRead(String chatId) async {
    await _client.post('/support/chats/$chatId/read', authenticated: true);
  }

  Future<void> closeSupportChat(String chatId) async {
    await _client.post('/support/chats/$chatId/close', authenticated: true);
  }

  Future<void> reopenSupportChat(String chatId) async {
    await _client.post('/support/chats/$chatId/reopen', authenticated: true);
  }

  Future<List<ConversationMemoryMessage>> getChatHistory(
    String chatId, {
    int limit = 15,
  }) async {
    final payload = await _client.get(
      '/ai/history/$chatId',
      authenticated: true,
      queryParameters: {'limit': '$limit'},
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => ConversationMemoryMessage.fromMap(
            Map<String, dynamic>.from(item),
            item['id']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<void> appendChatHistoryEntry({
    required String chatId,
    required ConversationMemoryMessage entry,
  }) async {
    await _client.post(
      '/ai/history/$chatId',
      authenticated: true,
      body: entry.toMap(),
    );
  }

  Future<void> clearChatHistory() async {
    await _client.delete('/ai/history', authenticated: true);
  }

  Future<Map<String, dynamic>?> getSupportResponseCache(String cacheKey) async {
    final payload = await _client.get(
      '/ai/support-cache',
      authenticated: true,
      queryParameters: {'key': cacheKey},
    );
    if (payload == null) {
      return null;
    }
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<void> setSupportResponseCache({
    required String cacheKey,
    required String response,
    required String intent,
    required String updatedAt,
  }) async {
    await _client.post(
      '/ai/support-cache',
      authenticated: true,
      body: {
        'key': cacheKey,
        'response': response,
        'intent': intent,
        'updatedAt': updatedAt,
      },
    );
  }

  Future<int> getTodayAiUsageCount(String dateKey) async {
    final payload = await _client.get(
      '/ai/usage/today',
      authenticated: true,
      queryParameters: {'date': dateKey},
    );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return ((map['aiCallsToday'] ?? 0) as num).toInt();
  }

  Future<void> incrementTodayAiUsage(String dateKey) async {
    await _client.post(
      '/ai/usage/increment',
      authenticated: true,
      body: {'dateKey': dateKey},
    );
  }

  Future<void> logAiUsage({
    required AiUsageLogEntry entry,
    required String date,
  }) async {
    await _client.post(
      '/ai/usage/log',
      authenticated: true,
      body: {...entry.toMap(), 'date': date},
    );
  }

  Future<List<AiUsageLogEntry>> getAiUsageLogs({int limit = 120}) async {
    final payload = await _client.get(
      '/ai/usage/logs',
      authenticated: true,
      queryParameters: {'limit': '$limit'},
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => AiUsageLogEntry.fromMap(
            Map<String, dynamic>.from(item),
            item['id']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<List<AiDailyStat>> getAiDailyStats() async {
    final payload = await _client.get('/ai/usage/daily', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => AiDailyStat.fromMap(
            Map<String, dynamic>.from(item),
            item['date']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<List<UserAiUsageStat>> getUserAiUsageStats() async {
    final payload = await _client.get('/ai/usage/users', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) => UserAiUsageStat.fromMap(
            Map<String, dynamic>.from(item),
            item['userId']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<void> logAiEvent({
    required String type,
    required String message,
    String prompt = '',
    String reason = '',
    String intentType = '',
    String? timestamp,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'message': message,
      'prompt': prompt,
      'reason': reason,
      'intentType': intentType,
    };
    if (timestamp != null) {
      body['timestamp'] = timestamp;
    }
    await _client.post('/ai/events', authenticated: true, body: body);
  }

  Future<AdminAnalytics> getAdminDashboard() async {
    final payload = await _client.get('/admin/dashboard', authenticated: true);
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    final topStores = ((map['topStores'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return Store.fromMap({
            'id': data['id'],
            'store_id': data['id'],
            'name': data['name'] ?? '',
            'logoUrl': data['logoUrl'] ?? '',
            'imageUrl': data['logoUrl'] ?? '',
            'rating': data['rating'] ?? 0,
          }, data['id']?.toString() ?? '');
        })
        .toList();

    return AdminAnalytics(
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      platformCommissionRevenue: (map['platformCommissionRevenue'] ?? 0)
          .toDouble(),
      vendorPayouts: (map['vendorPayouts'] ?? 0).toDouble(),
      riderPayouts: (map['riderPayouts'] ?? 0).toDouble(),
      totalOrders: ((map['totalOrders'] ?? 0) as num).toInt(),
      ordersToday: ((map['ordersToday'] ?? 0) as num).toInt(),
      topStores: topStores,
      dailySales: ((map['dailySales'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) {
            final data = Map<String, dynamic>.from(item);
            return AnalyticsPoint(
              label: data['label']?.toString() ?? '',
              value: ((data['value'] ?? 0) as num).toDouble(),
            );
          })
          .toList(),
      weeklySales: ((map['weeklySales'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) {
            final data = Map<String, dynamic>.from(item);
            return AnalyticsPoint(
              label: data['label']?.toString() ?? '',
              value: ((data['value'] ?? 0) as num).toDouble(),
            );
          })
          .toList(),
    );
  }

  Future<VendorAnalytics> getVendorDashboard() async {
    dynamic payload;
    try {
      payload = await _client.get('/finance/vendor/dashboard', authenticated: true);
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.get('/vendor/dashboard', authenticated: true);
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final wallet = Map<String, dynamic>.from(map['wallet'] as Map? ?? const {});
    final transactions = ((map['transactions'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => WalletTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    final dailySeries = ((map['dailySeries'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return AnalyticsPoint(
            label: data['label']?.toString() ?? '',
            value: ((data['value'] ?? 0) as num).toDouble(),
          );
        })
        .toList();
    return VendorAnalytics(
      todayRevenue:
          ((map['todayRevenue'] ?? map['todayGrossRevenue'] ?? 0) as num)
              .toDouble(),
      todayEarnings: ((map['todayEarnings'] ?? 0) as num).toDouble(),
      todayCommission: ((map['todayCommission'] ?? 0) as num).toDouble(),
      weeklyRevenue:
          ((map['weeklyRevenue'] ?? map['weeklyGrossRevenue'] ?? 0) as num)
              .toDouble(),
      weeklyCommission: ((map['weeklyCommission'] ?? 0) as num).toDouble(),
      totalSales:
          ((map['totalSales'] ??
                      map['weeklyEarnings'] ??
                      map['weeklyRevenue'] ??
                      0)
                  as num)
              .toDouble(),
      availableBalance:
          ((map['availableBalance'] ?? wallet['balance'] ?? 0) as num)
              .toDouble(),
      totalEarnings: ((map['totalEarnings'] ?? 0) as num).toDouble(),
      pendingAmount: ((map['pendingAmount'] ?? 0) as num).toDouble(),
      reservedAmount: ((map['reservedAmount'] ?? 0) as num).toDouble(),
      lastPayoutAmount: ((map['lastPayoutAmount'] ?? 0) as num).toDouble(),
      lastPayoutAt: map['lastPayoutAt']?.toString() ?? '',
      orders: ((map['ordersCompleted'] ?? 0) as num).toInt(),
      ordersCompleted: ((map['ordersCompleted'] ?? 0) as num).toInt(),
      ordersToday: ((map['ordersToday'] ?? 0) as num).toInt(),
      bestSellingProducts: const [],
      salesTrend: dailySeries,
      transactions: transactions,
    );
  }

  Future<RiderAnalytics> getRiderDashboard() async {
    dynamic payload;
    try {
      payload = await _client.get('/finance/rider/dashboard', authenticated: true);
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.get('/rider/dashboard', authenticated: true);
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final transactions = ((map['transactions'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) => WalletTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    return RiderAnalytics(
      todayDeliveries: ((map['todayDeliveries'] ?? 0) as num).toInt(),
      earningsToday: ((map['earningsToday'] ?? 0) as num).toDouble(),
      totalEarnings: ((map['totalEarnings'] ?? 0) as num).toDouble(),
      pendingPayout: ((map['pendingPayout'] ?? 0) as num).toDouble(),
      availableBalance: ((map['availableBalance'] ?? 0) as num).toDouble(),
      reservedAmount: ((map['reservedAmount'] ?? 0) as num).toDouble(),
      transactions: transactions,
    );
  }

  Future<List<AppUser>> getAdminUsers() async {
    final payload = await _client.get('/admin/users', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _appUserFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<PlatformSettings> getPlatformSettings() async {
    final payload = await _client.get('/admin/settings', authenticated: true);
    return PlatformSettings.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<PlatformSettings> savePlatformSettings(
    PlatformSettings settings,
  ) async {
    final payload = await _client.put(
      '/admin/settings',
      authenticated: true,
      body: settings.toMap(),
    );
    return PlatformSettings.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<PricingConfigModel> getAdminPricingConfig() async {
    final payload = await _client.get('/admin/pricing', authenticated: true);
    final map = Map<String, dynamic>.from(payload as Map);
    final config = Map<String, dynamic>.from(map['config'] as Map? ?? const {});
    config['auditLogs'] = map['auditLogs'] ?? const [];
    return PricingConfigModel.fromMap(config);
  }

  Future<PricingConfigModel> updateAdminPricingScope({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final payload = await _client.post(
      endpoint,
      authenticated: true,
      body: body,
    );
    return PricingConfigModel.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> simulateAdminPricing({
    required Map<String, dynamic> body,
  }) async {
    final payload = await _client.post(
      '/admin/pricing/simulate',
      authenticated: true,
      body: body,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<AppNotification>> getAdminNotifications() async {
    final payload = await _client.get(
      '/admin/notifications',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> createAdminNotification(AppNotification notification) async {
    await _client.post(
      '/admin/notifications',
      authenticated: true,
      body: notification.toMap(),
    );
  }

  Future<List<PayoutModel>> getAdminPayouts() async {
    final payload = await _client.get('/admin/payouts', authenticated: true);
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return PayoutModel.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<PayoutModel?> processAdminPayout({
    required String storeId,
    required String periodLabel,
  }) async {
    final payload = await _client.post(
      '/admin/payouts/process',
      authenticated: true,
      body: {'storeId': storeId, 'periodLabel': periodLabel},
    );
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    return PayoutModel.fromMap(map, map['id']?.toString() ?? '');
  }

  WalletSummary _walletSummaryFromPayload(
    Map<String, dynamic> map, {
    required String kind,
  }) {
    final transactions = (map['transactions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => WalletTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    final withdrawalRequests = (map['withdrawalRequests'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              WithdrawalRequestSummary.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    final linkedId = kind == 'vendor'
        ? map['storeId']?.toString() ?? ''
        : map['riderId']?.toString() ?? '';
    final payoutProfile = PayoutProfileSummary.fromMap(
      Map<String, dynamic>.from(map['payoutProfile'] as Map? ?? const {}),
    );
    return WalletSummary(
      id: linkedId.isNotEmpty ? linkedId : kind,
      kind: kind,
      linkedId: linkedId,
      balance: ((map['balance'] ?? 0) as num).toDouble(),
      pendingAmount: ((map['pendingAmount'] ?? 0) as num).toDouble(),
      reservedAmount: ((map['reservedAmount'] ?? 0) as num).toDouble(),
      totalEarnings: ((map['totalEarnings'] ?? 0) as num).toDouble(),
      totalWithdrawn: ((map['totalWithdrawn'] ?? 0) as num).toDouble(),
      lastSettlementDate: map['lastSettlementDate']?.toString() ?? '',
      commissionRate: map['commissionRate'] == null
          ? null
          : (map['commissionRate'] as num).toDouble(),
      payoutProfile: payoutProfile,
      transactions: transactions,
      withdrawalRequests: withdrawalRequests,
    );
  }

  Future<WalletSummary> getVendorWallet() async {
    dynamic payload;
    try {
      payload = await _client.get('/wallet/vendor', authenticated: true);
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.get('/vendor/wallet', authenticated: true);
    }
    return _walletSummaryFromPayload(
      Map<String, dynamic>.from(payload as Map),
      kind: 'vendor',
    );
  }

  Future<WalletSummary> requestVendorWithdraw(double amount) async {
    dynamic payload;
    try {
      payload = await _client.post(
        '/wallet/vendor/withdraw',
        authenticated: true,
        body: {'amount': amount},
      );
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.post(
        '/vendor/withdraw',
        authenticated: true,
        body: {'amount': amount},
      );
    }
    return _walletSummaryFromPayload(
      Map<String, dynamic>.from(payload as Map),
      kind: 'vendor',
    );
  }

  Future<WalletSummary> getRiderWallet() async {
    dynamic payload;
    try {
      payload = await _client.get('/wallet/rider', authenticated: true);
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.get('/rider/wallet', authenticated: true);
    }
    return _walletSummaryFromPayload(
      Map<String, dynamic>.from(payload as Map),
      kind: 'rider',
    );
  }

  Future<WalletSummary> requestRiderWithdraw(double amount) async {
    dynamic payload;
    try {
      payload = await _client.post(
        '/wallet/rider/withdraw',
        authenticated: true,
        body: {'amount': amount},
      );
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.post(
        '/rider/withdraw',
        authenticated: true,
        body: {'amount': amount},
      );
    }
    return _walletSummaryFromPayload(
      Map<String, dynamic>.from(payload as Map),
      kind: 'rider',
    );
  }

  Future<PayoutProfileSummary> getVendorPayoutProfile() async {
    final payload = await _client.get(
      '/vendor/payout-account',
      authenticated: true,
    );
    return PayoutProfileSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<PayoutProfileSummary> saveVendorPayoutProfile({
    required String methodType,
    required String accountHolderName,
    String upiId = '',
    String bankAccountNumber = '',
    String bankIfsc = '',
    String bankName = '',
  }) async {
    final payload = await _client.post(
      '/vendor/payout-account',
      authenticated: true,
      body: {
        'methodType': methodType,
        'accountHolderName': accountHolderName,
        'upiId': upiId,
        'bankAccountNumber': bankAccountNumber,
        'bankIfsc': bankIfsc,
        'bankName': bankName,
      },
    );
    return PayoutProfileSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<PayoutProfileSummary> getRiderPayoutProfile() async {
    final payload = await _client.get(
      '/rider/payout-account',
      authenticated: true,
    );
    return PayoutProfileSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<PayoutProfileSummary> saveRiderPayoutProfile({
    required String methodType,
    required String accountHolderName,
    String upiId = '',
    String bankAccountNumber = '',
    String bankIfsc = '',
    String bankName = '',
  }) async {
    final payload = await _client.post(
      '/rider/payout-account',
      authenticated: true,
      body: {
        'methodType': methodType,
        'accountHolderName': accountHolderName,
        'upiId': upiId,
        'bankAccountNumber': bankAccountNumber,
        'bankIfsc': bankIfsc,
        'bankName': bankName,
      },
    );
    return PayoutProfileSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<AdminFinanceSummary> getAdminFinance() async {
    dynamic payload;
    try {
      payload = await _client.get('/finance/overview', authenticated: true);
    } on BackendApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      payload = await _client.get('/admin/finance', authenticated: true);
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final adminWallet = Map<String, dynamic>.from(
      map['adminWallet'] as Map? ?? const {},
    );
    final vendorWallets = (map['vendorWallets'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => _walletSummaryFromPayload(
            Map<String, dynamic>.from(item),
            kind: 'vendor',
          ),
        )
        .toList();
    final riderWallets = (map['riderWallets'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => _walletSummaryFromPayload(
            Map<String, dynamic>.from(item),
            kind: 'rider',
          ),
        )
        .toList();
    final transactions = (map['transactions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => WalletTransaction.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    final withdrawalRequests = (map['withdrawalRequests'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              WithdrawalRequestSummary.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    final fraudAlerts = (map['fraudAlerts'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => FraudAlertSummary.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
    return AdminFinanceSummary(
      totalCommission: ((adminWallet['totalCommission'] ?? 0) as num)
          .toDouble(),
      totalRevenue: ((adminWallet['totalRevenue'] ?? 0) as num).toDouble(),
      payoutsDone: ((adminWallet['payoutsDone'] ?? 0) as num).toDouble(),
      vendorSettlementsDone:
          ((adminWallet['vendorSettlementsDone'] ?? 0) as num).toDouble(),
      riderSettlementsDone: ((adminWallet['riderSettlementsDone'] ?? 0) as num)
          .toDouble(),
      failedSettlements: ((adminWallet['failedSettlements'] ?? 0) as num)
          .toDouble(),
      vendorPending: ((map['vendorPending'] ?? 0) as num).toDouble(),
      riderPending: ((map['riderPending'] ?? 0) as num).toDouble(),
      pendingWithdrawalAmount: ((map['pendingWithdrawalAmount'] ?? 0) as num)
          .toDouble(),
      vendorWallets: vendorWallets,
      riderWallets: riderWallets,
      transactions: transactions,
      withdrawalRequests: withdrawalRequests,
      fraudAlerts: fraudAlerts,
      flaggedUsers: ((map['flaggedUsers'] ?? 0) as num).toInt(),
    );
  }

  Future<List<Map<String, dynamic>>> settleVendorPayouts({
    String? storeId,
    String periodLabel = 'Vendor settlement',
  }) async {
    final payload = await _client.post(
      '/admin/finance/settlements/vendors',
      authenticated: true,
      body: {
        if (storeId != null && storeId.trim().isNotEmpty)
          'storeId': storeId.trim(),
        'periodLabel': periodLabel,
      },
    );
    return (payload as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> settleRiderPayouts({
    String? riderId,
    String periodLabel = 'Rider settlement',
  }) async {
    final payload = await _client.post(
      '/admin/finance/settlements/riders',
      authenticated: true,
      body: {
        if (riderId != null && riderId.trim().isNotEmpty)
          'riderId': riderId.trim(),
        'periodLabel': periodLabel,
      },
    );
    return (payload as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<WithdrawalRequestSummary> approveWithdrawalRequest(
    String requestId,
  ) async {
    final payload = await _client.post(
      '/admin/finance/withdrawals/$requestId/approve',
      authenticated: true,
    );
    return WithdrawalRequestSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<WithdrawalRequestSummary> rejectWithdrawalRequest({
    required String requestId,
    required String reason,
  }) async {
    final payload = await _client.post(
      '/admin/finance/withdrawals/$requestId/reject',
      authenticated: true,
      body: {'reason': reason},
    );
    return WithdrawalRequestSummary.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<Map<String, dynamic>> runScheduledSettlements(
    String walletType,
  ) async {
    final payload = await _client.post(
      '/admin/finance/settlements/run',
      authenticated: true,
      body: {'walletType': walletType},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<FraudAlertSummary> updateFraudAlertStatus({
    required String alertId,
    required String status,
  }) async {
    final payload = await _client.patch(
      '/admin/finance/fraud-alerts/$alertId',
      authenticated: true,
      body: {'status': status},
    );
    return FraudAlertSummary.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<List<DisputeRecord>> getAdminDisputes() async {
    final payload = await _client.get('/admin/disputes', authenticated: true);
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return DisputeRecord.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<DisputeRecord> updateAdminDispute(DisputeRecord dispute) async {
    final payload = await _client.patch(
      '/admin/disputes/${dispute.id}',
      authenticated: true,
      body: dispute.toMap(),
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return DisputeRecord.fromMap(map, map['id']?.toString() ?? dispute.id);
  }

  Future<List<ActivityLogEntry>> getAdminActivityLogs() async {
    final payload = await _client.get(
      '/admin/activity-logs',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ActivityLogEntry.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<void> createAdminActivityLog(ActivityLogEntry entry) async {
    await _client.post(
      '/admin/activity-logs',
      authenticated: true,
      body: entry.toMap(),
    );
  }

  Future<List<Store>> getAdminStores() async {
    final payload = await _client.get('/admin/stores', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _storeFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Product>> getAdminProducts() async {
    final payload = await _client.get('/admin/products', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _productFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OrderModel>> getAdminOrders() async {
    final payload = await _client.get('/admin/orders', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OpsAlertItem>> getOpsAlerts({
    int limit = 50,
    String? severity,
  }) async {
    final payload = await _client.get(
      '/ops/alerts',
      authenticated: true,
      queryParameters: {
        'limit': '$limit',
        if (severity != null && severity.trim().isNotEmpty)
          'severity': severity.trim().toUpperCase(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return OpsAlertItem.fromMap(
            map,
            map['id']?.toString() ?? map['_id']?.toString() ?? '',
          );
        })
        .toList();
  }

  Future<void> triggerOpsDetection() async {
    await _client.post('/ops/detect', authenticated: true);
  }

  Future<void> runOpsAlertAction(String alertId) async {
    await _client.post('/ops/alerts/$alertId/action', authenticated: true);
  }

  Future<void> opsReassignOrder(String orderId) async {
    await _client.post('/ops/orders/$orderId/reassign', authenticated: true);
  }

  Future<void> opsCancelOrder(String orderId) async {
    await _client.post('/ops/orders/$orderId/cancel', authenticated: true);
  }

  Future<void> opsForceDispatch(String orderId) async {
    await _client.post('/ops/dispatch/$orderId/force', authenticated: true);
  }

  Future<void> opsRetryPayment(String orderId) async {
    await _client.post('/ops/payments/$orderId/retry', authenticated: true);
  }

  Future<List<OpsActionLogEntry>> getOpsLogs({int limit = 100}) async {
    final payload = await _client.get(
      '/ops/logs',
      authenticated: true,
      queryParameters: {'limit': '$limit'},
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return OpsActionLogEntry.fromMap(
            map,
            map['id']?.toString() ?? map['_id']?.toString() ?? '',
          );
        })
        .toList();
  }

  Future<List<OpsMetricSnapshot>> getOpsMetrics({
    String type = 'hourly',
    int limit = 24,
  }) async {
    final payload = await _client.get(
      '/ops/metrics',
      authenticated: true,
      queryParameters: {
        'type': type,
        'limit': '$limit',
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return OpsMetricSnapshot.fromMap(
            map,
            map['id']?.toString() ?? map['_id']?.toString() ?? '',
          );
        })
        .toList();
  }

  Future<OpsLiveSnapshot> getOpsLive() async {
    final payload = await _client.get('/ops/live', authenticated: true);
    final map = Map<String, dynamic>.from(payload as Map);

    final liveOrders = ((map['liveOrders'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final normalized = Map<String, dynamic>.from(item);
          normalized['id'] ??= normalized['_id']?.toString() ?? '';
          return _orderFromBackend(normalized);
        })
        .toList();

    final riders = ((map['riders'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final raw = Map<String, dynamic>.from(item);
          return AppUser.fromMap({
            'id': raw['uid']?.toString() ?? raw['_id']?.toString() ?? '',
            'uid': raw['uid']?.toString() ?? '',
            'name': raw['name']?.toString() ?? '',
            'role': 'rider',
            'riderApprovalStatus':
                raw['riderApprovalStatus']?.toString() ?? 'approved',
            'riderCity': raw['riderCity']?.toString() ?? '',
            'isActive': true,
            'latitude': raw['latitude'],
            'longitude': raw['longitude'],
          });
        })
        .toList();

    final vendors = ((map['vendors'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final raw = Map<String, dynamic>.from(item);
          return AppUser.fromMap({
            'id': raw['uid']?.toString() ?? raw['_id']?.toString() ?? '',
            'uid': raw['uid']?.toString() ?? '',
            'name': raw['name']?.toString() ?? '',
            'role': 'vendor',
            'storeId': raw['storeId']?.toString() ?? '',
            'city': raw['city']?.toString() ?? '',
            'isActive': true,
          });
        })
        .toList();

    final dispatch = ((map['dispatch'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final alertCountsRaw = ((map['alertCounts'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final alertCounts = <String, int>{};
    for (final row in alertCountsRaw) {
      final key = row['_id']?.toString().toUpperCase() ?? 'LOW';
      alertCounts[key] = ((row['count'] ?? 0) as num).toInt();
    }

    return OpsLiveSnapshot(
      liveOrders: liveOrders,
      riders: riders,
      vendors: vendors,
      dispatch: dispatch,
      alertCounts: alertCounts,
    );
  }

  Future<OpsSimulationOutput> runOpsSimulation({
    required int orders,
    required int riders,
  }) async {
    final payload = await _client.post(
      '/ops/simulate',
      authenticated: true,
      body: {
        'orders': orders,
        'riders': riders,
      },
    );
    return OpsSimulationOutput.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> dispatchAssignOrder(String orderId) async {
    final payload = await _client.post(
      '/dispatch/assign',
      authenticated: true,
      body: {'orderId': orderId},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> dispatchBatchAssign({String city = ''}) async {
    final payload = await _client.post(
      '/dispatch/batch-assign',
      authenticated: true,
      body: {'city': city},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<Map<String, dynamic>>> getDispatchBatches({
    String? riderId,
    String? status,
  }) async {
    final payload = await _client.get(
      '/dispatch/batches',
      authenticated: true,
      queryParameters: {
        if (riderId != null && riderId.trim().isNotEmpty) 'riderId': riderId.trim(),
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> triggerDispatchRebalance() async {
    final payload = await _client.post('/dispatch/rebalance', authenticated: true);
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getDispatchSlaOverview({
    String? riderId,
    String? vendorId,
    String? storeId,
  }) async {
    final payload = await _client.get(
      '/dispatch/sla',
      authenticated: true,
      queryParameters: {
        if (riderId != null && riderId.trim().isNotEmpty) 'riderId': riderId.trim(),
        if (vendorId != null && vendorId.trim().isNotEmpty) 'vendorId': vendorId.trim(),
        if (storeId != null && storeId.trim().isNotEmpty) 'storeId': storeId.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getDispatchEta(String orderId) async {
    final payload = await _client.get('/dispatch/eta/$orderId', authenticated: true);
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<TrialSession>> getAdminTrialHomeSessions({String? status}) async {
    final payload = await _client.get(
      '/admin/trial-home',
      authenticated: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => TrialSession.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<TrialSession> getAdminTrialHomeSession(String id) async {
    final payload = await _client.get('/admin/trial-home/$id', authenticated: true);
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> updateAdminTrialHomeSession({
    required String id,
    String? status,
    String? note,
    String? paymentStatus,
  }) async {
    final payload = await _client.patch(
      '/admin/trial-home/$id',
      authenticated: true,
      body: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> getVendorTrialHomeDashboard() async {
    final payload = await _client.get(
      '/vendor/trial-home/dashboard',
      authenticated: true,
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<TrialSession>> getVendorTrialHomeSessions({
    String? status,
    String? approvalStatus,
  }) async {
    final payload = await _client.get(
      '/vendor/trial-home/sessions',
      authenticated: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (approvalStatus != null && approvalStatus.isNotEmpty)
          'approvalStatus': approvalStatus,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => TrialSession.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<TrialSession> updateVendorTrialHomeSession({
    required String id,
    String? status,
    String? note,
    String? paymentStatus,
    String? returnDecision,
  }) async {
    final payload = await _client.patch(
      '/vendor/trial-home/$id/status',
      authenticated: true,
      body: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
        if (returnDecision != null && returnDecision.isNotEmpty)
          'returnDecision': returnDecision,
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> approveTrialHomeRequest(String id, {String note = ''}) async {
    final payload = await _client.post(
      '/trial-home/$id/approve',
      authenticated: true,
      body: {
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<TrialSession> rejectTrialHomeRequest(String id, {String note = ''}) async {
    final payload = await _client.post(
      '/trial-home/$id/reject',
      authenticated: true,
      body: {
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<List<Map<String, dynamic>>> getVendorTrialHomeProductSettings() async {
    final payload = await _client.get(
      '/vendor/trial-home/settings/products',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> updateVendorTrialHomeProductSettings({
    required String productId,
    required Map<String, dynamic> trialHome,
  }) async {
    final payload = await _client.patch(
      '/vendor/trial-home/settings/products/$productId',
      authenticated: true,
      body: {'trialHome': trialHome},
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<VendorKycRequest>> getVendorKycRequests({String? status}) async {
    final payload = await _client.get(
      '/admin/kyc/vendors',
      authenticated: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              _vendorKycRequestFromBackend(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<RiderKycRequest>> getRiderKycRequests({String? status}) async {
    final payload = await _client.get(
      '/admin/kyc/riders',
      authenticated: true,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map(
          (item) =>
              _riderKycRequestFromBackend(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<VendorKycRequest?> getMyVendorKycRequest() async {
    final payload = await _client.get('/kyc/vendor/me', authenticated: true);
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    if (map.isEmpty) {
      return null;
    }
    return _vendorKycRequestFromBackend(map);
  }

  Future<RiderKycRequest?> getMyRiderKycRequest() async {
    final payload = await _client.get('/kyc/rider/me', authenticated: true);
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    if (map.isEmpty) {
      return null;
    }
    return _riderKycRequestFromBackend(map);
  }

  Future<VendorKycRequest> submitVendorKycRequest(
    VendorKycRequest request,
  ) async {
    final payload = await _client.post(
      '/kyc/vendor',
      authenticated: true,
      body: request.toMap(),
    );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return _vendorKycRequestFromBackend(map);
  }

  Future<RiderKycRequest> submitRiderKycRequest(RiderKycRequest request) async {
    final payload = await _client.post(
      '/kyc/rider',
      authenticated: true,
      body: request.toMap(),
    );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return _riderKycRequestFromBackend(map);
  }

  Future<void> reviewVendorKycRequest({
    required String requestId,
    required String status,
    String reason = '',
  }) async {
    await _client.patch(
      '/admin/kyc/vendors/$requestId/review',
      authenticated: true,
      body: {'status': status, 'reason': reason},
    );
  }

  Future<void> reviewRiderKycRequest({
    required String requestId,
    required String status,
    String reason = '',
  }) async {
    await _client.patch(
      '/admin/kyc/riders/$requestId/review',
      authenticated: true,
      body: {'status': status, 'reason': reason},
    );
  }

  Future<Store?> getOwnStore() async {
    try {
      final payload = await _client.get(
        '/stores/owner/me',
        authenticated: true,
      );
      return _storeFromBackend(Map<String, dynamic>.from(payload as Map));
    } catch (_) {
      return null;
    }
  }

  Future<Store> saveStore(Store store) async {
      final body = {
        'name': store.name,
        'description': store.description,
        'logoUrl': store.logoUrl.isNotEmpty ? store.logoUrl : store.imageUrl,
        'isActive': store.isActive,
        'vendorType': store.vendorType,
        'address': store.address,
        'city': store.city,
        'latitude': store.latitude,
        'longitude': store.longitude,
        'tagline': store.tagline,
        'bannerImageUrl': store.bannerImageUrl,
        'category': store.category,
        'customVendorProfile': store.customVendorProfile.toMap(),
      };
    final payload = store.id.isEmpty
        ? await _client.post('/stores', authenticated: true, body: body)
        : await _client.put(
            '/stores/${store.id}',
            authenticated: true,
            body: body,
          );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return _storeFromBackend(map);
  }

  Future<void> syncUserProfile(AppUser user) async {
    try {
      await _client.withRetry(
        () => _client.post(
          '/auth/sync-profile',
          authenticated: true,
          body: {
            'name': user.name,
            'email': user.email,
            'phone': user.phone ?? '',
            'profileImageUrl': user.profileImageUrl ?? '',
            'address': user.address ?? '',
            'area': user.area ?? '',
            'city': user.city ?? '',
            'latitude': user.latitude,
            'longitude': user.longitude,
            'deliveryRadiusKm': user.deliveryRadiusKm,
            'locationUpdatedAt': user.locationUpdatedAt ?? '',
            'role': user.role,
            'isActive': user.isActive,
            'storeId': user.storeId ?? '',
            'walletBalance': user.walletBalance,
            'roles': user.roles,
            'riderApprovalStatus': user.riderApprovalStatus,
            'riderVehicleType': user.riderVehicleType ?? '',
            'riderLicenseNumber': user.riderLicenseNumber ?? '',
            'riderCity': user.riderCity ?? '',
          },
        ),
      );
    } on BackendApiException catch (error) {
      if (error.statusCode == 404) {
        debugPrint(
          'sync-profile endpoint unavailable on this backend. Continuing without sync.',
        );
        return;
      }
      if (_isTransientNetworkIssue(error)) {
        debugPrint('sync-profile skipped due to transient network issue: $error');
        return;
      }
      rethrow;
    } catch (error) {
      if (_isTransientNetworkIssue(error)) {
        debugPrint('sync-profile skipped due to transient network issue: $error');
        return;
      }
      rethrow;
    }
  }

  AppUser _appUserFromBackend(Map<String, dynamic> map) {
    return AppUser.fromMap({
      'id': map['firebaseUid'] ?? map['uid'] ?? map['id'],
      'name': map['name'] ?? 'ABZORA Member',
      'email': map['email'] ?? '',
      'profileImageUrl': map['profileImageUrl'],
      'phone': map['phone'] ?? '',
      'phone_number': map['phone'] ?? '',
      'address': map['address'],
      'area': map['area'],
      'city': map['city'],
      'latitude': map['latitude'],
      'longitude': map['longitude'],
      'deliveryRadiusKm': map['deliveryRadiusKm'] ?? 10,
      'locationUpdatedAt': map['locationUpdatedAt'],
      'created_at': map['createdAt'],
      'role': map['role'] ?? 'user',
      'isActive': map['isActive'] ?? true,
      'storeId': map['storeId'],
      'walletBalance': map['walletBalance'] ?? 0,
      'referralCode': map['referralCode'] ?? '',
      'referredBy': map['referredBy'] ?? '',
      'roles': map['roles'] ?? const {},
      'riderApprovalStatus': map['riderApprovalStatus'] ?? 'pending',
      'riderVehicleType': map['riderVehicleType'],
      'riderLicenseNumber': map['riderLicenseNumber'],
      'riderCity': map['riderCity'],
    });
  }

  Future<Product> createProduct(Product product) async {
    final payload = await _client.post(
      '/products',
      authenticated: true,
      body: _productPayload(product, includeStoreId: true),
    );
    return _productFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<Product> updateProduct(Product product) async {
    final payload = await _client.put(
      '/products/${product.id}',
      authenticated: true,
      body: _productPayload(product, includeStoreId: false),
    );
    return _productFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<void> deleteProduct(String productId) async {
    await _client.delete('/products/$productId', authenticated: true);
  }

  Future<Product> generateProductArAsset(
    String productId, {
    String? category,
    String? imageUrl,
    String? transparentImageUrl,
  }) async {
    await _client.post(
      '/products/$productId/ar-asset/generate',
      authenticated: true,
      body: {
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'imageUrl': imageUrl.trim(),
        if (transparentImageUrl != null &&
            transparentImageUrl.trim().isNotEmpty)
          'transparentImageUrl': transparentImageUrl.trim(),
      },
    );
    final payload = await _client.get(
      '/products/$productId',
      authenticated: true,
    );
    return _productFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<ArTryOnProductMetadata> getTryOnProductMetadata(
    String productId,
  ) async {
    final payload = await _client.get('/ar/product/$productId');
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return ArTryOnProductMetadata.fromMap(map);
  }

  Future<String> saveTryOnSession(ArTryOnSessionPayload session) async {
    final payload = await _client.post(
      '/ar/tryon/session',
      authenticated: true,
      body: session.toMap(),
    );
    final map = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
    return map['sessionId']?.toString() ?? session.sessionId;
  }

  Future<List<OrderModel>> getStoreOrders(String storeId) async {
    final payload = await _client.get(
      '/orders/store/$storeId',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OrderModel>> getAvailableDeliveries() async {
    final payload = await _client.get(
      '/orders/deliveries/available',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OrderModel>> getAssignedDeliveries() async {
    final payload = await _client.get(
      '/orders/deliveries/assigned',
      authenticated: true,
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<OrderModel> acceptDelivery(String orderId) async {
    final payload = await _client.post(
      '/orders/$orderId/accept-delivery',
      authenticated: true,
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> updateDeliveryStatus(
    String orderId,
    String deliveryStatus,
  ) async {
    final payload = await _client.patch(
      '/orders/$orderId/delivery-status',
      authenticated: true,
      body: {'deliveryStatus': deliveryStatus},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> postTrackingLocationUpdate({
    required String orderId,
    String? taskId,
    required double latitude,
    required double longitude,
    String? riderId,
    double? speedKmph,
    double? heading,
  }) async {
    final payload = await _client.post(
      '/tracking/location-update',
      authenticated: true,
      body: {
        'orderId': orderId,
        if (taskId != null && taskId.trim().isNotEmpty) 'taskId': taskId.trim(),
        if (riderId != null && riderId.trim().isNotEmpty) 'riderId': riderId.trim(),
        'latitude': latitude,
        'longitude': longitude,
        ..._optionalEntry('speedKmph', speedKmph),
        ..._optionalEntry('heading', heading),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<OrderModel> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    String? taskId,
    String? riderId,
    double? speedKmph,
    double? heading,
  }) async {
    await postTrackingLocationUpdate(
      orderId: orderId,
      taskId: taskId,
      latitude: latitude,
      longitude: longitude,
      riderId: riderId,
      speedKmph: speedKmph,
      heading: heading,
    );
    final payload = await _client.patch(
      '/orders/$orderId/rider-location',
      authenticated: true,
      body: {'latitude': latitude, 'longitude': longitude},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<void> postTrackingOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _client.post(
      '/tracking/order-status-update',
      authenticated: true,
      body: {
        'orderId': orderId,
        'status': status,
      },
    );
  }

  Future<Map<String, dynamic>> getTrackingEta(String orderId) async {
    final payload = await _client.get('/tracking/eta/$orderId', authenticated: true);
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> assignRiderTask({
    required String taskType,
    String? orderId,
    String? trialSessionId,
    String? riderId,
    double? dropLat,
    double? dropLng,
    String? city,
    bool? sameDay,
  }) async {
    final payload = await _client.post(
      '/assign-rider',
      authenticated: true,
      body: {
        'taskType': taskType,
        if (orderId != null && orderId.trim().isNotEmpty) 'orderId': orderId.trim(),
        if (trialSessionId != null && trialSessionId.trim().isNotEmpty)
          'trialSessionId': trialSessionId.trim(),
        if (riderId != null && riderId.trim().isNotEmpty) 'riderId': riderId.trim(),
        ..._optionalEntry('dropLat', dropLat),
        ..._optionalEntry('dropLng', dropLng),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        ..._optionalEntry('sameDay', sameDay),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<List<UnifiedRiderTask>> getRiderLogisticsTasks({String? status}) async {
    final payload = await _client.get(
      '/rider/tasks',
      authenticated: true,
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _riderTaskFromLogisticsMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<UnifiedRiderTask>> getRiderActiveLogisticsTasks() async {
    final payload = await _client.get('/rider/tasks/active', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _riderTaskFromLogisticsMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<UnifiedRiderTask> updateRiderLogisticsTaskStatus({
    required String taskId,
    required String status,
    String? otp,
    String? proofPhotoUrl,
    String? proofNote,
  }) async {
    final payload = await _client.patch(
      '/rider/tasks/$taskId/status',
      authenticated: true,
      body: {
        'status': status,
        if (otp != null && otp.trim().isNotEmpty) 'otp': otp.trim(),
        if (proofPhotoUrl != null && proofPhotoUrl.trim().isNotEmpty)
          'proofPhotoUrl': proofPhotoUrl.trim(),
        if (proofNote != null && proofNote.trim().isNotEmpty) 'proofNote': proofNote.trim(),
      },
    );
    return _riderTaskFromLogisticsMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<List<OrderModel>> getVendorOperationsOrders({
    String? status,
    String? storeId,
  }) async {
    final payload = await _client.get(
      '/vendor/ops/orders',
      authenticated: true,
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (storeId != null && storeId.trim().isNotEmpty) 'storeId': storeId.trim(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<OrderModel> updateVendorOperationsOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final payload = await _client.patch(
      '/vendor/ops/orders/$orderId/status',
      authenticated: true,
      body: {'status': status},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<List<TrialSession>> getVendorOperationsTrialRequests({
    String? status,
    String? approvalStatus,
  }) async {
    final payload = await _client.get(
      '/vendor/ops/trial-requests',
      authenticated: true,
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (approvalStatus != null && approvalStatus.trim().isNotEmpty)
          'approvalStatus': approvalStatus.trim(),
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => TrialSession.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<TrialSession> updateVendorOperationsTrialStatus({
    required String sessionId,
    required String status,
    String? note,
    List<String>? keptItems,
    List<String>? returnedItems,
  }) async {
    final payload = await _client.patch(
      '/vendor/ops/trial-requests/$sessionId/status',
      authenticated: true,
      body: {
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        ..._optionalEntry('keptItems', keptItems),
        ..._optionalEntry('returnedItems', returnedItems),
      },
    );
    return TrialSession.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> getLogisticsOperationsAnalytics() async {
    final payload = await _client.get('/analytics/ops', authenticated: true);
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<OrderModel> updateOrderStatus(String orderId, String status) async {
    final payload = await _client.patch(
      '/orders/$orderId/status',
      authenticated: true,
      body: {'status': status},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> updateCustomVendorOrderStatus(
    String orderId,
    String status, {
    String? vendorFinalImageUrl,
    bool? measurementsConfirmedByVendor,
    String? qualityApprovalStatus,
    String? alterationStatus,
  }
  ) async {
    final body = <String, dynamic>{'status': status};
    if (vendorFinalImageUrl?.isNotEmpty == true) {
      body['vendorFinalImageUrl'] = vendorFinalImageUrl!;
    }
    if (measurementsConfirmedByVendor != null) {
      body['measurementsConfirmedByVendor'] = measurementsConfirmedByVendor;
    }
    if (qualityApprovalStatus?.isNotEmpty == true) {
      body['qualityApprovalStatus'] = qualityApprovalStatus!;
    }
    if (alterationStatus?.isNotEmpty == true) {
      body['alterationStatus'] = alterationStatus!;
    }
    final payload = await _client.patch(
      '/vendor/custom/orders/$orderId/status',
      authenticated: true,
      body: body,
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<CustomVendorQualityState> getCustomVendorQuality() async {
    final payload = await _client.get(
      '/vendor/custom/quality',
      authenticated: true,
    );
    return CustomVendorQualityState.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CustomVendorTrainingProgress> completeCustomVendorTrainingModule({
    required String moduleKey,
    double score = 100,
  }) async {
    final payload = await _client.post(
      '/vendor/custom/training/modules/$moduleKey/complete',
      authenticated: true,
      body: {'score': score},
    );
    return CustomVendorTrainingProgress.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<CustomVendorSampleReview> submitCustomVendorSampleReview({
    required List<String> sampleImages,
    String notes = '',
  }) async {
    final payload = await _client.post(
      '/vendor/custom/sample-review',
      authenticated: true,
      body: {
        'sampleImages': sampleImages,
        'notes': notes,
      },
    );
    return CustomVendorSampleReview.fromMap(
      Map<String, dynamic>.from(payload as Map),
    );
  }

  Future<OrderModel> submitCustomFitFeedback({
    required String orderId,
    required double fitRating,
    required double qualityRating,
    required double deliveryRating,
    String notes = '',
    bool needsAlteration = false,
  }) async {
    final payload = await _client.post(
      '/orders/$orderId/custom-fit-feedback',
      authenticated: true,
      body: {
        'fitRating': fitRating,
        'qualityRating': qualityRating,
        'deliveryRating': deliveryRating,
        'notes': notes,
        'needsAlteration': needsAlteration,
      },
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> requestCustomAlteration({
    required String orderId,
    String notes = '',
  }) async {
    final payload = await _client.post(
      '/orders/$orderId/custom-alteration',
      authenticated: true,
      body: {'notes': notes},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> cancelOrder(String orderId) async {
    final payload = await _client.post(
      '/orders/$orderId/cancel',
      authenticated: true,
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<RefundRequest?> getRefundRequestForOrder(String orderId) async {
    final payload = await _client.get(
      '/orders/$orderId/refund-request',
      authenticated: true,
    );
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final id = map['id']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return RefundRequest.fromMap(map, id);
  }

  Future<List<RefundRequest>> getRefundRequests({String status = 'all'}) async {
    final payload = await _client.get(
      '/orders/refund-requests',
      authenticated: true,
      queryParameters: {'status': status},
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return RefundRequest.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<RefundRequest> createRefundRequest({
    required String orderId,
    required String reason,
  }) async {
    final payload = await _client.post(
      '/orders/$orderId/refund-request',
      authenticated: true,
      body: {'reason': reason},
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return RefundRequest.fromMap(map, map['id']?.toString() ?? '');
  }

  Future<RefundRequest> approveRefundRequest(String refundId) async {
    final payload = await _client.post(
      '/orders/refund-requests/$refundId/approve',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return RefundRequest.fromMap(map, map['id']?.toString() ?? refundId);
  }

  Future<RefundRequest> rejectRefundRequest({
    required String refundId,
    required String reason,
  }) async {
    final payload = await _client.post(
      '/orders/refund-requests/$refundId/reject',
      authenticated: true,
      body: {'reason': reason},
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return RefundRequest.fromMap(map, map['id']?.toString() ?? refundId);
  }

  Future<ReturnRequest?> getReturnRequestForOrder(String orderId) async {
    final payload = await _client.get(
      '/orders/$orderId/return-request',
      authenticated: true,
    );
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    final id = map['id']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return ReturnRequest.fromMap(map, id);
  }

  Future<List<ReturnRequest>> getReturnRequests({String status = 'all'}) async {
    final payload = await _client.get(
      '/orders/return-requests',
      authenticated: true,
      queryParameters: {'status': status},
    );
    final items = payload is List ? payload : const [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return ReturnRequest.fromMap(map, map['id']?.toString() ?? '');
    }).toList();
  }

  Future<ReturnRequest> createReturnRequest({
    required String orderId,
    required String reason,
    String imageUrl = '',
  }) async {
    final payload = await _client.post(
      '/orders/$orderId/return-request',
      authenticated: true,
      body: {
        'reason': reason,
        if (imageUrl.trim().isNotEmpty) 'imageUrl': imageUrl.trim(),
      },
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReturnRequest.fromMap(map, map['id']?.toString() ?? '');
  }

  Future<ReturnRequest> approveReturnRequest(String returnId) async {
    final payload = await _client.post(
      '/orders/return-requests/$returnId/approve',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReturnRequest.fromMap(map, map['id']?.toString() ?? returnId);
  }

  Future<ReturnRequest> rejectReturnRequest({
    required String returnId,
    required String reason,
  }) async {
    final payload = await _client.post(
      '/orders/return-requests/$returnId/reject',
      authenticated: true,
      body: {'reason': reason},
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReturnRequest.fromMap(map, map['id']?.toString() ?? returnId);
  }

  Future<ReturnRequest> markReturnPicked(String returnId) async {
    final payload = await _client.post(
      '/orders/return-requests/$returnId/picked',
      authenticated: true,
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReturnRequest.fromMap(map, map['id']?.toString() ?? returnId);
  }

  Future<ReturnRequest> completeReturnRequest({
    required String returnId,
    bool qualityApproved = true,
    String rejectionReason = '',
  }) async {
    final payload = await _client.post(
      '/orders/return-requests/$returnId/complete',
      authenticated: true,
      body: {
        'qualityApproved': qualityApproved,
        if (rejectionReason.trim().isNotEmpty)
          'rejectionReason': rejectionReason.trim(),
      },
    );
    final map = Map<String, dynamic>.from(payload as Map);
    return ReturnRequest.fromMap(map, map['id']?.toString() ?? returnId);
  }

  Future<OrderModel> createOrder({
    required List<OrderItem> items,
    required String paymentMethod,
    required String shippingLabel,
    required String shippingAddress,
  }) async {
    final payload = await _client.post(
      '/orders',
      authenticated: true,
      body: {
        'paymentMethod': paymentMethod.toUpperCase() == 'COD'
            ? 'COD'
            : 'RAZORPAY',
        'shippingAddress': _shippingAddressPayload(
          shippingLabel,
          shippingAddress,
        ),
        'items': items
            .map(
              (item) => {
                'productId': item.productId,
                'quantity': item.quantity,
                'size': item.size,
              },
            )
            .toList(),
      },
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> getCtaDecision({
    required String productId,
    String userId = '',
    int? fitConfidence,
    double? returnHistory,
    String userType = '',
    String productType = '',
    String locationSpeed = '',
  }) async {
    final payload = await _client.get(
      '/cta-decision/$productId',
      queryParameters: {
        if (userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (fitConfidence != null) 'fitConfidence': fitConfidence.toString(),
        if (returnHistory != null) 'returnHistory': returnHistory.toStringAsFixed(2),
        if (userType.trim().isNotEmpty) 'userType': userType.trim(),
        if (productType.trim().isNotEmpty) 'productType': productType.trim(),
        if (locationSpeed.trim().isNotEmpty) 'locationSpeed': locationSpeed.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getExperienceConfig({
    required String productId,
    String userId = '',
    int? fitConfidence,
    double? returnRate,
    int? sessionDepth,
    double? productFitRisk,
    bool? sameDayAvailable,
    String userType = '',
    String sessionId = '',
  }) async {
    final payload = await _client.get(
      '/experience-config/$productId',
      queryParameters: {
        if (userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (fitConfidence != null) 'fitConfidence': fitConfidence.toString(),
        if (returnRate != null) 'returnRate': returnRate.toStringAsFixed(2),
        if (sessionDepth != null) 'sessionDepth': sessionDepth.toString(),
        if (productFitRisk != null) 'productFitRisk': productFitRisk.toStringAsFixed(4),
        if (sameDayAvailable != null) 'sameDayAvailable': sameDayAvailable.toString(),
        if (userType.trim().isNotEmpty) 'userType': userType.trim(),
        if (sessionId.trim().isNotEmpty) 'sessionId': sessionId.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<Map<String, dynamic>> getMlDecision({
    required int fitConfidence,
    required double returnRate,
    required int sessionDepth,
    required bool sameDayAvailable,
    required double productFitRisk,
    required String userType,
    String userId = '',
    String productId = '',
  }) async {
    final payload = await _client.get(
      '/ml/decision',
      queryParameters: {
        'fitConfidence': fitConfidence.toString(),
        'returnRate': returnRate.toStringAsFixed(2),
        'sessionDepth': sessionDepth.toString(),
        'sameDayAvailable': sameDayAvailable.toString(),
        'productFitRisk': productFitRisk.toStringAsFixed(4),
        'userType': userType,
        if (userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (productId.trim().isNotEmpty) 'productId': productId.trim(),
      },
    );
    return Map<String, dynamic>.from(payload as Map);
  }

  Future<void> postMlReward({
    required String action,
    required double reward,
    String decisionId = '',
    Map<String, dynamic> features = const <String, dynamic>{},
    bool exploration = false,
  }) async {
    await _client.post(
      '/ml/reward',
      body: {
        'action': action,
        'reward': reward,
        if (decisionId.trim().isNotEmpty) 'decisionId': decisionId.trim(),
        if (features.isNotEmpty) 'features': features,
        'exploration': exploration,
      },
    );
  }

  Future<void> trackAnalyticsEvent({
    required String eventType,
    String userId = '',
    String sessionId = '',
    String productId = '',
    String decisionId = '',
    String cta = '',
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    await _client.post(
      '/analytics/event',
      body: {
        'eventType': eventType,
        if (userId.trim().isNotEmpty) 'userId': userId.trim(),
        if (sessionId.trim().isNotEmpty) 'sessionId': sessionId.trim(),
        if (productId.trim().isNotEmpty) 'productId': productId.trim(),
        if (decisionId.trim().isNotEmpty) 'decisionId': decisionId.trim(),
        if (cta.trim().isNotEmpty) 'cta': cta.trim(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<OrderModel> quickCheckoutOrder({
    required String productId,
    String size = '',
    int quantity = 1,
    String paymentMethod = 'COD',
    Map<String, String> shippingAddress = const {},
  }) async {
    final payload = await _client.post(
      '/orders/quick-checkout',
      authenticated: true,
      body: {
        'productId': productId,
        'size': size,
        'quantity': quantity,
        'paymentMethod': paymentMethod.toUpperCase() == 'COD' ? 'COD' : 'RAZORPAY',
        'shippingAddress': {
          'name': shippingAddress['name'] ?? '',
          'phone': shippingAddress['phone'] ?? '',
          'addressLine1': shippingAddress['addressLine1'] ?? '',
          'addressLine2': shippingAddress['addressLine2'] ?? '',
          'city': shippingAddress['city'] ?? '',
          'state': shippingAddress['state'] ?? '',
          'pincode': shippingAddress['pincode'] ?? '',
        },
      },
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Map<String, dynamic> _productPayload(
    Product product, {
    required bool includeStoreId,
  }) {
    return {
      if (includeStoreId) 'storeId': product.storeId,
      'name': product.name,
      'brand': product.brand,
      'price': product.price,
      'description': product.description,
      'stock': product.stock,
      'category': product.category,
      'subcategory': product.subcategory,
      'images': product.images,
      'model3d': product.model3d,
      'unityAssetBundleUrl': product.unityAssetBundleUrl,
      'rigProfile': product.rigProfile,
      'materialProfile': product.materialProfile,
      'attributes': product.attributes,
      'arAsset': product.arAsset,
      if (product.arAsset.isNotEmpty) 'disableArAssetGeneration': true,
      'isActive': product.isActive,
    };
  }

  Map<String, String> _shippingAddressPayload(
    String label,
    String fullAddress,
  ) {
    final parts = fullAddress
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return {
      'name': label,
      'phone': '',
      'addressLine1': parts.isNotEmpty ? parts.first : fullAddress.trim(),
      'addressLine2': parts.length > 1 ? parts.sublist(1).join(', ') : '',
      'city': '',
      'state': '',
      'pincode': '',
    };
  }

  Store _storeFromBackend(Map<String, dynamic> map) {
    return Store.fromMap({
      'id': map['id'],
      'store_id': map['id'],
      'ownerId': map['ownerId'],
      'name': map['name'],
      'description': map['description'] ?? '',
      'imageUrl': map['logoUrl'] ?? '',
      'logoUrl': map['logoUrl'] ?? '',
      'bannerImageUrl': map['bannerImageUrl'] ?? '',
      'rating': map['rating'] ?? 0,
      'reviewCount': map['reviewCount'] ?? 0,
      'address': map['address'] ?? '',
      'city': map['city'] ?? '',
      'isApproved': map['isApproved'] ?? true,
      'isActive': map['isActive'] ?? true,
      'isFeatured': map['isFeatured'] ?? false,
      'approvalStatus': map['approvalStatus'] ?? 'approved',
        'tagline': map['tagline'] ?? '',
        'commissionRate': map['commissionRate'] ?? 0.12,
        'walletBalance': map['walletBalance'] ?? 0,
        'latitude': map['latitude'],
        'longitude': map['longitude'],
        'category': map['category'] ?? '',
        'vendorType': map['vendorType'] ?? 'standard_vendor',
        'customVendorProfile': map['customVendorProfile'] ?? const {},
        'vendorScore': map['vendorScore'] ?? 0,
        'vendorRank': map['vendorRank'] ?? 0,
        'vendorVisibility': map['vendorVisibility'] ?? 'normal',
        'vendorHighlights': map['vendorHighlights'] ?? const <String>[],
      'performanceMetrics': map['performanceMetrics'] ?? const {},
    }, map['id']?.toString() ?? '');
  }

  Product _productFromBackend(Map<String, dynamic> map) {
    final resolvedBrand =
        <String?>[map['brand']?.toString(), map['brandName']?.toString()]
            .map((value) => value?.trim() ?? '')
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return Product.fromMap({
      'storeId': map['storeId'],
      'name': map['name'],
      'brand': resolvedBrand,
      'brandName': map['brandName'],
      'storeName': map['storeName'],
      'description': map['description'] ?? '',
      'price': map['price'] ?? 0,
      'basePrice': map['basePrice'] ?? map['price'],
      'dynamicPrice': map['dynamicPrice'],
      'originalPrice': map['originalPrice'],
      'demandScore': map['demandScore'] ?? 0,
      'viewCount': map['viewCount'] ?? 0,
      'cartCount': map['cartCount'] ?? 0,
      'purchaseCount': map['purchaseCount'] ?? 0,
      'images': map['images'] ?? const [],
      'model3d': map['model3d'],
      'unityAssetBundleUrl': map['unityAssetBundleUrl'],
      'rigProfile': map['rigProfile'],
      'materialProfile': map['materialProfile'],
      'sizes': map['sizes'] ?? const ['S', 'M', 'L'],
      'stock': map['stock'] ?? 0,
      'category': map['category'] ?? '',
      'subcategory': map['subcategory'] ?? '',
      'isActive': map['isActive'] ?? true,
      'createdAt': map['createdAt'],
      'rating': map['rating'] ?? 0,
      'reviewCount': map['reviewCount'] ?? 0,
      'lastPriceUpdated': map['updatedAt'],
      'isCustomTailoring': map['isCustomTailoring'] ?? false,
      'outfitType': map['outfitType'],
      'fabric': map['fabric'],
      'attributes': map['attributes'] ?? const {},
      'arAsset': map['arAsset'] ?? const {},
      'customizations': map['customizations'] ?? const {},
      'measurements': map['measurements'] ?? const {},
      'addons': map['addons'] ?? const [],
      'measurementProfileLabel': map['measurementProfileLabel'],
      'neededBy': map['neededBy'],
      'tailoringDeliveryMode': map['tailoringDeliveryMode'],
      'tailoringExtraCost': map['tailoringExtraCost'] ?? 0,
    }, map['id']?.toString() ?? '');
  }

  OrderModel _orderFromBackend(Map<String, dynamic> map) {
    final shipping = Map<String, dynamic>.from(
      map['shippingAddress'] ?? const {},
    );
    final items = (map['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final shippingParts = <String>[
      shipping['addressLine1']?.toString() ?? '',
      shipping['addressLine2']?.toString() ?? '',
      shipping['city']?.toString() ?? '',
      shipping['state']?.toString() ?? '',
      shipping['pincode']?.toString() ?? '',
    ]..removeWhere((part) => part.trim().isEmpty);

    return OrderModel.fromMap({
      'userId': map['userId'] ?? '',
      'storeId': map['storeId'] ?? '',
      'riderId': (map['riderId']?.toString().trim().isEmpty ?? true)
          ? null
          : map['riderId'],
      'totalAmount': map['totalAmount'] ?? 0,
      'status': _frontendOrderStatus(
        map['orderStatus']?.toString(),
        map['paymentStatus']?.toString(),
      ),
      'paymentMethod': map['paymentMethod'] ?? 'COD',
      'timestamp': map['createdAt'] ?? DateTime.now().toIso8601String(),
      'items': items
          .map(
            (item) => {
              'productId': item['productId']?.toString() ?? '',
              'productName': item['name'] ?? '',
              'quantity': item['quantity'] ?? 1,
              'price': item['price'] ?? 0,
              'size': item['size'] ?? '',
              'imageUrl': item['image'] ?? '',
            },
          )
          .toList(),
      'shippingLabel': shipping['name'] ?? '',
      'shippingAddress': shippingParts.join(', '),
      'extraCharges': 0,
      'subtotal':
          map['subtotalAmount'] ??
          map['productAmount'] ??
          map['totalAmount'] ??
          0,
      'taxAmount': map['taxAmount'] ?? 0,
      'platformCommission': map['platformCommission'] ?? 0,
      'vendorEarnings': map['vendorEarnings'] ?? 0,
      'payoutStatus': map['payoutStatus'] ?? 'Pending',
      'trackingId': map['trackingId'] ?? map['razorpay']?['orderId'] ?? '',
      'deliveryStatus': _frontendDeliveryStatus(
        map['deliveryStatus']?.toString(),
        map['orderStatus']?.toString(),
      ),
      'assignedDeliveryPartner': map['assignedDeliveryPartner'] ?? 'Unassigned',
      'invoiceNumber': map['id'] ?? '',
        'orderType': map['fulfillmentType'] == 'custom_tailoring'
            ? 'custom_tailoring'
            : 'marketplace',
        'fulfillmentType': map['fulfillmentType'] ?? 'marketplace',
        'customOrderStatus': map['customOrderStatus'] ?? 'none',
        'customMeasurements': map['customMeasurements'] ?? const {},
        'customDesignOptions': map['customDesignOptions'] ?? const {},
        'referenceImageUrl': map['referenceImageUrl'] ?? '',
        'previewImageUrl': map['previewImageUrl'] ?? '',
        'vendorFinalImageUrl': map['vendorFinalImageUrl'] ?? '',
        'selectedDesignerName': map['selectedDesignerName'] ?? '',
        'qualityApprovalStatus': map['qualityApprovalStatus'] ?? 'not_required',
        'measurementsConfirmedByVendor':
            map['measurementsConfirmedByVendor'] ?? false,
        'preDispatchChecklistCompletedAt':
            map['preDispatchChecklistCompletedAt'] ?? '',
        'customerFitFeedbackStatus':
            map['customerFitFeedbackStatus'] ?? 'pending',
        'customerFitRating': map['customerFitRating'] ?? 0,
        'customerQualityRating': map['customerQualityRating'] ?? 0,
        'customerDeliveryRating': map['customerDeliveryRating'] ?? 0,
        'customerFitFeedbackNotes': map['customerFitFeedbackNotes'] ?? '',
        'customerFitRespondedAt': map['customerFitRespondedAt'] ?? '',
        'alterationStatus': map['alterationStatus'] ?? 'none',
        'alterationRequestedAt': map['alterationRequestedAt'] ?? '',
        'alterationResolvedAt': map['alterationResolvedAt'] ?? '',
        'alterationNotes': map['alterationNotes'] ?? '',
        'customProductionTimeDays': map['customProductionTimeDays'] ?? 0,
        'customizationSummary': map['customizationSummary'] ?? '',
        'trackingTimestamps': Map<String, String>.from(
        (map['trackingTimestamps'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        ),
      ),
      'riderLatitude': map['riderLatitude'],
      'riderLongitude': map['riderLongitude'],
      'riderLocationUpdatedAt': map['riderLocationUpdatedAt'],
      'createdAt': map['createdAt'],
      'updatedAt': map['updatedAt'],
      'deliveredAt': (map['trackingTimestamps'] as Map?)?['Delivered'],
      'isConfirmed': (map['orderStatus']?.toString() ?? '') == 'confirmed',
      'isDelivered': (map['orderStatus']?.toString() ?? '') == 'delivered',
      'payoutProcessed': map['payoutProcessed'] ?? false,
      'paymentReference':
          map['razorpay']?['paymentId'] ?? map['razorpay']?['orderId'],
      'isPaymentVerified': (map['paymentStatus']?.toString() ?? '') == 'paid',
      'refundStatus': map['refundStatus'] ?? 'none',
      'returnStatus': map['returnStatus'] ?? 'none',
      'walletCreditUsed': 0,
    }, map['id']?.toString() ?? '');
  }

  String _frontendOrderStatus(String? backendStatus, String? paymentStatus) {
    switch ((backendStatus ?? '').toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return (paymentStatus ?? '').toLowerCase() == 'paid'
            ? 'Confirmed'
            : 'Placed';
    }
  }

  String _frontendDeliveryStatus(
    String? backendDeliveryStatus,
    String? backendOrderStatus,
  ) {
    switch ((backendDeliveryStatus ?? '').toLowerCase()) {
      case 'assigned':
        return 'Assigned';
      case 'ready for pickup':
        return 'Ready for pickup';
      case 'picked up':
        return 'Picked up';
      case 'out for delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
    }
    switch ((backendOrderStatus ?? '').toLowerCase()) {
      case 'shipped':
        return 'Picked Up';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'confirmed':
      case 'processing':
        return 'Pending';
      default:
        return 'Pending';
    }
  }

  UnifiedRiderTask _riderTaskFromLogisticsMap(Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString().toLowerCase().trim() ?? '';
    final normalizedStatus = switch (rawStatus) {
      'assigned' => 'assigned',
      'accepted' => 'assigned',
      'picked_up' => 'in_progress',
      'out_for_delivery' => 'in_progress',
      'delivered' => 'completed',
      'cancelled' => 'completed',
      _ => rawStatus.isEmpty ? 'assigned' : rawStatus,
    };
    final rawType = map['taskType']?.toString().toUpperCase().trim() ?? '';
    final taskType = rawType == 'TRIAL_PICKUP'
        ? 'return'
        : rawType == 'TRIAL_DELIVERY'
            ? 'trial_delivery'
            : 'delivery';
    return UnifiedRiderTask(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      type: taskType,
      orderId: map['orderId']?.toString().trim().isEmpty == true
          ? null
          : map['orderId']?.toString(),
      returnId: map['trialSessionId']?.toString().trim().isEmpty == true
          ? null
          : map['trialSessionId']?.toString(),
      userId: map['userId']?.toString() ?? '',
      address: map['dropAddress']?.toString().trim().isNotEmpty == true
          ? map['dropAddress'].toString()
          : (map['pickupAddress']?.toString() ?? ''),
      status: normalizedStatus,
      riderId: map['riderId']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString() ?? map['createdAt']?.toString() ?? '',
    );
  }

  SupportChat _supportChatFromBackend(Map<String, dynamic> map) {
    return SupportChat.fromMap({
      'userId': map['userId'] ?? '',
      'type': map['type'] ?? 'general',
      'status': map['status'] ?? 'open',
      'createdAt': map['createdAt'] ?? '',
      'updatedAt': map['updatedAt'] ?? '',
      'lastMessage': map['lastMessage'] ?? '',
      'lastMessageAt': map['lastMessageAt'] ?? '',
      'lastSenderId': map['lastSenderId'] ?? '',
      'lastSenderRole': map['lastSenderRole'] ?? '',
      'userName': map['userName'] ?? '',
      'userPhone': map['userPhone'] ?? '',
      'ticketId': map['ticketId'] ?? '',
      'orderId': map['orderId'],
      'unreadCountUser': map['unreadCountUser'] ?? 0,
      'unreadCountAdmin': map['unreadCountAdmin'] ?? 0,
      'participantIds': map['participantIds'] ?? const {},
    }, map['id']?.toString() ?? '');
  }

  SupportMessage _supportMessageFromBackend(Map<String, dynamic> map) {
    return SupportMessage.fromMap({
      'senderId': map['senderId'] ?? '',
      'senderRole': map['senderRole'] ?? 'user',
      'text': map['text'] ?? '',
      'imageUrl': map['imageUrl'] ?? '',
      'timestamp': map['timestamp'] ?? '',
      'read': map['read'] ?? false,
    }, map['id']?.toString() ?? '');
  }

  VendorKycRequest _vendorKycRequestFromBackend(Map<String, dynamic> map) {
    return VendorKycRequest.fromMap({
      'userId': map['userId'] ?? '',
      'storeName': map['storeName'] ?? '',
      'ownerName': map['ownerName'] ?? '',
      'phone': map['phone'] ?? '',
      'address': map['address'] ?? '',
      'city': map['city'] ?? '',
      'latitude': map['latitude'] ?? 0,
      'longitude': map['longitude'] ?? 0,
      'kyc': map['kyc'] ?? const {},
      'status': map['status'] ?? 'pending',
      'createdAt': map['createdAt'] ?? '',
      'updatedAt': map['updatedAt'] ?? '',
      'rejectionReason': map['rejectionReason'] ?? '',
      'reviewedBy': map['reviewedBy'] ?? '',
      'reviewedByName': map['reviewedByName'] ?? '',
      'reviewedAt': map['reviewedAt'] ?? '',
      'actionHistory': map['actionHistory'] ?? const [],
      'verification': map['verification'] ?? const {},
    }, map['id']?.toString() ?? '');
  }

  RiderKycRequest _riderKycRequestFromBackend(Map<String, dynamic> map) {
    return RiderKycRequest.fromMap({
      'userId': map['userId'] ?? '',
      'name': map['name'] ?? '',
      'phone': map['phone'] ?? '',
      'vehicle': map['vehicle'] ?? '',
      'city': map['city'] ?? '',
      'kyc': map['kyc'] ?? const {},
      'status': map['status'] ?? 'pending',
      'createdAt': map['createdAt'] ?? '',
      'updatedAt': map['updatedAt'] ?? '',
      'rejectionReason': map['rejectionReason'] ?? '',
      'reviewedBy': map['reviewedBy'] ?? '',
      'reviewedByName': map['reviewedByName'] ?? '',
      'reviewedAt': map['reviewedAt'] ?? '',
      'actionHistory': map['actionHistory'] ?? const [],
    }, map['id']?.toString() ?? '');
  }
}
