import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/image_url_service.dart';
import '../../services/storage_service.dart';
import '../../theme.dart';

class StoreSettingsScreen extends StatefulWidget {
  final Store store;

  const StoreSettingsScreen({
    super.key,
    required this.store,
  });

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _taglineController = TextEditingController(text: widget.store.tagline);
    _addressController = TextEditingController(text: widget.store.address);
    _descriptionController = TextEditingController(text: widget.store.description);
    _logoController = TextEditingController(text: widget.store.logoUrl);
    _bannerController = TextEditingController(text: widget.store.bannerImageUrl);
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

  Future<void> _save() async {
    final actor = context.read<AuthProvider>().user;
    if (actor == null) {
      return;
    }
    if (_nameController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
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
        logoUrl: ImageUrlService.optimizeForDelivery(_logoController.text.trim()),
        bannerImageUrl: ImageUrlService.optimizeForDelivery(_bannerController.text.trim()),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store branding updated.')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _pickAndUploadImage({required bool isLogo}) async {
    try {
      final actor = context.read<AuthProvider>().user;
      if (actor == null) {
        return;
      }
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
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
        SnackBar(content: Text(isLogo ? 'Logo uploaded from Cloudinary.' : 'Banner uploaded from Cloudinary.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STORE SETTINGS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STORE BRANDING',
                    style: GoogleFonts.poppins(
                      color: AbzioTheme.accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Update your logo, banner, messaging, and storefront identity.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _label('Store Name'),
            TextField(controller: _nameController),
            const SizedBox(height: 18),
            _label('Tagline'),
            TextField(controller: _taglineController, decoration: const InputDecoration(hintText: 'Wedding edits and elevated essentials')),
            const SizedBox(height: 18),
            _label('Address'),
            TextField(controller: _addressController),
            const SizedBox(height: 18),
            _label('Description'),
            TextField(controller: _descriptionController, maxLines: 4),
            const SizedBox(height: 18),
            _label('Logo URL'),
            TextField(controller: _logoController, decoration: const InputDecoration(hintText: 'https://...logo.jpg')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickAndUploadImage(isLogo: true),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('UPLOAD LOGO'),
            ),
            const SizedBox(height: 18),
            _label('Banner URL'),
            TextField(controller: _bannerController, decoration: const InputDecoration(hintText: 'https://...banner.jpg')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickAndUploadImage(isLogo: false),
              icon: const Icon(Icons.upload_rounded),
              label: const Text('UPLOAD BANNER'),
            ),
            const SizedBox(height: 18),
            Text(
              'Cloudinary uploads save hosted image URLs automatically. You can also keep using direct public image URLs for branding.',
              style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey500, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AbzioTheme.grey50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AbzioTheme.grey100),
              ),
              child: Text(
                'Commission rate, payout balance, approval, and featured state stay admin-controlled.',
                style: GoogleFonts.inter(color: AbzioTheme.grey600),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('SAVE STORE SETTINGS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: AbzioTheme.grey500,
        ),
      ),
    );
  }
}
