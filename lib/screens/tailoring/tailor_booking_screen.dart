import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';

class TailorBookingScreen extends StatefulWidget {
  final String? outfitType;
  final MeasurementProfile? measurementProfile;
  final String? measurementMethod;
  final String? standardSize;

  const TailorBookingScreen({
    super.key,
    this.outfitType,
    this.measurementProfile,
    this.measurementMethod,
    this.standardSize,
  });

  @override
  State<TailorBookingScreen> createState() => _TailorBookingScreenState();
}

class _TailorBookingScreenState extends State<TailorBookingScreen> {
  int _currentStep = 0;
  String _selectedOutfit = 'Sherwani';
  String _selectedTailor = 'Master Ibrahim';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 3));
  String _selectedSlot = '10:00 AM';
  final _notesController = TextEditingController();
  bool _isBooking = false;

  final List<String> _outfits = ['Sherwani', 'Suit', 'Tuxedo', 'Lehenga', 'Saree Blouse', 'Custom'];
  final List<String> _tailors = [
    'Master Ibrahim',
    'Ravi Singh Tailors',
    'Elite Stitch House',
    'Bespoke by Ahana',
  ];
  final List<String> _slots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.outfitType != null) {
      _selectedOutfit = widget.outfitType!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'BOOK APPOINTMENT',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: _currentStep > 0 ? () => setState(() => _currentStep--) : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _buildStep(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['OUTFIT', 'TAILOR', 'DATE & TIME', 'CONFIRM'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AbzioTheme.grey100))),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i <= _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? Colors.black : AbzioTheme.grey300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i],
                        style: GoogleFonts.poppins(
                          fontSize: 7,
                          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                          color: isActive ? Colors.black : AbzioTheme.grey400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(height: 1, width: 16, color: AbzioTheme.grey200, margin: const EdgeInsets.only(bottom: 14)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildOutfitStep();
      case 1:
        return _buildTailorStep();
      case 2:
        return _buildDateTimeStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOutfitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SELECT OUTFIT TYPE'),
        const SizedBox(height: 20),
        ...List.generate(_outfits.length, (i) {
          final outfit = _outfits[i];
          final isSelected = _selectedOutfit == outfit;
          return GestureDetector(
            onTap: () => setState(() => _selectedOutfit = outfit),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? Colors.black : AbzioTheme.grey200, width: isSelected ? 2 : 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    outfit,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTailorStep() {
    final tailorImages = [
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&q=80',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&q=80',
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&q=80',
      'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100&q=80',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CHOOSE YOUR TAILOR'),
        const SizedBox(height: 20),
        ...List.generate(_tailors.length, (i) {
          final tailor = _tailors[i];
          final isSelected = _selectedTailor == tailor;
          return GestureDetector(
            onTap: () => setState(() => _selectedTailor = tailor),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.black : AbzioTheme.grey100, width: isSelected ? 2 : 1.5),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AbzioNetworkImage(
                        imageUrl: tailorImages[i],
                        fallbackLabel: tailor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tailor, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                          'Rating 4.${8 + i % 2} | ${120 + i * 30}+ bookings',
                          style: GoogleFonts.inter(fontSize: 11, color: AbzioTheme.grey500),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDateTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PICK A DATE'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AbzioTheme.grey50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AbzioTheme.grey100),
          ),
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 90)),
            onDateChanged: (d) => setState(() => _selectedDate = d),
          ),
        ),
        const SizedBox(height: 28),
        _sectionLabel('PICK A TIME SLOT'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _slots.map((slot) {
            final isSelected = _selectedSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? Colors.black : AbzioTheme.grey200, width: 1.5),
                ),
                child: Text(
                  slot,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        _sectionLabel('SPECIAL NOTES (OPTIONAL)'),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, height: 1.5),
          decoration: const InputDecoration(hintText: 'Any specific details, references, or fabric preferences...'),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('BOOKING SUMMARY'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.content_cut_rounded, color: AbzioTheme.accentColor, size: 36),
              const SizedBox(height: 16),
              Text(
                'READY TO CONFIRM',
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w900, color: AbzioTheme.accentColor, letterSpacing: 2),
              ),
              const SizedBox(height: 24),
              _confirmRow(Icons.checkroom_outlined, 'Outfit', _selectedOutfit),
              const SizedBox(height: 16),
              _confirmRow(Icons.person_outline_rounded, 'Tailor', _selectedTailor),
              const SizedBox(height: 16),
              _confirmRow(Icons.calendar_today_outlined, 'Date', '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              const SizedBox(height: 16),
              _confirmRow(Icons.access_time_rounded, 'Time', _selectedSlot),
              if (widget.measurementProfile != null) ...[
                const SizedBox(height: 16),
                _confirmRow(
                  Icons.straighten_rounded,
                  'Profile',
                  widget.measurementProfile!.label,
                ),
                if ((widget.standardSize ?? widget.measurementProfile!.standardSize) != null) ...[
                  const SizedBox(height: 16),
                  _confirmRow(
                    Icons.checkroom_rounded,
                    'Standard Size',
                    widget.standardSize ?? widget.measurementProfile!.standardSize!,
                  ),
                ],
                const SizedBox(height: 20),
                _measurementSummaryCard(widget.measurementProfile!),
              ],
            ],
          ),
        ),
        if (_notesController.text.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AbzioTheme.grey50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.notes_rounded, color: AbzioTheme.grey500, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _notesController.text,
                    style: GoogleFonts.inter(fontSize: 12, color: AbzioTheme.grey600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AbzioTheme.grey100))),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isBooking ? null : _handleNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isBooking
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  _currentStep < 3 ? 'CONTINUE' : 'CONFIRM BOOKING',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 13),
                ),
        ),
      ),
    );
  }

  Widget _measurementSummaryCard(MeasurementProfile profile) {
    final methodLabel = widget.measurementMethod ?? profile.method;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Measurement review',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Method: ${methodLabel.toUpperCase()}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _measurementChip('Chest', profile.chest),
              _measurementChip('Waist', profile.waist),
              _measurementChip('Shoulder', profile.shoulder),
              _measurementChip('Sleeve', profile.sleeve),
              _measurementChip('Length', profile.length),
            ],
          ),
        ],
      ),
    );
  }

  Widget _measurementChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)} cm',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w900, color: AbzioTheme.grey500, letterSpacing: 2),
    );
  }

  Future<void> _handleNext() async {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      return;
    }

    setState(() => _isBooking = true);

    final auth = context.read<AuthProvider>();
    final currentUser = auth.user;
    if (currentUser == null) {
      setState(() => _isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Sign in to confirm a tailoring appointment.'),
        ),
      );
      return;
    }
    final booking = BookingModel(
      id: '',
      userId: currentUser.id,
      tailorId: _selectedTailor.toLowerCase().replaceAll(' ', '_'),
      tailorName: _selectedTailor,
      outfitType: _selectedOutfit,
      appointmentDate: _selectedDate,
      timeSlot: _selectedSlot,
      status: 'Confirmed',
      notes: _notesController.text.trim(),
    );

    await DatabaseService().createBooking(booking);

    if (!mounted) {
      return;
    }

    setState(() => _isBooking = false);
    _showSuccess();
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text('BOOKED!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your appointment with $_selectedTailor has been confirmed for ${_selectedDate.day}/${_selectedDate.month} at $_selectedSlot.',
              style: GoogleFonts.inter(fontSize: 13, color: AbzioTheme.grey500, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('DONE', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
