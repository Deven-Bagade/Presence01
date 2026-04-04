// lib/pages/notes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lecture_service.dart';
import '../widgets/notes_section.dart';
import '../themes/app_themes.dart';

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

  // Theme getters
  Color get _primaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.primary;
  Color get _backgroundColor => Provider.of<ThemeProvider>(context, listen: false).themeData.background;
  Color get _cardColor => Provider.of<ThemeProvider>(context, listen: false).themeData.card;
  Color get _textPrimary => Provider.of<ThemeProvider>(context, listen: false).themeData.textPrimary;
  Color get _textSecondary => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary;
  Color get _borderColor => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary.withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    _loadLectures();
  }

  Future<void> _loadLectures() async {
    try {
      final list = await _lectureService.fetchAllLecturesOnce();

      list.sort((a, b) => (a['subject'] ?? '').compareTo(b['subject'] ?? ''));

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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: Text(
          "Notes",
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: _textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Lecture",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary),
            ),
            const SizedBox(height: 8),

            if (_loading)
              Center(child: CircularProgressIndicator(color: _primaryColor))
            else
              Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLectureId,
                    isExpanded: true,
                    dropdownColor: _cardColor,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Choose a lecture", style: TextStyle(color: _textSecondary)),
                    ),
                    items: _lectures.map((lec) {
                      return DropdownMenuItem<String>(
                        value: lec['id'],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            lec['subject'] ?? 'Untitled',
                            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedLectureId = v);
                    },
                  ),
                ),
              ),

            const SizedBox(height: 8),

            Expanded(
              child: _selectedLectureId == null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.class_outlined, size: 64, color: _textSecondary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      "Select a lecture to view or add notes",
                      style: TextStyle(color: _textSecondary, fontSize: 16),
                    ),
                  ],
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