import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/notes_service.dart';

class LectureAttendanceHistory extends StatefulWidget {
  final String lectureId;
  final String lectureName;

  const LectureAttendanceHistory({
    super.key,
    required this.lectureId,
    required this.lectureName,
  });

  @override
  State<LectureAttendanceHistory> createState() => _LectureAttendanceHistoryState();
}

class _LectureAttendanceHistoryState extends State<LectureAttendanceHistory> {
  final AttendanceService _attendanceService = AttendanceService();
  final NotesService _notesService = NotesService();
  List<Map<String, dynamic>> _attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      // First, get all attendance records
      final allRecords = await _attendanceService.getAllAttendance().first;

      // Filter for this specific lecture
      final filtered = allRecords.where((record) {
        return record['lectureId']?.toString() == widget.lectureId;
      }).toList();

      // Sort by date (most recent first)
      filtered.sort((a, b) {
        final dateA = _parseTimestamp(a['markedAt'] ?? a['date']);
        final dateB = _parseTimestamp(b['markedAt'] ?? b['date']);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _attendanceRecords = filtered;
        });
      }
    } catch (e) {
      print('Error loading attendance history: $e');
    }
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return null;

      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (timestamp['_seconds'] as int) * 1000,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.lectureName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadAttendanceHistory,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // History list
            Expanded(
              child: _attendanceRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _attendanceRecords.length,
                itemBuilder: (context, index) {
                  final record = _attendanceRecords[index];
                  final date = _parseTimestamp(record['markedAt']) ??
                      _parseDate(record['date']?.toString());

                  return _buildHistoryTile(record, date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> record, DateTime? date) {
    final status = (record['status'] ?? 'unknown').toString();
    final isAuto = record['autoMarked'] == true;
    final reason = (record['reason'] ?? '').toString();
    final notes = (record['notes'] ?? '').toString();

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    String statusLabel = status.toUpperCase();

    if (status == 'present') {
      statusColor = Colors.green.shade600;
      statusIcon = Icons.check_circle;
    } else if (status == 'absent') {
      statusColor = Colors.red.shade600;
      statusIcon = Icons.cancel;
    } else if (status == 'late') {
      statusColor = Colors.orange.shade600;
      statusIcon = Icons.schedule;
    } else if (status == 'cancelled' || status == 'holiday') {
      statusColor = Colors.blueGrey.shade600;
      statusIcon = Icons.event_busy;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and auto badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('EEE, MMM dd, yyyy').format(date)
                        : 'Date unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isAuto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Status
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: statusColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),

            // Reason and notes
            if (reason.isNotEmpty || notes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  if (reason.isNotEmpty)
                    Text(
                      'Reason: $reason',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  if (notes.isNotEmpty && notes != reason)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Notes: $notes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No attendance history found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attendance will appear here once marked',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}