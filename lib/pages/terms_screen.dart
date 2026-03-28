// lib/pages/terms_screen.dart
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now().toLocal().toString().split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendigo Terms of Service',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Last Updated: $currentDate',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection('1. Acceptance of Terms',
                'By using Attendigo, you agree to be bound by these Terms of Service.'),
            const SizedBox(height: 16),
            _buildSection('2. Description of Service',
                'Attendigo is an attendance tracking application that helps users monitor and manage their lecture attendance.'),
            const SizedBox(height: 16),
            _buildSection('3. User Responsibilities',
                'You are responsible for maintaining the confidentiality of your account and for all activities that occur under your account.'),
            const SizedBox(height: 16),
            _buildSection('4. Privacy',
                'We collect and use personal information as described in our Privacy Policy. By using Attendigo, you consent to such collection and use.'),
            const SizedBox(height: 16),
            _buildSection('5. Data Accuracy',
                'You acknowledge that attendance data may not always be 100% accurate and should be verified with official records.'),
            const SizedBox(height: 16),
            _buildSection('6. Modifications to Service',
                'We reserve the right to modify or discontinue the service at any time without notice.'),
            const SizedBox(height: 16),
            _buildSection('7. Limitation of Liability',
                'Attendigo shall not be liable for any indirect, incidental, special, consequential or punitive damages.'),
            const SizedBox(height: 16),
            _buildSection('8. Contact',
                'For any questions about these Terms, please contact us at support@attendigo.com.'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I Understand'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}