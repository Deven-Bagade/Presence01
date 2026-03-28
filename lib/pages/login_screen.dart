// lib/pages/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import '../widgets/terms_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onGoogleSignIn() async {
    if (!mounted) return;                // <--- safety check
    setState(() => _loading = true);     // <--- safe now

    try {
      final cred = await _authService.signInWithGoogle();

      if (!mounted) return;              // <--- widget might be gone
      await _postLoginNavigate(cred.user);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(e.message ?? e.code);

    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());

    } finally {
      if (!mounted) return;              // <--- required!
      setState(() => _loading = false);
    }
  }


  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Enter phone with country code, e.g. +91 98765...');
      return;
    }
    setState(() => _loading = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phone,
        onAutoVerified: (credential) async {
          // handled by auth state, but navigate anyway
          final user = FirebaseAuth.instance.currentUser;
          await _postLoginNavigate(user);
        },
        onCodeSent: (verificationId, token) {
          _verificationId = verificationId;
          setState(() => _loading = false);
          _showOtpDialog();
        },
        onFailed: (e) {
          setState(() => _loading = false);
          _showError(e.message ?? e.code);
        },
      );
    } catch (e) {
      _showError(e.toString());
      setState(() => _loading = false);
    }
  }

  void _showOtpDialog() {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Enter OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A verification code was sent to your phone.'),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              otpCtrl.dispose();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = otpCtrl.text.trim();
              if (code.isEmpty || _verificationId == null) {
                _showError('Enter OTP first');
                return;
              }
              Navigator.of(context).pop();
              setState(() => _loading = true);
              try {
                final cred = await _authService.signInWithSmsCode(
                  verificationId: _verificationId!,
                  smsCode: code,
                );
                await _postLoginNavigate(cred.user);
              } on FirebaseAuthException catch (e) {
                _showError(e.message ?? e.code);
              } catch (e) {
                _showError(e.toString());
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

// Update the _postLoginNavigate method in login_screen.dart
  Future<void> _postLoginNavigate(User? user) async {
    if (user == null) return;

    // Check and show terms dialog if not accepted
    final termsAccepted = await _showTermsDialogIfNeeded(user.uid);
    if (!termsAccepted) {
      // User declined terms, don't proceed
      await FirebaseAuth.instance.signOut();
      return;
    }

    final complete = await _authService.isProfileComplete(user.uid);
    if (!mounted) return;

    if (complete) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfileSetupScreen(uid: user.uid)),
      );
    }
  }

  Future<bool> _showTermsDialogIfNeeded(String uid) async {
    final hasAccepted = await _authService.hasAcceptedTerms(uid);
    if (hasAccepted) return true;

    final accepted = await TermsDialog.show(
      context: context,
      userId: uid,
      authService: _authService,
    );

    return accepted == true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text('Welcome to Attendigo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Sign in using Google or your phone number'),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (with country code)',
                    hintText: '+91 98765 43210',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _sendOtp, child: const Text('Send OTP')),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _onGoogleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color.fromARGB(80, 0, 0, 0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
