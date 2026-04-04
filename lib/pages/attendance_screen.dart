import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/attendance_service.dart';
import '../services/lecture_service.dart';
import '../widgets/attendance_dialog.dart';
import '../widgets/lecture_attendance_history.dart';
import '../themes/app_themes.dart'; // Add this import

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final LectureService _lectureService = LectureService();
  bool _isDisposed = false;

  String _filter = 'all'; // all | present | absent | late
  String _search = '';

  // 🆕 Color scheme from theme provider
  Color get _primaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.primary;
  Color get _secondaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.secondary;
  Color get _accentColor => Provider.of<ThemeProvider>(context, listen: false).themeData.accent;
  Color get _backgroundColor => Provider.of<ThemeProvider>(context, listen: false).themeData.background;
  Color get _cardColor => Provider.of<ThemeProvider>(context, listen: false).themeData.card;
  Color get _textPrimary => Provider.of<ThemeProvider>(context, listen: false).themeData.textPrimary;
  Color get _textSecondary => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary;
  Color get _borderColor => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary.withOpacity(0.2);

  // 🆕 Status colors from theme constants
  Color get _successColor => AppThemeData.presentColor; // Green
  Color get _errorColor => AppThemeData.absentColor;    // Red
  Color get _warningColor => AppThemeData.lateColor;    // Amber

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: Text(
          'Attendance',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _primaryColor),
            onPressed: () {
              if (!_isDisposed) {
                setState(() {}); // simple refresh
              }
            },
            tooltip: 'Refresh',
          )
        ],
      ),
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchAndFilters(),
            const SizedBox(height: 6),
            Expanded(child: _buildAttendanceList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) {
                    if (!_isDisposed) {
                      setState(() => _search = v.trim().toLowerCase());
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: _textSecondary),
                    hintText: 'Search by subject or reason...',
                    hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
                    filled: true,
                    fillColor: _backgroundColor,
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
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, color: _textSecondary),
                      onPressed: () {
                        if (!_isDisposed) {
                          setState(() => _search = '');
                        }
                      },
                    )
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filter chips
// Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _filterChip('present', 'Present'),
                      const SizedBox(width: 8),
                      _filterChip('absent', 'Absent'),
                      const SizedBox(width: 8),
                      _filterChip('late', 'Late'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, color: _primaryColor),
                onPressed: () => _showInfo(context),
                tooltip: 'Auto rules',
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;

    Color chipColor = _primaryColor;
    if (value == 'present') chipColor = _successColor;
    else if (value == 'absent') chipColor = _errorColor;
    else if (value == 'late') chipColor = _warningColor;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        if (!_isDisposed) {
          setState(() => _filter = value);
        }
      },
      selectedColor: chipColor,
      backgroundColor: chipColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? chipColor : _borderColor,
          width: selected ? 0 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildAttendanceList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _attendanceService.getAllAttendance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: _errorColor),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading attendance',
                    style: TextStyle(
                      fontSize: 16,
                      color: _errorColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (!_isDisposed) {
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];

        // Apply filter
        final filtered = data.where((rec) {
          final status = (rec['status'] ?? '').toString();
          if (_filter != 'all' && status != _filter) return false;

          if (_search.isNotEmpty) {
            final subject = (rec['lectureSubject'] ?? '').toString().toLowerCase();
            final reason = (rec['reason'] ?? '').toString().toLowerCase();
            return subject.contains(_search) || reason.contains(_search);
          }
          return true;
        }).toList();

        // Sort by timestamp (most recent first)
        filtered.sort((a, b) {
          try {
            DateTime? aTime = _parseTimestamp(a['markedAt']);
            DateTime? bTime = _parseTimestamp(b['markedAt']);

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          } catch (_) {
            return 0;
          }
        });

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: _textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _search.isNotEmpty || _filter != 'all'
                        ? "No attendance records match your criteria."
                        : "No attendance records yet.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_search.isNotEmpty || _filter != 'all')
                    ElevatedButton(
                      onPressed: () {
                        if (!_isDisposed) {
                          setState(() {
                            _search = '';
                            _filter = 'all';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        foregroundColor: _primaryColor,
                      ),
                      child: const Text('Clear Filters'),
                    ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: _borderColor,
          ),
          itemBuilder: (context, index) {
            final rec = filtered[index];
            return _attendanceTile(rec);
          },
        );
      },
    );
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return null;

      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          (timestamp['_seconds'] as int) * 1000,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _attendanceTile(Map<String, dynamic> rec) {
    // Normalize fields safely
    final status = (rec['status'] ?? 'unknown').toString();
    final subject = (rec['lectureSubject'] ?? 'Lecture').toString();
    final reason = (rec['reason'] ?? '').toString();
    final notes = (rec['notes'] ?? '').toString();
    final auto = rec['autoMarked'] == true;

    // Format time display
    String timeText = 'Unknown';
    String dateText = '';

    try {
      final timestamp = _parseTimestamp(rec['markedAt']);
      if (timestamp != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final recordDay = DateTime(timestamp.year, timestamp.month, timestamp.day);

        if (recordDay == today) {
          timeText = 'Today, ${_formatTime(timestamp)}';
        } else if (recordDay == today.subtract(const Duration(days: 1))) {
          timeText = 'Yesterday, ${_formatTime(timestamp)}';
        } else {
          dateText = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
          timeText = _formatTime(timestamp);
        }
      } else if (rec['date'] != null) {
        dateText = rec['date'].toString();
      }
    } catch (_) {
      timeText = 'Time unknown';
    }

    Color statusColor = _textSecondary;
    IconData statusIcon = Icons.help_outline;
    String statusLabel = status.toUpperCase();

    if (status == 'present') {
      statusColor = _successColor;
      statusIcon = Icons.check_circle;
    } else if (status == 'absent') {
      statusColor = _errorColor;
      statusIcon = Icons.cancel;
    } else if (status == 'late') {
      statusColor = _warningColor;
      statusIcon = Icons.schedule;
    }

    return InkWell(
      onTap: () {
        // open detailed attendance history for lecture id
        final lectureId = rec['lectureId']?.toString() ?? '';
        if (lectureId.isNotEmpty) {
          showDialog(
            context: context,
            builder: (_) => LectureAttendanceHistory(
              lectureId: lectureId,
              lectureName: subject,
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon with background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First row: Subject + Auto badge + Time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (auto)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Auto',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _accentColor,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Date if available
                    if (dateText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ),

                    // Reason or notes
                    if (reason.isNotEmpty || notes.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reason.isNotEmpty)
                            Text(
                              reason,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: _textPrimary,
                              ),
                            ),
                          if (notes.isNotEmpty && notes != reason)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                notes,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 10),

                    // Status chip
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showInfo(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Attendance Information',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Auto-marking rules:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Lectures that have ended without attendance records are automatically marked as "Present"',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Manual attendance takes precedence over auto-marking',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Cancelled/holiday lectures are never auto-marked',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How to use:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Tap any attendance record to view its full history',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Use filters to view specific status types',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Search by subject name or reason',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}