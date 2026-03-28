// lib/pages/profile_setup_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid;
  const ProfileSetupScreen({required this.uid, super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final AuthService _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _collegeCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile({bool skip = false}) async {
    setState(() => _loading = true);
    try {
      if (skip) {
        await _authService.saveUserProfile(widget.uid, {'profileCompleted': true});
      } else {
        final map = {
          'name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          'college': _collegeCtrl.text.trim().isEmpty ? null : _collegeCtrl.text.trim(),
          'year': _yearCtrl.text.trim().isEmpty ? null : _yearCtrl.text.trim(),
        };
        // remove nulls
        map.removeWhere((k, v) => v == null);
        await _authService.saveUserProfile(widget.uid, map);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        actions: [
          TextButton(
            onPressed: () => _saveProfile(skip: true),
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Add a few details (optional)', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 8),
                TextField(controller: _collegeCtrl, decoration: const InputDecoration(labelText: 'College')),
                const SizedBox(height: 8),
                TextField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Year / Semester')),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => _saveProfile(skip: false), child: const Text('Save & Continue')),
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
