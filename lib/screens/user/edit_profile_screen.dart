import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/tap_scale.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final trimmedName = _nameController.text.trim();
    final trimmedAddress = _addressController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _nameError = 'Name cannot be empty';
      });
      return;
    }
    setState(() {
      _nameError = null;
    });

    await auth.saveProfile(
      name: trimmedName,
      address: trimmedAddress,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1400,
    );
    if (picked == null) {
      return;
    }
    await auth.updateProfileImage(picked);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile image updated')),
    );
  }

  Future<void> _openImageActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final profileImageUrl = user?.profileImageUrl?.trim() ?? '';
    final hasLocation = _addressController.text.trim().isNotEmpty;

    return AbzioThemeScope.light(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBF5),
        appBar: AppBar(
          title: const Text('Edit Profile'),
        ),
        body: SafeArea(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFFFF8E5),
                          AbzioTheme.accentColor.withValues(alpha: 0.18),
                          const Color(0xFFFFFCF6),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -18,
                          right: -12,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AbzioTheme.accentColor.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -28,
                          left: -14,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFEFB),
                          Color(0xFFFFFBF1),
                          Color(0xFFFFF7EA),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.92, end: 1),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) =>
                              Transform.scale(scale: value, child: child),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AbzioTheme.accentColor.withValues(alpha: 0.28),
                                      AbzioTheme.accentColor.withValues(alpha: 0.08),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AbzioTheme.accentColor.withValues(alpha: 0.16),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: Colors.white,
                                  backgroundImage: profileImageUrl.isEmpty
                                      ? null
                                      : NetworkImage(profileImageUrl),
                                  child: profileImageUrl.isEmpty
                                      ? const BrandLogo(
                                          size: 92,
                                          radius: 52,
                                          padding: EdgeInsets.all(8),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: TapScale(
                                  onTap: auth.isUpdatingProfile ? null : _openImageActions,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AbzioTheme.accentColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AbzioTheme.accentColor.withValues(alpha: 0.28),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Your ABZORA profile',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Refine your details for smoother delivery, better recommendations, and a more personal luxury experience.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.abzioSecondaryText,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _statusChip(
                              context,
                              icon: Icons.verified_user_outlined,
                              label: 'Trusted account',
                            ),
                            _statusChip(
                              context,
                              icon: hasLocation
                                  ? Icons.location_on_outlined
                                  : Icons.location_searching_outlined,
                              label: hasLocation ? 'Location ready' : 'Add location',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sectionCard(
                    context,
                    title: 'Personal Details',
                    subtitle: 'Your identity and essential account information.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fieldLabel('FULL NAME'),
                        const SizedBox(height: 10),
                        _inputCard(
                          context,
                          focusNode: _nameFocusNode,
                          child: TextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() {
                                  _nameError = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Name',
                              hintText: 'ABZORA Member',
                              errorText: _nameError,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel('PHONE NUMBER'),
                        const SizedBox(height: 10),
                        _inputCard(
                          context,
                          child: TextField(
                            controller: _phoneController,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Phone number is verified through OTP and cannot be edited here.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.abzioSecondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionCard(
                    context,
                    title: 'Delivery Location',
                    subtitle: 'Use your live location for faster, more accurate delivery.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fieldLabel('LOCATION'),
                        const SizedBox(height: 10),
                        _inputCard(
                          context,
                          focusNode: _addressFocusNode,
                          child: TextField(
                            controller: _addressController,
                            focusNode: _addressFocusNode,
                            textInputAction: TextInputAction.done,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              hintText: 'Set your delivery location',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8EB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AbzioTheme.accentColor.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 18,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  hasLocation
                                      ? 'Current location captured and ready for premium delivery experiences.'
                                      : 'Use GPS once to auto-fill your address with minimal effort.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: context.abzioSecondaryText,
                                        height: 1.35,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: auth.isUpdatingProfile
                              ? null
                              : () async {
                                  await auth.fillAddressFromGps(
                                    fallbackName: _nameController.text.trim().isEmpty
                                        ? 'ABZORA Member'
                                        : _nameController.text.trim(),
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  final refreshed = auth.user;
                                  _addressController.text = refreshed?.address ?? '';
                                  _nameController.text =
                                      refreshed?.name ?? _nameController.text;
                                  setState(() {});
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Use Current Location'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TapScale(
                    onTap: auth.isUpdatingProfile ? null : _save,
                    child: ElevatedButton(
                      onPressed: auth.isUpdatingProfile ? null : _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFF3D47A),
                              AbzioTheme.accentColor,
                            ],
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minHeight: 58),
                          child: auth.isUpdatingProfile
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: auth.isUpdatingProfile
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.abzioSecondaryText,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _statusChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AbzioTheme.accentColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.black87,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AbzioTheme.accentColor,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _inputCard(
    BuildContext context, {
    FocusNode? focusNode,
    required Widget child,
  }) {
    final focused = focusNode?.hasFocus ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: focused ? AbzioTheme.accentColor : context.abzioBorder,
          width: focused ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (focused ? AbzioTheme.accentColor : Colors.black).withValues(
              alpha: focused ? 0.10 : 0.03,
            ),
            blurRadius: focused ? 18 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
