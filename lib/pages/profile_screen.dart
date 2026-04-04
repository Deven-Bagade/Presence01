// lib/pages/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'timetable_history_screen.dart'; // ✅ IMPORT ADDED

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.indigo,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : "U",
                      style: const TextStyle(
                          fontSize: 32, color: Colors.white),
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? "User",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "No email",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Navigation Options
          _buildTile(
            icon: Icons.settings,
            title: "Settings",
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          _buildTile(
            icon: Icons.analytics,
            title: "Analytics",
            onTap: () => Navigator.pushNamed(context, '/analytics'),
          ),
          _buildTile(
            icon: Icons.history,
            title: "Attendance History",
            onTap: () {
              // ✅ FIXED: Navigates to global timetable history
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TimetableHistoryScreen(),
                ),
              );
            },
          ),
          _buildTile(
            icon: Icons.share,
            title: "Share App",
            onTap: () => _shareApp(context),
          ),
          _buildTile(
            icon: Icons.star,
            title: "Rate Us",
            onTap: () => _showRatingDialog(context),
          ),
          _buildTile(
            icon: Icons.lightbulb,
            title: "Suggest a Feature",
            onTap: () => _showFeatureSuggestionDialog(context),
          ),
          _buildTile(
            icon: Icons.logout,
            title: "Logout",
            onTap: () => _showLogoutDialog(context),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.indigo),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      const String apkUrl =
          'https://drive.google.com/uc?export=download&id=1zU1oc0mOeI6TxnZc1L-ehdCEqAz8opVu';

      final String shareText =
          '📱 Check out *Attendigo* – a simple & powerful attendance tracking app!\n\n'
          '⬇️ Download the app instantly from here:\n'
          '$apkUrl\n\n'
          '⚠️ Note: When installing, allow "Install from unknown sources".';

      await Share.share(
        shareText,
        subject: 'Attendigo – Attendance Tracker',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share app: $e')),
      );
    }
  }

  Future<void> _showRatingDialog(BuildContext context) async {
    final ratingController = TextEditingController();
    double selectedRating = 0.0;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rate Our App'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('How would you rate your experience?'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ratingController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Feedback (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Tell us what you like or suggest improvements...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    if (selectedRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a rating'),
                        ),
                      );
                      return;
                    }

                    setState(() => isSubmitting = true);
                    await _submitRating(
                      context,
                      selectedRating,
                      ratingController.text.trim(),
                    );
                    setState(() => isSubmitting = false);

                    if (context.mounted) {
                      Navigator.pop(context);
                      // ✅ FIXED: Removed the ask to rate on Play Store popup here
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating(
      BuildContext context,
      double rating,
      String feedback,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      final userName = user?.displayName ?? 'Anonymous User';
      final userEmail = user?.email;

      await FirebaseFirestore.instance.collection('ratings').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'rating': rating,
        'feedback': feedback,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
        'platform': 'Android',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showFeatureSuggestionDialog(BuildContext context) async {
    final suggestionController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Suggest a Feature'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Have an idea to improve Attendigo? We\'d love to hear it!',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: suggestionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Your suggestion',
                        border: OutlineInputBorder(),
                        hintText: 'Describe the feature you\'d like to see...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                    final suggestion = suggestionController.text.trim();
                    if (suggestion.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a suggestion'),
                        ),
                      );
                      return;
                    }

                    setState(() => isSubmitting = true);
                    await _submitFeatureSuggestion(context, suggestion);
                    setState(() => isSubmitting = false);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitFeatureSuggestion(
      BuildContext context,
      String suggestion,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      final userName = user?.displayName ?? 'Anonymous User';
      final userEmail = user?.email;

      await FirebaseFirestore.instance.collection('feature_suggestions').add({
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'suggestion': suggestion,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'votes': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your suggestion!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit suggestion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}