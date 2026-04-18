class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://abzora-backend.onrender.com',
  );
  static const String firebaseWebApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY', defaultValue: '');
  static const String firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
  static const String firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String firebaseEmulatorHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '127.0.0.1');
  static const int firebaseAuthEmulatorPort = int.fromEnvironment('FIREBASE_AUTH_EMULATOR_PORT', defaultValue: 9099);
  static const int firebaseDatabaseEmulatorPort = int.fromEnvironment('FIREBASE_DATABASE_EMULATOR_PORT', defaultValue: 9000);
  static const bool useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);
  static const String razorpayKey = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');
  static const String razorpayVerificationEndpoint = String.fromEnvironment(
    'RAZORPAY_VERIFICATION_ENDPOINT',
    defaultValue: '',
  );
  static const String razorpayOrderEndpoint = String.fromEnvironment(
    'RAZORPAY_ORDER_ENDPOINT',
    defaultValue: '',
  );
  static const String razorpayRefundEndpoint = String.fromEnvironment(
    'RAZORPAY_REFUND_ENDPOINT',
    defaultValue: '',
  );
  static const String razorpayCardSetupEndpoint = String.fromEnvironment(
    'RAZORPAY_CARD_SETUP_ENDPOINT',
    defaultValue: '',
  );
  static const String razorpayCardFinalizeEndpoint = String.fromEnvironment(
    'RAZORPAY_CARD_FINALIZE_ENDPOINT',
    defaultValue: '',
  );
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dcedoi0wp',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'abzio_unsigned_uploads',
  );
  static const String cloudinarySignedUploadEndpoint = String.fromEnvironment(
    'CLOUDINARY_SIGNED_UPLOAD_ENDPOINT',
    defaultValue: '',
  );
  static const String kycFaceMatchEndpoint = String.fromEnvironment(
    'KYC_FACE_MATCH_ENDPOINT',
    defaultValue: '',
  );
  static const String openAiApiKey = '';
  static const String openAiModel = 'gpt-5-mini';
  static const String openAiCheapModel = 'gpt-5-nano';
  static const String openAiResponsesEndpoint = '';
  static const String elevenLabsApiKey = String.fromEnvironment(
    'ELEVENLABS_API_KEY',
    defaultValue: '',
  );
  static const String elevenLabsVoiceId = String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: '',
  );
  static const String elevenLabsEndpoint = String.fromEnvironment(
    'ELEVENLABS_ENDPOINT',
    defaultValue: 'https://api.elevenlabs.io/v1/text-to-speech',
  );
  static const String readyPlayerMeAvatarUrl = String.fromEnvironment(
    'READY_PLAYER_ME_AVATAR_URL',
    defaultValue: '',
  );
  static const String appDownloadLink = String.fromEnvironment(
    'APP_DOWNLOAD_LINK',
    defaultValue: 'https://abzora.app',
  );

  static bool get hasFirebaseConfig =>
      firebaseAppId.isNotEmpty && firebaseProjectId.isNotEmpty;

  static bool get hasBackendBaseUrl => backendBaseUrl.isNotEmpty;

  static String get effectiveRazorpayVerificationEndpoint =>
      razorpayVerificationEndpoint.isNotEmpty
          ? razorpayVerificationEndpoint
          : hasBackendBaseUrl
              ? '$backendBaseUrl/orders/verify-payment'
              : '';

  static String get effectiveRazorpayOrderEndpoint =>
      razorpayOrderEndpoint.isNotEmpty
          ? razorpayOrderEndpoint
          : hasBackendBaseUrl
              ? '$backendBaseUrl/orders/create-razorpay-order'
              : '';

  static String get effectiveUploadEndpoint =>
      hasBackendBaseUrl ? '$backendBaseUrl/upload' : '';

  static bool get hasRazorpayKey =>
      razorpayKey.isNotEmpty && !razorpayKey.contains('YOUR_KEY_HERE');
  static bool get hasRazorpayVerificationEndpoint =>
      effectiveRazorpayVerificationEndpoint.isNotEmpty;
  static bool get hasRazorpayOrderEndpoint =>
      effectiveRazorpayOrderEndpoint.isNotEmpty;
  static bool get hasRazorpayRefundEndpoint =>
      razorpayRefundEndpoint.isNotEmpty;
  static bool get hasRazorpayCardSetupEndpoint =>
      razorpayCardSetupEndpoint.isNotEmpty;
  static bool get hasRazorpayCardFinalizeEndpoint =>
      razorpayCardFinalizeEndpoint.isNotEmpty;
  static bool get hasRazorpayCardVaulting =>
      hasRazorpayKey &&
      hasRazorpayCardSetupEndpoint &&
      hasRazorpayCardFinalizeEndpoint;

  static bool get hasGoogleMapsKey => googleMapsApiKey.isNotEmpty;

  static bool get hasCloudinaryConfig =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  static bool get hasCloudinarySignedUploadEndpoint =>
      cloudinarySignedUploadEndpoint.isNotEmpty;

  static bool get hasKycFaceMatchEndpoint => kycFaceMatchEndpoint.isNotEmpty;

  static bool get hasOpenAiConfig =>
      false;

  static bool get hasElevenLabsConfig =>
      elevenLabsApiKey.isNotEmpty && elevenLabsVoiceId.isNotEmpty;

  static bool get hasReadyPlayerMeAvatar =>
      readyPlayerMeAvatarUrl.isNotEmpty;
}
