import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/state_views.dart';

class AdminManagementScreen extends StatefulWidget {
  final int initialTab;

  const AdminManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _db = DatabaseService();
  final _locationService = LocationService();

  List<AppUser> _users = [];
  List<Store> _stores = [];
  List<Product> _products = [];
  List<OrderModel> _orders = [];
  bool _loading = true;

  AppUser? get _actor => context.read<AuthProvider>().user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _db.getUsers(actor: _actor),
      _db.getAdminStores(),
      _db.getAllProducts(actor: _actor),
      _db.getAllOrders(actor: _actor),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _users = results[0] as List<AppUser>;
      _stores = results[1] as List<Store>;
      _products = results[2] as List<Product>;
      _orders = results[3] as List<OrderModel>;
      _loading = false;
    });
  }

  Future<void> _saveUser(AppUser user) async {
    await _db.updateUser(user, actor: _actor);
    await _load();
  }

  Future<void> _saveStore(Store store) async {
    await _db.saveStore(store, actor: _actor);
    await _load();
  }

  Future<void> _toggleUserActive(AppUser user) async {
    await _saveUser(user.copyWith(isActive: !user.isActive));
  }

  Future<void> _changeUserRole(AppUser user, String role) async {
    await _saveUser(user.copyWith(role: role));
  }

  Future<void> _assignStoreToUser(AppUser user) async {
    String? selectedStoreId = user.storeId;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Link Store for ${user.name}'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedStoreId,
            decoration: const InputDecoration(labelText: 'Store'),
            items: _stores
                .map(
                  (store) => DropdownMenuItem<String>(
                    value: store.id,
                    child: Text('${store.name} (${store.id})'),
                  ),
                )
                .toList(),
            onChanged: (value) => setDialogState(() => selectedStoreId = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != true || selectedStoreId == null || selectedStoreId!.isEmpty) {
      return;
    }

    final store = _stores.cast<Store?>().firstWhere((item) => item?.id == selectedStoreId, orElse: () => null);
    if (store == null) {
      return;
    }

    await _saveStore(store.copyWith(ownerId: user.id));

    await _saveUser(user.copyWith(role: 'vendor', storeId: selectedStoreId));
  }

  Future<void> _createStoreForUser(AppUser user) async {
    final nameController = TextEditingController(text: user.name.isEmpty ? '' : '${user.name} Studio');
    final addressController = TextEditingController(text: user.address ?? '');
    final taglineController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create Store for ${user.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Store Name')),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextField(controller: taglineController, decoration: const InputDecoration(labelText: 'Tagline')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Create')),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty || addressController.text.trim().isEmpty) {
      return;
    }

    final geoResult = await _locationService.geocodeAddress(addressController.text.trim());
    if (geoResult.status != AddressLookupStatus.success || geoResult.latitude == null || geoResult.longitude == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not verify store address. Please add a clearer address with city details.'),
        ),
      );
      return;
    }
    final resolvedAddress = await _locationService.reverseGeocode(
      geoResult.latitude!,
      geoResult.longitude!,
    );

    final store = Store(
      id: '',
      ownerId: user.id,
      name: nameController.text.trim(),
      description: 'Pending vendor storefront for ${user.name}.',
      imageUrl: '',
      rating: 0,
      reviewCount: 0,
      address: addressController.text.trim(),
      city: resolvedAddress.city.isNotEmpty ? resolvedAddress.city : (user.city ?? ''),
      isApproved: false,
      isActive: false,
      isFeatured: false,
      approvalStatus: 'pending',
      tagline: taglineController.text.trim(),
      logoUrl: '',
      bannerImageUrl: '',
      commissionRate: 0.12,
      walletBalance: 0,
      latitude: geoResult.latitude,
      longitude: geoResult.longitude,
      category: 'Fashion',
    );

    await _db.saveStore(store, actor: _actor);
    final createdStore = await _db.getStoreByOwner(user.id);
    if (createdStore == null) {
      return;
    }

    await _saveUser(user.copyWith(role: 'vendor', storeId: createdStore.id));
  }

  Future<void> _toggleStoreApproval(Store store) async {
    final nextApproved = !store.isApproved;
    await _saveStore(
      store.copyWith(
        isApproved: nextApproved,
        approvalStatus: nextApproved ? 'approved' : 'pending',
      ),
    );
  }

  Future<void> _rejectStore(Store store) async {
    await _saveStore(
      store.copyWith(
        isApproved: false,
        isActive: false,
        approvalStatus: 'rejected',
      ),
    );
  }

  Future<void> _toggleStoreActive(Store store) async {
    await _saveStore(store.copyWith(isActive: !store.isActive));
  }

  Future<void> _toggleFeatured(Store store) async {
    await _saveStore(store.copyWith(isFeatured: !store.isFeatured));
  }

  Future<void> _adjustCommission(Store store) async {
    final controller = TextEditingController(text: (store.commissionRate * 100).toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Adjust Commission for ${store.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Commission %'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true) {
      return;
    }
    final value = (double.tryParse(controller.text.trim()) ?? (store.commissionRate * 100)) / 100;
    await _db.adjustStoreCommission(storeId: store.id, commissionRate: value.clamp(0, 1), actor: _actor!);
    await _load();
  }

  Future<void> _adjustWallet(Store store) async {
    final controller = TextEditingController(text: '0');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Adjust Earnings for ${store.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
          decoration: const InputDecoration(labelText: 'Adjustment amount (Rs)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apply')),
        ],
      ),
    );
    if (result != true) {
      return;
    }
    final value = double.tryParse(controller.text.trim()) ?? 0;
    await _db.adjustStoreWallet(storeId: store.id, delta: value, actor: _actor!);
    await _load();
  }

  Future<void> _editProduct(Product product) async {
    final stockController = TextEditingController(text: product.stock.toString());
    final priceController = TextEditingController(text: product.price.toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
            const SizedBox(height: 12),
            TextField(controller: stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true) {
      return;
    }

    await _db.updateProduct(
      Product(
        id: product.id,
        storeId: product.storeId,
        name: product.name,
        brand: product.brand,
        description: product.description,
        price: double.tryParse(priceController.text.trim()) ?? product.price,
        originalPrice: product.originalPrice,
        images: product.images,
        sizes: product.sizes,
        stock: int.tryParse(stockController.text.trim()) ?? product.stock,
        category: product.category,
        isActive: product.isActive,
        createdAt: product.createdAt,
        rating: product.rating,
        reviewCount: product.reviewCount,
        isCustomTailoring: product.isCustomTailoring,
        outfitType: product.outfitType,
        fabric: product.fabric,
        customizations: product.customizations,
        measurements: product.measurements,
        addons: product.addons,
        measurementProfileLabel: product.measurementProfileLabel,
        neededBy: product.neededBy,
        tailoringDeliveryMode: product.tailoringDeliveryMode,
        tailoringExtraCost: product.tailoringExtraCost,
      ),
      actor: _actor,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isSuperAdmin) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: AbzioEmptyCard(
              title: 'Restricted workspace',
              subtitle: 'This control center is reserved for platform administrators only.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SUPER ADMIN'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'USERS'),
            Tab(text: 'STORES'),
            Tab(text: 'PRODUCTS'),
            Tab(text: 'ORDERS'),
          ],
        ),
      ),
      body: _loading
          ? const AbzioLoadingView(
              title: 'Loading control center',
              subtitle: 'Refreshing users, stores, catalog, and orders.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const BrandLogo(
                          size: 52,
                          radius: 16,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTROL CENTER',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: AbzioTheme.accentColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Users, stores, catalog, and orders in one secure place.',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUsersTab(),
                        _buildStoresTab(),
                        _buildProductsTab(),
                        _buildOrdersTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUsersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AbzioTheme.grey100,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AbzioTheme.grey300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Firebase User Onboarding', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'New Firebase accounts start as users. From here you can promote them, create a pending store, or link an existing store without editing Firestore manually.',
                style: GoogleFonts.inter(color: AbzioTheme.grey600, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._users.map((user) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(user.email, style: GoogleFonts.inter(color: AbzioTheme.grey600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(user.role.toUpperCase())),
                        Chip(label: Text(user.isActive ? 'ACTIVE' : 'BLOCKED')),
                        if (user.storeId != null && user.storeId!.isNotEmpty) Chip(label: Text('STORE ${user.storeId}')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _toggleUserActive(user),
                          child: Text(user.isActive ? 'BLOCK USER' : 'RESTORE USER'),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (role) => _changeUserRole(user, role),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'user', child: Text('Set as User')),
                            PopupMenuItem(value: 'vendor', child: Text('Set as Vendor')),
                            PopupMenuItem(value: 'rider', child: Text('Set as Rider')),
                            PopupMenuItem(value: 'super_admin', child: Text('Set as Super Admin')),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text('CHANGE ROLE'),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _assignStoreToUser(user),
                          child: const Text('LINK STORE'),
                        ),
                        ElevatedButton(
                          onPressed: () => _createStoreForUser(user),
                          child: const Text('CREATE STORE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStoresTab() {
    final width = MediaQuery.of(context).size.width;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _stores.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final store = _stores[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(store.name),
            subtitle: Text(
              '${store.address}${store.city.isNotEmpty ? ', ${store.city}' : ''}\nOwner: ${store.ownerId}\nFeatured: ${store.isFeatured ? 'Yes' : 'No'}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.approvalStatus.toUpperCase(),
                  style: TextStyle(
                    color: store.approvalStatus == 'approved'
                        ? Colors.green
                        : store.approvalStatus == 'rejected'
                            ? Colors.red
                            : Colors.orange,
                    fontWeight: FontWeight.w700,
                    fontSize: width < 360 ? 10 : 11,
                  ),
                ),
                Text(
                  store.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(color: store.isActive ? Colors.blue : Colors.red, fontWeight: FontWeight.w700, fontSize: width < 360 ? 10 : 11),
                ),
              ],
            ),
            onTap: () async {
              await showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        title: Text(store.isApproved ? 'Move To Pending' : 'Approve Store'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _toggleStoreApproval(store);
                        },
                      ),
                      ListTile(
                        title: const Text('Reject Store'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _rejectStore(store);
                        },
                      ),
                      ListTile(
                        title: Text(store.isActive ? 'Deactivate Shop' : 'Activate Shop'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _toggleStoreActive(store);
                        },
                      ),
                      ListTile(
                        title: Text(store.isFeatured ? 'Remove Featured' : 'Mark Featured'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _toggleFeatured(store);
                        },
                      ),
                      ListTile(
                        title: const Text('Adjust Commission'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _adjustCommission(store);
                        },
                      ),
                      ListTile(
                        title: const Text('Adjust Earnings'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _adjustWallet(store);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductsTab() {
    final width = MediaQuery.of(context).size.width;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _products[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: ClipOval(
                child: AbzioNetworkImage(
                  imageUrl: product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/200',
                  fallbackLabel: product.name,
                ),
              ),
            ),
            title: Text(product.name),
            subtitle: Text('Rs ${product.price.toInt()} | Stock ${product.stock} | Store ${product.storeId}'),
            trailing: width < 380
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => _editProduct(product), icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                        onPressed: () async {
                          await _db.deleteProduct(product.id, actor: _actor);
                          await _load();
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    children: [
                      IconButton(onPressed: () => _editProduct(product), icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                        onPressed: () async {
                          await _db.deleteProduct(product.id, actor: _actor);
                          await _load();
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersTab() {
    const statuses = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ${order.id}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${order.items.length} item(s) | Rs ${order.totalAmount.toInt()} | Store ${order.storeId}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: statuses.contains(order.status) ? order.status : statuses.first,
                  items: statuses.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    await _db.updateOrderStatus(order.id, value, actor: _actor);
                    await _load();
                  },
                  decoration: const InputDecoration(labelText: 'Order Status'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
