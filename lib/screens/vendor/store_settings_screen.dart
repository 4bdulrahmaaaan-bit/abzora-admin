import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/image_url_service.dart';
import '../../services/storage_service.dart';
import '../../core/vendor/theme/vendor_theme.dart';
import '../../core/vendor/widgets/premium_vendor_card.dart';
import '../../core/vendor/widgets/vendor_buttons.dart';
import '../../core/vendor/widgets/vendor_status_badge.dart';
import '../../utils/app_error_text.dart';
import '../../features/legal/account_deletion_request_screen.dart';
import '../../features/legal/legal_policy_hub_screen.dart';
import '../../features/legal/legal_document_registry.dart';
import '../../features/onboarding/vendor_onboarding_flow_screen.dart';
import '../../widgets/payout_account_dialog.dart';

class StoreSettingsScreen extends StatefulWidget {
  final Store store;

  const StoreSettingsScreen({super.key, required this.store});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _taglineController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _logoController;
  late final TextEditingController _bannerController;
  bool _saving = false;
  final _picker = ImagePicker();
  PayoutProfileSummary? _payoutProfile;
  bool _payoutFetched = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _taglineController = TextEditingController(text: widget.store.tagline);
    _addressController = TextEditingController(text: widget.store.address);
    _descriptionController = TextEditingController(
      text: widget.store.description,
    );
    _logoController = TextEditingController(text: widget.store.logoUrl);
    _bannerController = TextEditingController(
      text: widget.store.bannerImageUrl,
    );

