import '../models/banner_model.dart';
import '../models/category_management_model.dart';
import '../models/models.dart';
import 'backend_api_client.dart';

class BackendCommerceService {
  BackendCommerceService({BackendApiClient? client}) : _client = client ?? const BackendApiClient();

  final BackendApiClient _client;

  bool get isConfigured => _client.isConfigured;

  Future<AppUser> getCurrentUserProfile() async {
    final payload = await _client.get('/auth/me', authenticated: true);
    final map = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
    return _appUserFromBackend(map);
  }

  Future<AppUser> saveTestUserPhone(String phone) async {
    final payload = await _client.post(
      '/auth/test-user',
      body: {'phone': phone},
    );
    final map =
        payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
    return _appUserFromBackend(map);
  }

  Future<List<UserAddress>> getUserAddresses() async {
    final payload = await _client.get('/auth/addresses', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return UserAddress.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
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

  Future<BodyProfile> saveBodyProfile(BodyProfile profile) async {
    final payload = await _client.put(
      '/auth/memory',
      authenticated: true,
      body: {
        ...profile.toMap(),
        'size': profile.recommendedSize,
      },
    );
    return BodyProfile.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<Map<String, dynamic>> recommendSize({
    required double heightCm,
    required double weightKg,
    required String bodyType,
    String? productFit,
  }) async {
    final payload = await _client.post(
      '/ai/recommend-size',
      authenticated: true,
      body: {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'bodyType': bodyType,
        if (productFit != null && productFit.trim().isNotEmpty)
          'productFit': productFit.trim(),
      },
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

  Future<List<BannerModel>> getBanners({bool includeInactive = false}) async {
    final payload = await _client.get('/banners', authenticated: includeInactive);
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

  Future<List<CategoryManagementModel>> getAdminCategories() async {
    final payload = await _client.get('/api/categories', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) =>
            CategoryManagementModel.fromMap(Map<String, dynamic>.from(item)))
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

  Future<List<ReviewModel>> getProductReviews(String productId) async {
    final payload = await _client.get('/reviews/products/$productId');
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ReviewModel.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
  }

  Future<List<ReviewModel>> getStoreReviews(String storeId) async {
    final payload = await _client.get('/reviews/stores/$storeId');
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ReviewModel.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
  }

  Future<ReviewModel> saveReview(ReviewModel review) async {
    final payload = await _client.post(
      '/reviews',
      authenticated: true,
      body: {
        'id': review.id,
        ...review.toMap(),
      },
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
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return BookingModel.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
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
      final payload = await _client.get('/support/chats/$chatId', authenticated: true);
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
        if (beforeTimestamp != null && beforeTimestamp.isNotEmpty) 'before': beforeTimestamp,
      },
    );
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _supportMessageFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SupportChat> createSupportChat(String issueType) async {
    final payload = await _client.post(
      '/support/chats',
      authenticated: true,
      body: {
        'issueType': issueType,
      },
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
        if (assistantReplyText != null && assistantReplyText.isNotEmpty) 'assistantReplyText': assistantReplyText,
        if (assistantTimestamp != null && assistantTimestamp.isNotEmpty) 'assistantTimestamp': assistantTimestamp,
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
    final map = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
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
      body: {
        ...entry.toMap(),
        'date': date,
      },
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
        .map((item) => AiUsageLogEntry.fromMap(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
        .toList();
  }

  Future<List<AiDailyStat>> getAiDailyStats() async {
    final payload = await _client.get('/ai/usage/daily', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => AiDailyStat.fromMap(Map<String, dynamic>.from(item), item['date']?.toString() ?? ''))
        .toList();
  }

  Future<List<UserAiUsageStat>> getUserAiUsageStats() async {
    final payload = await _client.get('/ai/usage/users', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => UserAiUsageStat.fromMap(Map<String, dynamic>.from(item), item['userId']?.toString() ?? ''))
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
    await _client.post(
      '/ai/events',
      authenticated: true,
      body: body,
    );
  }

  Future<AdminAnalytics> getAdminDashboard() async {
    final payload = await _client.get('/admin/dashboard', authenticated: true);
    final map =
        payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
    final topStores = ((map['topStores'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          return Store.fromMap(
            {
              'id': data['id'],
              'store_id': data['id'],
              'name': data['name'] ?? '',
              'logoUrl': data['logoUrl'] ?? '',
              'imageUrl': data['logoUrl'] ?? '',
              'rating': data['rating'] ?? 0,
            },
            data['id']?.toString() ?? '',
          );
        })
        .toList();

    return AdminAnalytics(
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      platformCommissionRevenue:
          (map['platformCommissionRevenue'] ?? 0).toDouble(),
      totalOrders: ((map['totalOrders'] ?? 0) as num).toInt(),
      topStores: topStores,
      dailySales: const [],
      weeklySales: const [],
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

  Future<PlatformSettings> savePlatformSettings(PlatformSettings settings) async {
    final payload = await _client.put(
      '/admin/settings',
      authenticated: true,
      body: settings.toMap(),
    );
    return PlatformSettings.fromMap(Map<String, dynamic>.from(payload as Map));
  }

  Future<List<AppNotification>> getAdminNotifications() async {
    final payload = await _client.get('/admin/notifications', authenticated: true);
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
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return PayoutModel.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
  }

  Future<PayoutModel?> processAdminPayout({
    required String storeId,
    required String periodLabel,
  }) async {
    final payload = await _client.post(
      '/admin/payouts/process',
      authenticated: true,
      body: {
        'storeId': storeId,
        'periodLabel': periodLabel,
      },
    );
    if (payload == null) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload as Map);
    return PayoutModel.fromMap(map, map['id']?.toString() ?? '');
  }

  Future<List<DisputeRecord>> getAdminDisputes() async {
    final payload = await _client.get('/admin/disputes', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return DisputeRecord.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
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
    final payload = await _client.get('/admin/activity-logs', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ActivityLogEntry.fromMap(map, map['id']?.toString() ?? '');
        })
        .toList();
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

  Future<List<VendorKycRequest>> getVendorKycRequests({
    String? status,
  }) async {
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
        .map((item) => _vendorKycRequestFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<RiderKycRequest>> getRiderKycRequests({
    String? status,
  }) async {
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
        .map((item) => _riderKycRequestFromBackend(Map<String, dynamic>.from(item)))
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

  Future<VendorKycRequest> submitVendorKycRequest(VendorKycRequest request) async {
    final payload = await _client.post(
      '/kyc/vendor',
      authenticated: true,
      body: request.toMap(),
    );
    final map = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
    return _vendorKycRequestFromBackend(map);
  }

  Future<RiderKycRequest> submitRiderKycRequest(RiderKycRequest request) async {
    final payload = await _client.post(
      '/kyc/rider',
      authenticated: true,
      body: request.toMap(),
    );
    final map = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
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
      body: {
        'status': status,
        'reason': reason,
      },
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
      body: {
        'status': status,
        'reason': reason,
      },
    );
  }

  Future<Store?> getOwnStore() async {
    try {
      final payload = await _client.get('/stores/owner/me', authenticated: true);
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
    };
    final payload = store.id.isEmpty
        ? await _client.post('/stores', authenticated: true, body: body)
        : await _client.put('/stores/${store.id}', authenticated: true, body: body);
    final map = payload is Map<String, dynamic> ? payload : Map<String, dynamic>.from(payload as Map);
    return _storeFromBackend(map);
  }

  Future<void> syncUserProfile(AppUser user) async {
    await _client.post(
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
    );
  }

  AppUser _appUserFromBackend(Map<String, dynamic> map) {
    return AppUser.fromMap(
      {
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
        'roles': map['roles'] ?? const {},
        'riderApprovalStatus': map['riderApprovalStatus'] ?? 'pending',
        'riderVehicleType': map['riderVehicleType'],
        'riderLicenseNumber': map['riderLicenseNumber'],
        'riderCity': map['riderCity'],
      },
    );
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

  Future<List<OrderModel>> getStoreOrders(String storeId) async {
    final payload = await _client.get('/orders/store/$storeId', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OrderModel>> getAvailableDeliveries() async {
    final payload = await _client.get('/orders/deliveries/available', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OrderModel>> getAssignedDeliveries() async {
    final payload = await _client.get('/orders/deliveries/assigned', authenticated: true);
    final items = payload is List ? payload : const [];
    return items
        .whereType<Map>()
        .map((item) => _orderFromBackend(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<OrderModel> acceptDelivery(String orderId) async {
    final payload = await _client.post('/orders/$orderId/accept-delivery', authenticated: true);
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> updateDeliveryStatus(String orderId, String deliveryStatus) async {
    final payload = await _client.patch(
      '/orders/$orderId/delivery-status',
      authenticated: true,
      body: {'deliveryStatus': deliveryStatus},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> updateRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    final payload = await _client.patch(
      '/orders/$orderId/rider-location',
      authenticated: true,
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Future<OrderModel> updateOrderStatus(String orderId, String status) async {
    final payload = await _client.patch(
      '/orders/$orderId/status',
      authenticated: true,
      body: {'status': status},
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
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
        'paymentMethod': paymentMethod.toUpperCase() == 'COD' ? 'COD' : 'RAZORPAY',
        'shippingAddress': _shippingAddressPayload(shippingLabel, shippingAddress),
        'items': items
            .map(
              (item) => {
                'productId': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
      },
    );
    return _orderFromBackend(Map<String, dynamic>.from(payload as Map));
  }

  Map<String, dynamic> _productPayload(Product product, {required bool includeStoreId}) {
    return {
      if (includeStoreId) 'storeId': product.storeId,
      'name': product.name,
      'price': product.price,
      'description': product.description,
      'stock': product.stock,
      'category': product.category,
      'images': product.images,
      'isActive': product.isActive,
    };
  }

  Map<String, String> _shippingAddressPayload(String label, String fullAddress) {
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
    return Store.fromMap(
      {
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
        'vendorScore': map['vendorScore'] ?? 0,
        'vendorRank': map['vendorRank'] ?? 0,
        'vendorVisibility': map['vendorVisibility'] ?? 'normal',
        'performanceMetrics': map['performanceMetrics'] ?? const {},
      },
      map['id']?.toString() ?? '',
    );
  }

  Product _productFromBackend(Map<String, dynamic> map) {
    return Product.fromMap(
      {
        'storeId': map['storeId'],
        'name': map['name'],
        'brand': map['brand'] ?? '',
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
        'sizes': map['sizes'] ?? const ['S', 'M', 'L'],
        'stock': map['stock'] ?? 0,
        'category': map['category'] ?? '',
        'isActive': map['isActive'] ?? true,
        'createdAt': map['createdAt'],
        'rating': map['rating'] ?? 0,
        'reviewCount': map['reviewCount'] ?? 0,
        'lastPriceUpdated': map['updatedAt'],
        'isCustomTailoring': map['isCustomTailoring'] ?? false,
        'outfitType': map['outfitType'],
        'fabric': map['fabric'],
        'customizations': map['customizations'] ?? const {},
        'measurements': map['measurements'] ?? const {},
        'addons': map['addons'] ?? const [],
        'measurementProfileLabel': map['measurementProfileLabel'],
        'neededBy': map['neededBy'],
        'tailoringDeliveryMode': map['tailoringDeliveryMode'],
        'tailoringExtraCost': map['tailoringExtraCost'] ?? 0,
      },
      map['id']?.toString() ?? '',
    );
  }

  OrderModel _orderFromBackend(Map<String, dynamic> map) {
    final shipping = Map<String, dynamic>.from(map['shippingAddress'] ?? const {});
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

    return OrderModel.fromMap(
      {
        'userId': map['userId'] ?? '',
        'storeId': map['storeId'] ?? '',
        'riderId': (map['riderId']?.toString().trim().isEmpty ?? true) ? null : map['riderId'],
        'totalAmount': map['totalAmount'] ?? 0,
        'status': _frontendOrderStatus(map['orderStatus']?.toString(), map['paymentStatus']?.toString()),
        'paymentMethod': map['paymentMethod'] ?? 'COD',
        'timestamp': map['createdAt'] ?? DateTime.now().toIso8601String(),
        'items': items
            .map(
              (item) => {
                'productId': item['productId']?.toString() ?? '',
                'productName': item['name'] ?? '',
                'quantity': item['quantity'] ?? 1,
                'price': item['price'] ?? 0,
                'size': '',
                'imageUrl': item['image'] ?? '',
              },
            )
            .toList(),
        'shippingLabel': shipping['name'] ?? '',
        'shippingAddress': shippingParts.join(', '),
        'extraCharges': 0,
        'subtotal': map['subtotalAmount'] ?? map['totalAmount'] ?? 0,
        'taxAmount': 0,
        'platformCommission': 0,
        'vendorEarnings': 0,
        'payoutStatus': 'Pending',
        'trackingId': map['razorpay']?['orderId'] ?? '',
        'deliveryStatus': _frontendDeliveryStatus(
          map['deliveryStatus']?.toString(),
          map['orderStatus']?.toString(),
        ),
        'assignedDeliveryPartner': map['assignedDeliveryPartner'] ?? 'Unassigned',
        'invoiceNumber': map['id'] ?? '',
        'orderType': 'marketplace',
        'trackingTimestamps': const <String, String>{},
        'riderLatitude': map['riderLatitude'],
        'riderLongitude': map['riderLongitude'],
        'riderLocationUpdatedAt': map['riderLocationUpdatedAt'],
        'createdAt': map['createdAt'],
        'updatedAt': map['updatedAt'],
        'isConfirmed': (map['orderStatus']?.toString() ?? '') == 'confirmed',
        'isDelivered': (map['orderStatus']?.toString() ?? '') == 'delivered',
        'paymentReference': map['razorpay']?['paymentId'] ?? map['razorpay']?['orderId'],
        'isPaymentVerified': (map['paymentStatus']?.toString() ?? '') == 'paid',
        'refundStatus': '',
        'returnStatus': '',
        'walletCreditUsed': 0,
      },
      map['id']?.toString() ?? '',
    );
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
        return (paymentStatus ?? '').toLowerCase() == 'paid' ? 'Confirmed' : 'Placed';
    }
  }

  String _frontendDeliveryStatus(String? backendDeliveryStatus, String? backendOrderStatus) {
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

  SupportChat _supportChatFromBackend(Map<String, dynamic> map) {
    return SupportChat.fromMap(
      {
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
      },
      map['id']?.toString() ?? '',
    );
  }

  SupportMessage _supportMessageFromBackend(Map<String, dynamic> map) {
    return SupportMessage.fromMap(
      {
        'senderId': map['senderId'] ?? '',
        'senderRole': map['senderRole'] ?? 'user',
        'text': map['text'] ?? '',
        'imageUrl': map['imageUrl'] ?? '',
        'timestamp': map['timestamp'] ?? '',
        'read': map['read'] ?? false,
      },
      map['id']?.toString() ?? '',
    );
  }

  VendorKycRequest _vendorKycRequestFromBackend(Map<String, dynamic> map) {
    return VendorKycRequest.fromMap(
      {
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
      },
      map['id']?.toString() ?? '',
    );
  }

  RiderKycRequest _riderKycRequestFromBackend(Map<String, dynamic> map) {
    return RiderKycRequest.fromMap(
      {
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
      },
      map['id']?.toString() ?? '',
    );
  }
}
