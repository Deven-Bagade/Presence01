// lib/pages/notes_screen.dart
import 'package:flutter/material.dart';
import '../services/lecture_service.dart';
import '../widgets/notes_section.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final LectureService _lectureService = LectureService();

  List<Map<String, dynamic>> _lectures = [];
  String? _selectedLectureId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    try {
      final list = await _lectureService.fetchAllLecturesOnce();

      list.sort((a, b) =>
          (a['subject'] ?? '').compareTo(b['subject'] ?? ''));

      if (!mounted) return;

      setState(() {
        _lectures = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notes")),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Lecture",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _selectedLectureId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Choose a lecture",
                ),
                items: _lectures.map((lec) {
                  return DropdownMenuItem<String>(
                    value: lec['id'],
                    child: Text(lec['subject'] ?? 'Untitled'),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() => _selectedLectureId = v);
                },
              ),

            const SizedBox(height: 14),

            Expanded(
              child: _selectedLectureId == null
                  ? const Center(
                child: Text(
                  "Select a lecture to view/add notes",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : NotesSection(
                lectureId: _selectedLectureId!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
