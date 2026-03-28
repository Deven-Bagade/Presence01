// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google Sign-In
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
    }
    final googleAuth = await googleUser.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final userCred = await _auth.signInWithCredential(cred);
    await _saveUserToFirestore(userCred.user!, provider: 'google');
    return userCred;
  }

  Future<bool> hasAcceptedTerms(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final val = doc.data()?['termsAccepted'];
    return val == true;
  }
  /// Update terms acceptance status
  Future<void> acceptTerms(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'termsAccepted': true,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Trigger sending verification SMS
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCred = await _auth.signInWithCredential(credential);
          await _saveUserToFirestore(userCred.user!, provider: 'phone');
          onAutoVerified(credential);
        } catch (e) {
          // ignore here; caller will handle auth state stream too
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(e);
      },
      codeSent: (verificationId, resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  /// Sign in using verificationId and code
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _saveUserToFirestore(userCred.user!, provider: 'phone');
    return userCred;
  }

  /// Sign out both Google and Firebase
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Save or merge user info to Firestore
  Future<void> _saveUserToFirestore(User user, {required String provider}) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final data = {
      'uid': user.uid,
      'name': user.displayName,
      'email': user.email,
      'phone': user.phoneNumber,
      'photoURL': user.photoURL,
      'authProvider': provider,
      'lastLogin': FieldValue.serverTimestamp(),
      'termsAccepted': false, // Default to false
    };

    final snap = await doc.get();
    if (!snap.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['profileCompleted'] = false;
      data['autoMarkAbsent'] = true;
      data['reminderBeforeLecture'] = 15;
    }
    await doc.set(data, SetOptions(merge: true));
  }

  /// Check if profileCompleted flag exists & true
  Future<bool> isProfileComplete(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return false;
    final val = doc.data()?['profileCompleted'];
    return val == true;
  }

  /// Save profile details (from profile setup screen)
  Future<void> saveUserProfile(String uid, Map<String, dynamic> profileData) async {
    final doc = _firestore.collection('users').doc(uid);
    final merged = {
      ...profileData,
      'profileCompleted': true,
      'lastProfileUpdate': FieldValue.serverTimestamp()
    };
    await doc.set(merged, SetOptions(merge: true));
  }

  /// Get user preferences
  Future<Map<String, dynamic>> getUserPreferences(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  /// Update user preferences
  Future<void> updateUserPreferences(String uid, Map<String, dynamic> prefs) async {
    await _firestore.collection('users').doc(uid).set(
        {'preferences': prefs},
        SetOptions(merge: true)
    );
  }
}