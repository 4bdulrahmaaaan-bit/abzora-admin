import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/payment_service.dart';
import '../../theme.dart';
import '../../widgets/address_card.dart';
import '../../widgets/payment_selector.dart';
import 'address_screen.dart';

class AiStylistQuickCheckoutScreen extends StatefulWidget {
  const AiStylistQuickCheckoutScreen({
    super.key,
    required this.product,
    required this.recommendedSize,
  });

  final Product product;
  final String recommendedSize;

  @override
  State<AiStylistQuickCheckoutScreen> createState() => _AiStylistQuickCheckoutScreenState();
}

class _AiStylistQuickCheckoutScreenState extends State<AiStylistQuickCheckoutScreen> {
  final DatabaseService _database = DatabaseService();

  bool _loading = true;
  bool _processing = false;
  String? _paymentMethod = 'COD';
  UserAddress? _selectedAddress;
  List<UserAddress> _savedAddresses = const [];
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _buildIdempotencyKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadCheckoutContext();
    });
  }

  String _buildIdempotencyKey() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ai-buy-$millis-$random';
  }

  Future<void> _loadCheckoutContext() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final results = await Future.wait([
        _database.getUserAddresses(user.id),
        _database.getPreferredPaymentMethod(user.id),
      ]);
      final addresses = results[0] as List<UserAddress>;
      final preferredPayment = results[1] as String?;
      final fallbackAddress = _fallbackAddressFromUser(user);
      final allAddresses = [
        ...addresses,
        if (fallbackAddress != null && !addresses.any((item) => _sameAddress(item, fallbackAddress))) fallbackAddress,
      ];
      if (!mounted) {
        return;
      }
      setState(() {
        _savedAddresses = allAddresses;
        _selectedAddress = allAddresses.isEmpty ? fallbackAddress : allAddresses.first;
        _paymentMethod = (preferredPayment == null || preferredPayment.isEmpty) ? 'COD' : preferredPayment;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAddress = _fallbackAddressFromUser(user);
        _paymentMethod = 'COD';
        _loading = false;
      });
    }
  }

  bool _sameAddress(UserAddress left, UserAddress right) {
    return left.name == right.name &&
        left.phone == right.phone &&
        left.addressLine == right.addressLine &&
        left.city == right.city &&
        left.pincode == right.pincode;
  }

  UserAddress? _fallbackAddressFromUser(AppUser user) {
    if ((user.address ?? '').trim().isEmpty) {
      return null;
    }
    return UserAddress(
      id: 'profile-address',
      userId: user.id,
      name: user.name.trim().isEmpty ? 'ABZORA Member' : user.name.trim(),
      phone: user.phone ?? '',
      addressLine: user.address!.trim(),
      city: user.city ?? '',
      state: '',
      pincode: _extractPincode(user.address ?? ''),
      locality: user.area ?? '',
      latitude: user.latitude,
      longitude: user.longitude,
      type: 'home',
      createdAt: user.locationUpdatedAt ?? user.createdAt ?? DateTime.now().toIso8601String(),
    );
  }

  String _extractPincode(String address) {
    final match = RegExp(r'\b\d{6}\b').firstMatch(address);
    return match?.group(0) ?? '';
  }

  String _composeFullAddress(UserAddress address) {
    return [
      if (address.houseDetails.trim().isNotEmpty) address.houseDetails.trim(),
      if (address.addressLine.trim().isNotEmpty) address.addressLine.trim(),
      if (address.landmark.trim().isNotEmpty) address.landmark.trim(),
      if (address.locality.trim().isNotEmpty) address.locality.trim(),
      if (address.city.trim().isNotEmpty) address.city.trim(),
      if (address.state.trim().isNotEmpty) address.state.trim(),
      if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
    ].join(', ');
  }

  Future<void> _showAddressPicker() async {
    final selected = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery address', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                if (_savedAddresses.isEmpty)
                  Text(
                    'No saved address yet. Add one to continue.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ..._savedAddresses.map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(address),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _selectedAddress?.id == address.id ? AbzioTheme.accentColor : context.abzioBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(address.name, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      _composeFullAddress(address),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.abzioSecondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _selectedAddress?.id == address.id ? Icons.check_circle_rounded : Icons.circle_outlined,
                                color: _selectedAddress?.id == address.id ? AbzioTheme.accentColor : context.abzioSecondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop('add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add address'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selected is UserAddress) {
      setState(() => _selectedAddress = selected);
      return;
    }
    if (selected == 'add') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddressScreen()),
      );
      if (!mounted) {
        return;
      }
      await _loadCheckoutContext();
    }
  }

  Future<void> _confirmOrder() async {
    if (_processing) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to continue.')),
      );
      return;
    }
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a delivery address to continue.')),
      );
      return;
    }
    if ((_paymentMethod ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a payment method to continue.')),
      );
      return;
    }

    setState(() => _processing = true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(_database.trackAiStylistConversion(
      user: user,
      product: widget.product,
      eventType: 'buy_now_tapped',
      recommendedSize: widget.recommendedSize,
    ));

    try {
      String? paymentReference;
      var paymentVerified = false;
      if (_paymentMethod == 'RAZORPAY') {
        final result = await PaymentService().processCheckout(
          context: context,
          userId: user.id,
          name: user.name.trim().isEmpty ? 'ABZORA Member' : user.name.trim(),
          amount: widget.product.effectivePrice,
          email: user.email.isEmpty ? 'guest@abzora.app' : user.email,
          contact: user.phone ?? _selectedAddress!.phone,
          description: 'AI stylist instant checkout',
        );
        if (!result.success) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Payment was not completed. Please try again.')),
            );
          }
          return;
        }
        paymentReference = result.paymentId ?? result.externalWallet ?? result.orderId;
        paymentVerified = result.isVerified;
      }

      final order = await _database.placeOrdersForCart(
        actor: user,
        items: [
          OrderItem(
            productId: widget.product.id,
            productName: widget.product.name,
            quantity: 1,
            price: widget.product.effectivePrice,
            size: widget.recommendedSize,
            imageUrl: widget.product.images.isNotEmpty ? widget.product.images.first : '',
          ),
        ],
        paymentMethod: _paymentMethod!,
        shippingLabel: _selectedAddress!.name,
        shippingAddress: _composeFullAddress(_selectedAddress!),
        extraCharges: 0,
        paymentReference: paymentReference,
        idempotencyKey: _idempotencyKey,
        isPaymentVerified: paymentVerified,
      );
      await _database.savePreferredPaymentMethod(user.id, _paymentMethod!);
      await _database.trackAiStylistConversion(
        user: user,
        product: widget.product,
        eventType: 'purchase_completed',
        recommendedSize: widget.recommendedSize,
        orderId: order.id,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(order);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message.isEmpty ? 'Order could not be placed right now.' : message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
    final imageUrl = widget.product.images.isNotEmpty ? widget.product.images.first : '';

    return AbzioThemeScope.light(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quick Checkout'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'One tap from stylist to order',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Review the essentials and confirm your order.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: context.abzioBorder),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 96,
                                      height: 120,
                                      child: imageUrl.isEmpty
                                          ? const ColoredBox(
                                              color: Color(0xFFF4F4F4),
                                              child: Icon(Icons.checkroom_rounded, color: AbzioTheme.accentColor, size: 34),
                                            )
                                          : Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                                                color: Color(0xFFF4F4F4),
                                                child: Icon(Icons.checkroom_rounded, color: AbzioTheme.accentColor, size: 34),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.product.category.toUpperCase(),
                                          style: Theme.of(context).textTheme.labelMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.product.name,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          currency.format(widget.product.effectivePrice),
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                color: AbzioTheme.accentColor,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7DE),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'AI size: ${widget.recommendedSize}',
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            AddressCard(
                              address: _selectedAddress,
                              onChange: _showAddressPicker,
                            ),
                            const SizedBox(height: 18),
                            PaymentSelector(
                              selectedMethod: _paymentMethod,
                              onChanged: (value) => setState(() => _paymentMethod = value),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.abzioBorder),
                              ),
                              child: Column(
                                children: [
                                  _line(context, 'Product total', currency.format(widget.product.effectivePrice)),
                                  const SizedBox(height: 10),
                                  _line(context, 'Delivery fee', 'Free'),
                                  const SizedBox(height: 10),
                                  _line(context, 'Selected size', widget.recommendedSize),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Divider(height: 1),
                                  ),
                                  _line(
                                    context,
                                    'Total',
                                    currency.format(widget.product.effectivePrice),
                                    strong: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _processing ? null : _confirmOrder,
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(58)),
                            child: _processing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : const Text('Confirm Order'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, {bool strong = false}) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
