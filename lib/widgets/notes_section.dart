// lib/widgets/notes_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/notes_service.dart';
import '../themes/app_themes.dart';

class NotesSection extends StatefulWidget {
  final String lectureId;
  final DateTime? date;

  const NotesSection({Key? key, required this.lectureId, this.date}) : super(key: key);

  @override
  State<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  final NotesService _notesService = NotesService();
  final TextEditingController _controller = TextEditingController();

  // ✅ FIXED: Store the stream in state so it doesn't restart when the keyboard opens
  late Stream<List<Map<String, dynamic>>> _notesStream;
  bool _isSaving = false;

  // Theme getters
  Color get _primaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.primary;
  Color get _cardColor => Provider.of<ThemeProvider>(context, listen: false).themeData.card;
  Color get _textPrimary => Provider.of<ThemeProvider>(context, listen: false).themeData.textPrimary;
  Color get _textSecondary => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary;
  Color get _borderColor => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary.withOpacity(0.2);

  @override
  void initState() {
    super.initState();
    _notesStream = _notesService.streamNotesForLecture(widget.lectureId);
  }

  // If the user selects a different lecture from the dropdown, update the stream
  @override
  void didUpdateWidget(NotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lectureId != widget.lectureId) {
      _notesStream = _notesService.streamNotesForLecture(widget.lectureId);
    }
  }

  void _clear() => _controller.clear();

  Future<void> _addNote() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _notesService.addNote(
        lectureId: widget.lectureId,
        date: widget.date ?? DateTime.now(),
        content: text,
      );
      _clear();
      FocusScope.of(context).unfocus(); // Close keyboard automatically
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditDialog(Map<String, dynamic> note) {
    final editController = TextEditingController(text: note['content'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Edit note', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: editController,
          maxLines: null,
          style: TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Note content',
            hintStyle: TextStyle(color: _textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _borderColor)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await _notesService.updateNote(noteId: note['id'], content: newText);
              } catch (e) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Delete note?', style: TextStyle(color: _textPrimary)),
        content: Text('This action cannot be undone.', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _notesService.deleteNote(note['id']);
              } catch (e) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _noteTile(Map<String, dynamic> note) {
    String displayDate = note['date'] ?? 'Unknown Date';
    if (note['updatedAt'] != null && note['updatedAt'] is Timestamp) {
      final dt = (note['updatedAt'] as Timestamp).toDate();
      displayDate = DateFormat('MMM d, yyyy • h:mm a').format(dt);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          note['content'] ?? '',
          style: TextStyle(color: _textPrimary, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            displayDate,
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: _textSecondary),
          color: _cardColor,
          onSelected: (v) {
            if (v == 'edit') _showEditDialog(note);
            if (v == 'delete') _confirmDelete(note);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: _textPrimary))),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Add a Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                style: TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write something...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
                  filled: true,
                  fillColor: _cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _isSaving
                ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator()))
                : Container(
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _addNote,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                tooltip: 'Add note',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Previous Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notesStream, // ✅ FIXED: Reads from the cached stream
            builder: (context, snapshot) {
              // ✅ FIXED: Added error checking to catch Firebase issues and display them
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'An error occurred: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _primaryColor));
              }
              final notes = snapshot.data ?? [];
              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes, size: 48, color: _textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('No notes for this lecture yet.', style: TextStyle(color: _textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: notes.length,
                itemBuilder: (context, index) => _noteTile(notes[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}