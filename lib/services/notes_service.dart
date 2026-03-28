import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _notesRef =>
      _firestore.collection('users').doc(_uid).collection('notes');

  // ─────────────────────────────────────────
  // ADD / SAVE NOTE (used by dialog & editor)
  // ─────────────────────────────────────────
  Future<void> saveNote({
    required String lectureId,
    required DateTime date,
    required String content,
  }) async {
    final id = _noteId(lectureId, date);

    await _notesRef.doc(id).set({
      'lectureId': lectureId,
      'date': _formatDate(date),
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 🔁 Backward compatibility (old UI calls)
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
  // STREAM NOTES FOR A LECTURE  ✅ FIX
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamNotesForLecture(String lectureId) {
    return _notesRef
        .where('lectureId', isEqualTo: lectureId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  // ─────────────────────────────────────────
  // OPTIONAL: STREAM NOTES FOR DATE
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamNotesForDate(DateTime date) {
    final key = _formatDate(date);

    return _notesRef
        .where('date', isEqualTo: key)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  // Fetch a single note for lecture + date (one-time, non-stream)
  Future<Map<String, dynamic>?> getNoteOnce({
    required String lectureId,
    required DateTime date,
  }) async {
    final id = _noteId(lectureId, date);

    final doc = await _notesRef.doc(id).get();

    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return {
      ...data,
      'id': doc.id,
    };
  }


  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  String _noteId(String lectureId, DateTime date) =>
      '$lectureId-${_formatDate(date)}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
