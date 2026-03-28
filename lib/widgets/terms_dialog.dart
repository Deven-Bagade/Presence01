// lib/widgets/terms_dialog.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../pages/terms_screen.dart';

class TermsDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String userId,
    required AuthService authService,
  }) async {
    // First check if already accepted
    final hasAccepted = await authService.hasAcceptedTerms(userId);
    if (hasAccepted) return true;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must explicitly accept or decline
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Before using Attendigo, please read and accept our Terms and Conditions.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your acceptance will be recorded in our database.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Decline button - exit app
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false); // Return false
              Future.delayed(const Duration(milliseconds: 300), () {
                // Exit the application
                Navigator.of(context, rootNavigator: true).pop();
                // For Android, you might need SystemNavigator.pop()
              });
            },
            child: const Text('Decline & Exit'),
          ),
          // View Terms button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TermsScreen(),
                ),
              ).then((_) {
                // Re-show dialog after viewing terms
                show(context: context, userId: userId, authService: authService);
              });
            },
            child: const Text('View Terms'),
          ),
          // Accept button
          ElevatedButton(
            onPressed: () async {
              try {
                await authService.acceptTerms(userId);
                Navigator.of(context).pop(true); // Return true
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save acceptance: $e')),
                );
              }
            },
            child: const Text('Accept & Continue'),
          ),
        ],
      ),
    );
  }
}