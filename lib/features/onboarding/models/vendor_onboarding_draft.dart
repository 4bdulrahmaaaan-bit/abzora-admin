import 'package:flutter/material.dart';

class VendorOnboardingDraft {
  // Business Information
  final storeName = TextEditingController();
  final ownerName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final gstNumber = TextEditingController();
  String businessType = 'Individual Seller';

  // Location
  final address = TextEditingController();
  final city = TextEditingController();
  double? latitude;
  double? longitude;

  // Expertise
  final experienceYears = TextEditingController();
  final Set<String> specializations = {};
  final Set<String> serviceTypes = {};
  final List<String> storeTags = [];

  // Portfolio
  final List<String> portfolioPaths = [];
  int primaryPortfolioIndex = 0;

  // Pricing & Capacity
  final startingPrice = TextEditingController();
  final upperPrice = TextEditingController();
  final productionDays = TextEditingController(text: '7');
  final monthlyCapacity = TextEditingController();

  // Finance
  final bankAccount = TextEditingController();
  final confirmBankAccount = TextEditingController();
  final ifsc = TextEditingController();
  final upi = TextEditingController();
  String settlementPreference = 'Weekly';
  String preferredPaymentMethod = 'Bank Transfer';

  // KYC & Compliance
  String? ownerPhotoUrl;
  String? storePhotoUrl;
  String? aadhaarUrl;
  String? panUrl;

  bool isProcessingKyc = false;
  bool kycProcessed = false;
  Map<String, dynamic> aadhaarOcr = {};
  Map<String, dynamic> panOcr = {};
  Map<String, dynamic> vendorVerification = {};
  double kycConfidence = 0.0;

  // Readiness
  bool agreedToTruth = false;
  bool agreedToTerms = false;

  void dispose() {
    storeName.dispose();
    ownerName.dispose();
    phone.dispose();
    email.dispose();
    gstNumber.dispose();
    address.dispose();
    city.dispose();
    experienceYears.dispose();
    startingPrice.dispose();
    upperPrice.dispose();
    productionDays.dispose();
    monthlyCapacity.dispose();
    bankAccount.dispose();
    confirmBankAccount.dispose();
    ifsc.dispose();
    upi.dispose();
  }
}
