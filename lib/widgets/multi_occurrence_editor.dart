// lib/widgets/multi_occurrence_attendance_dialog.dart
import 'package:flutter/material.dart';
import '../services/attendance_service.dart';
import '../services/lecture_service.dart';

class MultiOccurrenceAttendanceDialog extends StatefulWidget {
  final String lectureId;
  final String lectureName;
  final DateTime date;
  final VoidCallback onUpdated;

  const MultiOccurrenceAttendanceDialog({
    super.key,
    required this.lectureId,
    required this.lectureName,
    required this.date,
    required this.onUpdated,
  });

  @override
  State<MultiOccurrenceAttendanceDialog> createState() => _MultiOccurrenceAttendanceDialogState();
}

class _MultiOccurrenceAttendanceDialogState extends State<MultiOccurrenceAttendanceDialog> {
  final AttendanceService _attendanceService = AttendanceService();
  final LectureService _lectureService = LectureService();
  List<Map<String, dynamic>> _occurrences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOccurrences();
  }

  Future<void> _loadOccurrences() async {
    try {
      final occurrences = await _lectureService.getOccurrencesOnDate(
        lectureId: widget.lectureId,
        date: widget.date,
      );

      final occurrenceData = <Map<String, dynamic>>[];
      for (int i = 0; i < occurrences.length; i++) {
        final attendance = await _attendanceService.getAttendanceForOccurrence(
          lectureId: widget.lectureId,
          date: widget.date,
          occurrenceIndex: i,
        );

        occurrenceData.add({
          'index': i,
          'occurrence': occurrences[i],
          'attendance': attendance,
          'status': attendance?['status'] ?? 'pending',
          'reason': attendance?['reason'] ?? '',
          'notes': attendance?['notes'] ?? '',
        });
      }

      setState(() {
        _occurrences = occurrenceData;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveOccurrence(int index) async {
    final data = _occurrences[index];

    await _attendanceService.markAttendanceForOccurrence(
      lectureId: widget.lectureId,
      date: widget.date,
      occurrenceIndex: index,
      status: data['status'],
      reason: data['reason'].isNotEmpty ? data['reason'] : null,
      notes: data['notes'].isNotEmpty ? data['notes'] : null,
    );

    widget.onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.lectureName} - ${_formatDate(widget.date)}'),
      content: _loading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _occurrences.length,
          itemBuilder: (context, index) {
            return _buildOccurrenceCard(index);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildOccurrenceCard(int index) {
    final data = _occurrences[index];
    final occurrence = data['occurrence'] as LectureOccurrence;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Occurrence ${index + 1}: ${occurrence.formattedStartTime} - ${occurrence.formattedEndTime}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (occurrence.room != null) Text('Room: ${occurrence.room}'),
            if (occurrence.topic != null) Text('Topic: ${occurrence.topic}'),

            const SizedBox(height: 12),

            // Status selector
            Wrap(
              spacing: 8,
              children: ['present', 'absent', 'late', 'cancelled'].map((status) {
                return ChoiceChip(
                  label: Text(status),
                  selected: data['status'] == status,
                  onSelected: (_) {
                    setState(() {
                      _occurrences[index]['status'] = status;
                    });
                    _saveOccurrence(index);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Reason
            TextField(
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: data['reason']),
              onChanged: (value) {
                _occurrences[index]['reason'] = value;
              },
            ),

            const SizedBox(height: 8),

            // Notes
            TextField(
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: data['notes']),
              onChanged: (value) {
                _occurrences[index]['notes'] = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}