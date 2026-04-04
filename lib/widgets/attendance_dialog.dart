import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/notes_service.dart';

class AttendanceDialog extends StatefulWidget {
  final Map<String, dynamic> lecture;
  final DateTime date;
  final VoidCallback onUpdated;
  final int? occurrenceIndex;

  const AttendanceDialog({
    super.key,
    required this.lecture,
    required this.date,
    required this.onUpdated,
    this.occurrenceIndex,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  final AttendanceService _attendanceService = AttendanceService();

  String _status = 'present'; // present | absent | late | cancelled | holiday
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  // ─────────────────────────────────────────────
  // SAVE - FIXED
  // ─────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final noteText = _notesCtrl.text.trim();
      final reasonText = _reasonCtrl.text.trim();

      if (_status == 'cancelled' || _status == 'holiday') {
        await _attendanceService.markCancelled(
          lectureId: widget.lecture['id'],
          date: widget.date,
          type: _status,
          note: noteText, // Overrides use 'note'
          occurrenceIndex: widget.occurrenceIndex,
        );
      } else {
        await _attendanceService.markAttendance(
          lectureId: widget.lecture['id'],
          date: widget.date,
          status: _status,
          reason: reasonText, // Regular attendance saves the reason
          notes: noteText,
          autoMarked: false,
          occurrenceIndex: widget.occurrenceIndex,
        );
      }

      // ✅ ADDED: Bridge the note over to the Notes Screen automatically!
      if (noteText.isNotEmpty) {
        await NotesService().addNote(
          lectureId: widget.lecture['id'],
          date: widget.date,
          content: 'Attendance ($_status): $noteText',
        );
      }

      if (!mounted) return;
      widget.onUpdated();
      Navigator.pop(context);

    } catch (e) {
      _error(e.toString());
    }

    if (mounted) setState(() => _saving = false);
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final subject = widget.lecture['subject'] ?? 'Lecture';
    final room = widget.lecture['occurrenceRoom'] ?? widget.lecture['room'] ?? '';
    final topic = widget.lecture['occurrenceTopic'] ?? widget.lecture['topic'] ?? '';
    final startTime = widget.lecture['occurrenceStartTime'] as TimeOfDay?;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mark Attendance",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subject,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          if (widget.occurrenceIndex != null) ...[
            const SizedBox(height: 2),
            Text(
              "Occurrence ${widget.occurrenceIndex! + 1}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lecture info card
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Date: ${_formatDate(widget.date)}",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Time: ${_formatTimeOfDay(startTime)}",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    if (room.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Room: $room",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                    if (topic.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Topic: $topic",
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status picker
            _statusPicker(),
            const SizedBox(height: 16),

            // Reason field (for absent/late)
            if (_status == 'absent' || _status == 'late')
              Column(
                children: [
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: "Reason",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Notes field
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: "Notes",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 3,
            ),

            // Info text for cancelled/holiday
            if (_status == 'cancelled' || _status == 'holiday') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _status == 'cancelled'
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _status == 'cancelled' ? Colors.orange : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  _status == 'cancelled'
                      ? "This will cancel the lecture and remove any existing attendance records."
                      : "This will mark the day as a holiday for this lecture.",
                  style: TextStyle(
                    fontSize: 12,
                    color: _status == 'cancelled' ? Colors.orange[800] : Colors.blue[800],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getStatusColor(_status),
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            _status == 'cancelled' || _status == 'holiday'
                ? "Mark ${_status.capitalize()}"
                : "Mark as ${_status.capitalize()}",
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // STATUS PICKER
  // ─────────────────────────────────────────────
  Widget _statusPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Status",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusChip('present', 'Present', Colors.green),
            _statusChip('absent', 'Absent', Colors.red),
            _statusChip('late', 'Late', Colors.orange),
            _statusChip('cancelled', 'Cancelled', Colors.grey),
            _statusChip('holiday', 'Holiday', Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey[700],
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _status = value),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS - FIXED
  // ─────────────────────────────────────────────
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '--:--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      case 'holiday':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}