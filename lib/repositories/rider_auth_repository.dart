import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderAuthRepository {
  RiderAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithOtpStub(String phone, String otp) async {
    // Replace with real verify flow when Firebase phone auth recaptcha/app verifier is configured.
    if (otp.length < 6) throw Exception('Invalid OTP');
  }

  Future<void> saveSignup(Map<String, dynamic> payload) async {
    final uid = _auth.currentUser?.uid ?? 'demo_rider';
    await _firestore
        .collection('riderApplications')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }
}
