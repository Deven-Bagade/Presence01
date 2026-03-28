// lib/widgets/notes_section.dart
// Simple Notes UI: lists notes for a lecture and allows add / edit / delete.
//
// Usage:
//   NotesSection(lectureId: lectureId, date: DateTime.now())
// or to place inside attendance dialog.

import 'package:flutter/material.dart';
import '../services/notes_service.dart';

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
  bool _isSaving = false;

  void _clear() {
    _controller.clear();
  }

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
    } catch (e) {
      // Basic error handling: show snackbar
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showEditDialog(Map<String, dynamic> note) {
    final editController = TextEditingController(text: note['content'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: editController,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Note content'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await _notesService.updateNote(noteId: note['id'], content: newText);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
        title: const Text('Delete note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await _notesService.deleteNote(note['id']);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _noteTile(Map<String, dynamic> note) {
    final ts = note['timestamp'] ?? '';
    final dateStr = ts is String ? ts.split('T').first : ts.toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(note['content'] ?? ''),
        subtitle: Text(dateStr),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _showEditDialog(note);
            if (v == 'delete') _confirmDelete(note);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream notes for this lecture
    final stream = _notesService.streamNotesForLecture(widget.lectureId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Write a quick note...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isSaving
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
                : IconButton(
              onPressed: _addNote,
              icon: const Icon(Icons.send),
              tooltip: 'Add note',
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final notes = snapshot.data ?? [];
            if (notes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No notes yet.'),
              );
            }
            return Column(
              children: notes.map((n) => _noteTile(n)).toList(),
            );
          },
        ),
      ],
    );
  }
}
