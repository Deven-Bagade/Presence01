// lib/services/notes_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _notesRef =>
      _firestore.collection('users').doc(_uid).collection('notes');

  // ─────────────────────────────────────────
  // ADD / SAVE NOTE (FIXED: No longer overwrites)
  // ─────────────────────────────────────────
  Future<void> saveNote({
    required String lectureId,
    required DateTime date,
    required String content,
  }) async {
    // ✅ FIXED: Using .add() creates a unique ID for EVERY note.
    await _notesRef.add({
      'lectureId': lectureId,
      'date': _formatDate(date),
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Backward compatibility
  Future<void> addNote({
    required String lectureId,
    required DateTime date,
    required String content,
  }) =>
      saveNote(lectureId: lectureId, date: date, content: content);

  Future<void> updateNote({
    required String noteId,
    required String content,
  }) async {
    await _notesRef.doc(noteId).update({
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _notesRef.doc(noteId).delete();
  }

  // ─────────────────────────────────────────
  // STREAM NOTES FOR A LECTURE
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamNotesForLecture(String lectureId) {
    return _notesRef
        .where('lectureId', isEqualTo: lectureId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();

      docs.sort((a, b) {
        final aTime = a['updatedAt'] as Timestamp?;
        final bTime = b['updatedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return docs;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}