    _nameController.addListener(_updateCompletion);
    _taglineController.addListener(_updateCompletion);
    _addressController.addListener(_updateCompletion);
    _descriptionController.addListener(_updateCompletion);
    _logoController.addListener(_updateCompletion);
    _bannerController.addListener(_updateCompletion);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_payoutFetched) {
      _payoutFetched = true;
      final actor = context.read<AuthProvider>().user;
      if (actor != null) {
        DatabaseService()
            .getVendorPayoutProfile(actor: actor)
            .then((profile) {
          if (mounted) setState(() => _payoutProfile = profile);
        }).catchError((_) {});
      }
    }
  }

  void _updateCompletion() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _logoController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  int get _completionPercentage {
    int score = 0;
    if (_nameController.text.trim().isNotEmpty) score += 20;
    if (_taglineController.text.trim().isNotEmpty) score += 10;
    if (_descriptionController.text.trim().isNotEmpty) score += 20;
    if (_addressController.text.trim().isNotEmpty) score += 20;
    if (_logoController.text.trim().isNotEmpty) score += 15;
    if (_bannerController.text.trim().isNotEmpty) score += 15;
    return score;
  }

  Future<void> _save() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store name and address are required.')),
      );
      return;
    }

    setState(() => _saving = true);
    await DatabaseService().saveStore(
      Store(
        id: widget.store.id,
        ownerId: widget.store.ownerId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _logoController.text.trim().isEmpty
            ? ImageUrlService.optimizeForDelivery(widget.store.imageUrl)
            : ImageUrlService.optimizeForDelivery(_logoController.text.trim()),
        rating: widget.store.rating,
        reviewCount: widget.store.reviewCount,
        address: _addressController.text.trim(),
        isApproved: widget.store.isApproved,
        isActive: widget.store.isActive,
        isFeatured: widget.store.isFeatured,
        logoUrl: ImageUrlService.optimizeForDelivery(
          _logoController.text.trim(),
        ),
        bannerImageUrl: ImageUrlService.optimizeForDelivery(
          _bannerController.text.trim(),
        ),
        tagline: _taglineController.text.trim(),
        commissionRate: widget.store.commissionRate,
        walletBalance: widget.store.walletBalance,
      ),
      actor: actor,
    );

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Store branding updated.')));
    Navigator.pop(context, true);
  }

  Future<void> _pickAndUploadImage({required bool isLogo}) async {
    try {
      final actor = context.read<AuthProvider>().user;
      if (actor == null) {
        return;
      }
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (file == null) {
        return;
      }
      setState(() => _saving = true);
      final url = await StorageService().uploadPickedImage(
        file: file,
        folder: isLogo ? 'store_logos' : 'store_banners',
        ownerId: actor.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (isLogo) {
          _logoController.text = url;
        } else {
          _bannerController.text = url;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLogo
                ? 'Logo uploaded successfully.'
                : 'Banner uploaded successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppErrorText.from(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openVendorOnboarding(int initialStep) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorOnboardingFlowScreen(initialStep: initialStep),
      ),
    );
  }

  Future<void> _managePayoutAccount() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    final formValue = await showPayoutAccountDialog(
      context: context,
      title: 'Vendor payout account',
      initialValue: _payoutProfile ?? const PayoutProfileSummary.empty(),
    );
    if (formValue == null || !mounted) {
      return;
    }
    try {
      final updatedProfile = await DatabaseService().saveVendorPayoutProfile(
        actor: actor,
        methodType: formValue.methodType,
        accountHolderName: formValue.accountHolderName,
        upiId: formValue.upiId,
        bankAccountNumber: formValue.bankAccountNumber,
        bankIfsc: formValue.bankIfsc,
        bankName: formValue.bankName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _payoutProfile = updatedProfile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout details saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorText.from(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VendorTheme.background,
      appBar: AppBar(
        title: Text(
          'Store Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VendorTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompletionCard(),
            const SizedBox(height: VendorTheme.spacing24),
            _buildSectionHeader('Store Identity', Icons.storefront_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTextField('Store Name', _nameController, 'Required'),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTextField(
              'Tagline',
              _taglineController,
              'e.g. Wedding edits and elevated essentials',
            ),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTextField(
              'Description',
              _descriptionController,
              'Describe your store...',
              maxLines: 4,
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Location', Icons.location_on_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildTextField('Store Address', _addressController, 'Required'),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Visual Branding', Icons.image_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildImageField('Logo URL', _logoController, true),
            const SizedBox(height: VendorTheme.spacing24),
            _buildImageField('Banner URL', _bannerController, false),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Business Information', Icons.business_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'GSTIN & PAN Details',
              subtitle: 'Manage tax compliance and verification',
              onTap: () => _openVendorOnboarding(4),
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildLegalListTile(
              title: 'Business Type',
              subtitle: 'Sole Proprietorship, LLP, Pvt Ltd, etc.',
              onTap: () => _openVendorOnboarding(0),
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Financial Settings', Icons.account_balance_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'Bank Account Details',
              subtitle: _payoutProfile != null && _payoutProfile!.isConfigured && _payoutProfile!.bankAccountNumber.length >= 4
                  ? '${_payoutProfile!.bankName} **** ${_payoutProfile!.bankAccountNumber.substring(_payoutProfile!.bankAccountNumber.length - 4)}'
                  : 'Not configured',
              onTap: _managePayoutAccount,
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildLegalListTile(
              title: 'Payout Preferences',
              subtitle: _payoutProfile != null && _payoutProfile!.isConfigured
                  ? _payoutProfile!.methodType
                  : 'Not set',
              onTap: _managePayoutAccount,
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Notifications', Icons.notifications_active_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'Notification Preferences',
              subtitle: 'Orders, Returns, Finance, Reviews alerts',
              onTap: () {},
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Security & Access', Icons.security_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'Device Sessions',
              subtitle: 'Manage logged-in devices',
              onTap: () {},
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildLegalListTile(
              title: 'Selfie Verification',
              subtitle: 'Verified Identity',
              onTap: () {},
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Store Controls', Icons.power_settings_new_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'Vacation Mode',
              subtitle: 'Temporarily hide store from customers',
              onTap: () {},
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildLegalListTile(
              title: 'Auto-Reject Orders',
              subtitle: 'Automatically reject when inventory is 0',
              onTap: () {},
            ),
            const SizedBox(height: VendorTheme.spacing32),
            _buildSectionHeader('Legal & Settings', Icons.gavel_outlined),
            const SizedBox(height: VendorTheme.spacing16),
            _buildLegalListTile(
              title: 'Legal & Policies',
              subtitle: 'Terms, privacy, and agreements',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalPolicyHubScreen(
                    audience: LegalAudience.vendor,
                    title: 'Vendor Legal Center',
                  ),
                ),
              ),
            ),
            const SizedBox(height: VendorTheme.spacing12),
            _buildLegalListTile(
              title: 'Request Account Deletion',
              subtitle: 'Email support for account deletion request',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AccountDeletionRequestScreen(roleLabel: 'Vendor'),
                ),
              ),
            ),
            const SizedBox(height: VendorTheme.spacing32),
            SizedBox(
              width: double.infinity,
              child: VendorPrimaryButton(
                label: 'SAVE STORE SETTINGS',
                onTap: _saving ? null : _save,
                isLoading: _saving,
              ),
            ),
            const SizedBox(height: VendorTheme.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    final int score = _completionPercentage;
    return PremiumVendorCard(
      padding: const EdgeInsets.all(VendorTheme.spacing20),
      backgroundColor: VendorTheme.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Store Completion',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              VendorStatusBadge(
                label: '$score%',
                type: score == 100
                    ? VendorBadgeType.success
                    : VendorBadgeType.warning,
              ),
            ],
          ),
          const SizedBox(height: VendorTheme.spacing16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: VendorTheme.grey200,
              valueColor: AlwaysStoppedAnimation<Color>(
                score == 100 ? VendorTheme.success : VendorTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: VendorTheme.spacing12),
          Text(
            score == 100
                ? 'Your store is fully optimized and ready to convert.'
                : 'Complete your store profile to increase buyer trust and conversion.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: VendorTheme.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: VendorTheme.primary),
        const SizedBox(width: VendorTheme.spacing8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: VendorTheme.grey500,
          ),
        ),
        const SizedBox(height: VendorTheme.spacing8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VendorTheme.spacing16,
              vertical: VendorTheme.spacing16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
              borderSide: const BorderSide(color: VendorTheme.grey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
              borderSide: const BorderSide(color: VendorTheme.grey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
              borderSide: const BorderSide(color: VendorTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageField(
    String label,
    TextEditingController controller,
    bool isLogo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _buildTextField(label, controller, 'https://...')),
            const SizedBox(width: VendorTheme.spacing12),
            VendorOutlinedButton(
              label: 'UPLOAD',
              onTap: _saving ? null : () => _pickAndUploadImage(isLogo: isLogo),
              icon: Icons.cloud_upload_outlined,
            ),
          ],
        ),
        const SizedBox(height: VendorTheme.spacing8),
        if (controller.text.trim().isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(VendorTheme.radiusMedium),
            child: Image.network(
              controller.text.trim(),
              height: isLogo ? 80 : 120,
              width: isLogo ? 80 : double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: isLogo ? 80 : 120,
                width: isLogo ? 80 : double.infinity,
                color: VendorTheme.grey200,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: VendorTheme.grey400,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegalListTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return PremiumVendorCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VendorTheme.spacing16,
          vertical: VendorTheme.spacing8,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right, color: VendorTheme.grey400),
      ),
    );
  }
}
