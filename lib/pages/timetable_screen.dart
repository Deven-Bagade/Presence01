import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lecture_service.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_dialog.dart';
import '../widgets/lecture_attendance_history.dart';
import './add_lecture_screen.dart';
import './timetable_history_screen.dart';
import '../themes/app_themes.dart';
import '../services/notification_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final LectureService _lectureService = LectureService();
  final AttendanceService _attendanceService = AttendanceService();
  final NotificationService _notificationService = NotificationService();

  bool isWeekly = true;
  bool _autoMarkedOnce = false;

  // 🆕 FIXED: Use proper state management
  final _refreshStream = StreamController<bool>.broadcast();
  bool get _isDisposed => !_refreshStream.hasListener && !mounted;

  // 🆕 SWAP STATE (UPDATED FOR OCCURRENCE-SPECIFIC SWAPPING)
  bool _swapMode = false;
  String? _swapFirstId;
  String? _swapSecondId;
  int? _swapFirstOccurrenceIndex;
  int? _swapSecondOccurrenceIndex;
  Map<String, Map<String, dynamic>> _swapLectures = {}; // occurrenceKey -> {lectureId, subject, occurrenceIndex}

  static const double timeColumnWidth = 80.0;
  static const double hourCellHeight = 88.0;

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
  Color get _warningColor => AppThemeData.lateColor;    // Amber
  Color get _errorColor => AppThemeData.absentColor;    // Red

  // Swap colors (kept consistent)
  Color get _swapFirstColor => const Color(0xFFFF9500); // Orange
  Color get _swapSecondColor => const Color(0xFF34C759); // Green

  // 🆕 Helper getters for swap keys
  String get _swapFirstKey => _swapFirstId != null && _swapFirstOccurrenceIndex != null
      ? '$_swapFirstId-$_swapFirstOccurrenceIndex'
      : '';

  String get _swapSecondKey => _swapSecondId != null && _swapSecondOccurrenceIndex != null
      ? '$_swapSecondId-$_swapSecondOccurrenceIndex'
      : '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_autoMarkedOnce) {
        try {
          print('🔄 Starting auto-mark attendance...');
          await _attendanceService.autoMarkPresentForMissed();

          // Initialize notification service
          await _notificationService.initialize();

          // Request permissions if not granted
          final granted = await _notificationService.requestNotificationPermissions();

          if (granted) {
            // Schedule notifications
            await _notificationService.rescheduleAllNotifications();
            print('✅ Notifications scheduled successfully');
          } else {
            print('⚠️ Notification permissions not granted');
          }

          if (!mounted) return;
          setState(() => _autoMarkedOnce = true);
          _refreshStream.add(true);
        } catch (e) {
          print('❌ Error auto-marking attendance: $e');
        }
      }
    });
  }
  @override
  void dispose() {
    _refreshStream.close();
    super.dispose();
  }

  // 🆕 Refresh method
  void _refreshTimetable() {
    if (!mounted) return;
    setState(() {});
    _refreshStream.add(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _swapMode
              ? (_swapFirstId == null && _swapSecondId == null)
              ? "🔀 Select first occurrence"
              : (_swapFirstId != null && _swapSecondId == null)
              ? "🔀 Select second occurrence"
              : "🔀 Confirm swap"
              : "📅 Timetable",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          // Add lecture button
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: _primaryColor,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditLectureScreen()),
            ),
          ),

          // Swap toggle button
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _swapMode ? _warningColor.withOpacity(0.1) : _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _swapMode ? Icons.close : Icons.swap_horiz,
                color: _swapMode ? _warningColor : _primaryColor,
                size: 20,
              ),
            ),
            tooltip: _swapMode ? "Cancel Swap" : "Swap Occurrences",
            onPressed: () {
              setState(() {
                _swapMode = !_swapMode;
                _swapFirstId = null;
                _swapSecondId = null;
                _swapFirstOccurrenceIndex = null;
                _swapSecondOccurrenceIndex = null;
                _swapLectures.clear();
              });
            },
          ),

          // Confirm swap button (only shows when two occurrences are selected)
          if (_swapMode && _swapFirstId != null && _swapSecondId != null)
            IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: _successColor,
                  size: 20,
                ),
              ),
              tooltip: "Confirm Swap",
              onPressed: _confirmSwap,
            ),
        ],
      ),
      body: Column(
        children: [
          _viewToggle(),
          Expanded(child: isWeekly ? _weeklyView() : _dailyView()),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // OCCURRENCE-SPECIFIC SWAP LOGIC
  // ─────────────────────────────────────────
  bool _isSwapping = false;

  void _confirmSwap() async {
    if (_swapFirstId == null || _swapSecondId == null ||
        _swapFirstOccurrenceIndex == null || _swapSecondOccurrenceIndex == null ||
        _isSwapping) return;

    _isSwapping = true;

    final firstLecture = _swapLectures[_swapFirstKey];
    final secondLecture = _swapLectures[_swapSecondKey];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          "🔀 Swap Occurrences",
          style: TextStyle(color: _primaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Swap specific occurrences:",
              style: TextStyle(color: _textPrimary),
            ),
            const SizedBox(height: 12),
            Card(
              color: _swapFirstColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📌 First: ${firstLecture?['subject'] ?? 'Unknown'}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _swapFirstColor,
                      ),
                    ),
                    Text(
                      "Occurrence ${(_swapFirstOccurrenceIndex! + 1)}",
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: _swapSecondColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📌 Second: ${secondLecture?['subject'] ?? 'Unknown'}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _swapSecondColor,
                      ),
                    ),
                    Text(
                      "Occurrence ${(_swapSecondOccurrenceIndex! + 1)}",
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Only these specific occurrences will swap their days/times.",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Other occurrences of these lectures will remain unchanged.",
              style: TextStyle(
                color: _accentColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isSwapping = false;
            },
            child: Text(
              "Cancel",
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _performSwap();
              _isSwapping = false;
            },
            child: const Text("Swap Occurrences"),
          ),
        ],
      ),
    );
  }

  Future<void> _performSwap() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Perform occurrence-specific swap
      await _lectureService.swapOccurrences(
        lectureAId: _swapFirstId!,
        occurrenceIndexA: _swapFirstOccurrenceIndex!,
        lectureBId: _swapSecondId!,
        occurrenceIndexB: _swapSecondOccurrenceIndex!,
      );

      // Check if widget is still mounted before popping
      if (!mounted) return;

      // Pop the loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✅ Occurrences swapped successfully"),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Reset swap state
      setState(() {
        _swapMode = false;
        _swapFirstId = null;
        _swapSecondId = null;
        _swapFirstOccurrenceIndex = null;
        _swapSecondOccurrenceIndex = null;
        _swapLectures.clear();
      });

      // Refresh timetable
      _refreshTimetable();

    } catch (e) {
      // Check if widget is still mounted before popping
      if (!mounted) return;

      // Pop the loading dialog using rootNavigator to ensure we pop the dialog
      Navigator.of(context, rootNavigator: true).pop();

      // Show error
      _showError("Failed to swap occurrences: ${e.toString()}");
    }
  }

  void _selectForSwap(dynamic occurrenceData) {
    if (!_swapMode) return;

    final normalizedData = _normalizeOccurrenceData(occurrenceData);
    final lectureId = normalizedData['id'] as String?;
    final subject = normalizedData['subject'] as String? ?? 'Unknown';
    final occurrenceIndex = normalizedData['occurrenceIndex'] as int? ?? 0;

    if (lectureId == null) return;

    // Create a unique key for this specific occurrence
    final occurrenceKey = '$lectureId-$occurrenceIndex';

    setState(() {
      if (_swapFirstId == null) {
        _swapFirstId = lectureId;
        _swapFirstOccurrenceIndex = occurrenceIndex;
        _swapLectures[occurrenceKey] = {
          'subject': subject,
          'lectureId': lectureId,
          'occurrenceIndex': occurrenceIndex,
        };
      } else if (_swapSecondId == null && occurrenceKey != _swapFirstKey) {
        _swapSecondId = lectureId;
        _swapSecondOccurrenceIndex = occurrenceIndex;
        _swapLectures[occurrenceKey] = {
          'subject': subject,
          'lectureId': lectureId,
          'occurrenceIndex': occurrenceIndex,
        };
      } else if (_swapFirstKey == occurrenceKey) {
        // Deselect first
        _swapFirstId = null;
        _swapFirstOccurrenceIndex = null;
        _swapLectures.remove(occurrenceKey);

        // Move second to first if exists
        if (_swapSecondId != null) {
          _swapFirstId = _swapSecondId;
          _swapFirstOccurrenceIndex = _swapSecondOccurrenceIndex;
          _swapSecondId = null;
          _swapSecondOccurrenceIndex = null;
        }
      } else if (_swapSecondKey == occurrenceKey) {
        // Deselect second
        _swapSecondId = null;
        _swapSecondOccurrenceIndex = null;
        _swapLectures.remove(occurrenceKey);
      }
    });
  }

  Map<String, dynamic> _normalizeOccurrenceData(dynamic occurrenceData) {
    // Handle both Map and LectureOccurrence types
    if (occurrenceData is Map<String, dynamic>) {
      final map = Map<String, dynamic>.from(occurrenceData);

      // 🆕 Try to extract occurrence index
      if (occurrenceData.containsKey('occurrence')) {
        final occ = occurrenceData['occurrence'] as LectureOccurrence?;
        if (occ != null) {
          // Try to find the occurrence index
          final allOccurrences = occurrenceData['occurrencesList'] as List<LectureOccurrence>?;
          if (allOccurrences != null) {
            for (int i = 0; i < allOccurrences.length; i++) {
              final checkOcc = allOccurrences[i];
              if (checkOcc.dayOfWeek == occ.dayOfWeek &&
                  checkOcc.startTime.hour == occ.startTime.hour &&
                  checkOcc.startTime.minute == occ.startTime.minute) {
                map['occurrenceIndex'] = i;
                break;
              }
            }
          }
        }
      }

      return map;
    }
    // If it's already a LectureOccurrence, wrap it in a map
    else if (occurrenceData is LectureOccurrence) {
      return {
        'occurrence': occurrenceData,
        'occurrenceStartTime': occurrenceData.startTime,
        'occurrenceEndTime': occurrenceData.endTime,
        'subject': 'Unknown Lecture',
        'occurrenceIndex': 0, // Default to first occurrence
      };
    }

    // Fallback
    return {'subject': 'Unknown', 'occurrenceIndex': 0};
  }

  LectureOccurrence? _extractOccurrence(dynamic data) {
    if (data is LectureOccurrence) {
      return data;
    } else if (data is Map<String, dynamic>) {
      return data['occurrence'] as LectureOccurrence?;
    }
    return null;
  }

  // ─────────────────────────────────────────
  // VIEW TOGGLE
  // ─────────────────────────────────────────
  Widget _viewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Text("Daily"),
            selected: !isWeekly,
            selectedColor: _primaryColor,
            labelStyle:
            TextStyle(color: !isWeekly ? Colors.white : _textSecondary),
            onSelected: (_) => setState(() => isWeekly = false),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text("Weekly"),
            selected: isWeekly,
            selectedColor: _primaryColor,
            labelStyle:
            TextStyle(color: isWeekly ? Colors.white : _textSecondary),
            onSelected: (_) => setState(() => isWeekly = true),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // WEEKLY VIEW
  // ─────────────────────────────────────────
  Widget _weeklyView() {
    return StreamBuilder<bool>(
      stream: _refreshStream.stream,
      initialData: true,
      builder: (context, refreshSnapshot) {
        return StreamBuilder<Map<int, List<Map<String, dynamic>>>>(
          stream: _lectureService.getWeeklyTimetableStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('Weekly view error: ${snapshot.error}');
              return _buildError("Error loading timetable: ${snapshot.error}");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmpty(message: "No weekly lectures scheduled");
            }

            final weekly = snapshot.data!;
            final allOccurrences = weekly.values.expand((e) => e).toList();

            if (allOccurrences.isEmpty) {
              return _buildEmpty(message: "No lectures this week");
            }

            // Find earliest start time and latest end time
            TimeOfDay? minStartTime;
            TimeOfDay? maxEndTime;

            for (final occurrence in allOccurrences) {
              final startTime = occurrence['occurrenceStartTime'] as TimeOfDay?;
              final endTime = occurrence['occurrenceEndTime'] as TimeOfDay?;

              if (startTime != null) {
                if (minStartTime == null ||
                    startTime.hour * 60 + startTime.minute <
                        minStartTime.hour * 60 + minStartTime.minute) {
                  minStartTime = startTime;
                }
              }

              if (endTime != null) {
                if (maxEndTime == null ||
                    endTime.hour * 60 + endTime.minute >
                        maxEndTime.hour * 60 + maxEndTime.minute) {
                  maxEndTime = endTime;
                }
              }
            }

            // Use default times if none found
            final startHour = minStartTime?.hour ?? 8;
            final endHour = maxEndTime?.hour ?? 17;

            // Create time slots from start hour to end hour
            final slots = List.generate((endHour - startHour + 1).clamp(1, 24), (i) => startHour + i);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                  maxWidth:
                  max(MediaQuery.of(context).size.width, timeColumnWidth + 7 * 140),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _weekHeader(),
                        const SizedBox(height: 6),
                        Column(
                          children:
                          slots.map((hour) => _timeRow(hour, weekly)).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // DAILY VIEW
  // ─────────────────────────────────────────
  Widget _dailyView() {
    final today = DateTime.now().weekday;

    return StreamBuilder<bool>(
      stream: _refreshStream.stream,
      initialData: true,
      builder: (context, refreshSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _lectureService.getLecturesForDayStream(today),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildError("Error loading today's lectures");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmpty(message: "No lectures today");
            }

            final occurrences = snapshot.data!;

            // Sort occurrences by start time
            occurrences.sort((a, b) {
              final aStart = a['occurrenceStartTime'] as TimeOfDay?;
              final bStart = b['occurrenceStartTime'] as TimeOfDay?;

              if (aStart == null || bStart == null) return 0;

              final aStartMin = aStart.hour * 60 + aStart.minute;
              final bStartMin = bStart.hour * 60 + bStart.minute;
              return aStartMin.compareTo(bStartMin);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: occurrences.length,
              itemBuilder: (_, i) => _dailyCard(occurrences[i]),
            );
          },
        );
      },
    );
  }

  Widget _dailyCard(Map<String, dynamic> occurrenceData) {
    final subject = occurrenceData['subject'] ?? '';
    final room = occurrenceData['occurrenceRoom'] ?? occurrenceData['room'] ?? '';
    final topic = occurrenceData['occurrenceTopic'] ?? occurrenceData['topic'] ?? '';
    final startTime = occurrenceData['occurrenceStartTime'] as TimeOfDay?;
    final endTime = occurrenceData['occurrenceEndTime'] as TimeOfDay?;
    final lectureId = occurrenceData['id'] as String?;
    final occurrenceIndex = occurrenceData['occurrenceIndex'] as int? ?? 0;

    final occurrenceKey = lectureId != null ? '$lectureId-$occurrenceIndex' : '';
    final isSelected = _swapMode && (occurrenceKey == _swapFirstKey || occurrenceKey == _swapSecondKey);
    final isFirstSelected = occurrenceKey == _swapFirstKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? (isFirstSelected
            ? _swapFirstColor.withOpacity(0.1)
            : _swapSecondColor.withOpacity(0.1))
            : _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
              : _borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isFirstSelected ? _swapFirstColor : _swapSecondColor).withOpacity(0.2)
                : _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                startTime?.hour.toString().padLeft(2, '0') ?? '--',
                style: TextStyle(
                  color: isSelected
                      ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
                      : _primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                startTime?.minute.toString().padLeft(2, '0') ?? '--',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                subject,
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (_swapMode && isSelected)
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: CircleAvatar(
                  backgroundColor: isFirstSelected ? _swapFirstColor : _swapSecondColor,
                  radius: 10,
                  child: Text(
                    isFirstSelected ? "1" : "2",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topic.isNotEmpty)
              Text(
                topic,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: _textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  "${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}",
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: _textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  room,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            // 🆕 Show occurrence index if multiple occurrences exist
            if (occurrenceData['occurrenceCount'] != null && occurrenceData['occurrenceCount'] > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Occurrence ${occurrenceIndex + 1} of ${occurrenceData['occurrenceCount']}",
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: _buildTrailingIcon(occurrenceData),
        onTap: () => _openOptions(occurrenceData),
      ),
    );
  }

  Widget _buildTrailingIcon(Map<String, dynamic> occurrenceData) {
    final lectureId = occurrenceData['id'] as String?;
    final occurrenceIndex = occurrenceData['occurrenceIndex'] as int? ?? 0;

    if (_swapMode && lectureId != null) {
      final occurrenceKey = '$lectureId-$occurrenceIndex';

      if (occurrenceKey == _swapFirstKey) {
        return CircleAvatar(
          backgroundColor: _swapFirstColor,
          radius: 12,
          child: Text("1", style: TextStyle(color: Colors.white, fontSize: 10)),
        );
      } else if (occurrenceKey == _swapSecondKey) {
        return CircleAvatar(
          backgroundColor: _swapSecondColor,
          radius: 12,
          child: Text("2", style: TextStyle(color: Colors.white, fontSize: 10)),
        );
      }
    }

    return Icon(
      Icons.more_vert,
      color: _textSecondary,
      size: 20,
    );
  }

  // ─────────────────────────────────────────
  // WEEKLY GRID HELPERS
  // ─────────────────────────────────────────
  Widget _weekHeader() {
    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final fullDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    final today = DateTime.now().weekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: timeColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                'Time',
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          ...days.asMap().entries.map(
                (entry) => Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: entry.key == today
                      ? _accentColor.withOpacity(0.1)
                      : _backgroundColor,
                  border: Border(
                    left: BorderSide(color: _borderColor),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: entry.key == today
                            ? _accentColor
                            : _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fullDays[entry.key].substring(0, 3),
                      style: TextStyle(
                        color: entry.key == today
                            ? _accentColor
                            : _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow(
      int hour,
      Map<int, List<Map<String, dynamic>>> weekly,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _timeCell(hour),
        ...List.generate(7, (i) {
          final day = i + 1;
          final dayOccurrences = weekly[day] ?? [];
          return Expanded(
            child: Container(
              height: hourCellHeight,
              decoration: BoxDecoration(
                color: i % 2 == 0 ? _cardColor : _backgroundColor,
                border: Border(
                  top: BorderSide(color: _borderColor),
                  left: BorderSide(color: _borderColor),
                ),
              ),
              child: _hourCellContent(hour, dayOccurrences),
            ),
          );
        }),
      ],
    );
  }

  Widget _timeCell(int hour) {
    return Container(
      width: timeColumnWidth,
      height: hourCellHeight,
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _borderColor),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '${hour.toString().padLeft(2, '0')}:00',
        style: TextStyle(
          color: _textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _hourCellContent(
      int hour,
      List<Map<String, dynamic>> dayOccurrences,
      ) {
    final slotStart = DateTime(2025, 1, 1, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));

    final overlaps = <Map<String, dynamic>>[];

    for (final occurrence in dayOccurrences) {
      final startTime = occurrence['occurrenceStartTime'] as TimeOfDay?;
      final endTime = occurrence['occurrenceEndTime'] as TimeOfDay?;

      if (startTime == null || endTime == null) continue;

      // Convert TimeOfDay to DateTime for comparison
      final s = DateTime(slotStart.year, slotStart.month, slotStart.day, startTime.hour, startTime.minute);
      final e = DateTime(slotStart.year, slotStart.month, slotStart.day, endTime.hour, endTime.minute);

      if (s.isBefore(slotEnd) && e.isAfter(slotStart)) {
        overlaps.add({
          ...occurrence,
          '__start': s.isBefore(slotStart) ? slotStart : s,
          '__end': e.isAfter(slotEnd) ? slotEnd : e,
        });
      }
    }

    if (overlaps.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: overlaps.asMap().entries.map((entry) {
        final occurrence = entry.value;
        final start = occurrence['__start'] as DateTime;
        final end = occurrence['__end'] as DateTime;

        final minutesFromTop = start.minute;
        final heightMinutes = end.difference(start).inMinutes;

        final lectureId = occurrence['id'] as String?;
        final occurrenceIndex = occurrence['occurrenceIndex'] as int? ?? 0;
        final occurrenceKey = lectureId != null ? '$lectureId-$occurrenceIndex' : '';
        final isSelected = occurrenceKey == _swapFirstKey || occurrenceKey == _swapSecondKey;
        final isFirstSelected = occurrenceKey == _swapFirstKey;

        return Positioned(
          top: minutesFromTop / 60 * hourCellHeight,
          left: 4,
          right: 4,
          height: max(24, heightMinutes / 60 * hourCellHeight),
          child: GestureDetector(
            onTap: () {
              if (_swapMode) {
                _selectForSwap(occurrence);
                return;
              }
              _openOptions(occurrence);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              // 1. ADD THIS LINE: It cuts off any text that spills outside the box visually
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isFirstSelected
                    ? _swapFirstColor.withOpacity(0.2)
                    : _swapSecondColor.withOpacity(0.2))
                    : _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
                      : _primaryColor.withOpacity(0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              // 2. ADD THIS WRAPPER: It gives the Column infinite vertical space so it never throws a RenderFlex error
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            occurrence['subject'] ?? '',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
                                  : _textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (_swapMode && isSelected)
                          CircleAvatar(
                            backgroundColor: isFirstSelected ? _swapFirstColor : _swapSecondColor,
                            radius: 6,
                            child: Text(
                              isFirstSelected ? "1" : "2",
                              style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    if (occurrence['occurrenceRoom'] != null)
                      Text(
                        occurrence['occurrenceRoom'] ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected
                              ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
                              : _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    if (occurrence['occurrenceCount'] != null && occurrence['occurrenceCount'] > 1)
                      Text(
                        "Occ ${(occurrenceIndex + 1)}",
                        style: TextStyle(
                          fontSize: 8,
                          color: isSelected
                              ? (isFirstSelected ? _swapFirstColor : _swapSecondColor)
                              : _textSecondary.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────
  // OPTIONS DIALOG
  // ─────────────────────────────────────────
  void _openOptions(dynamic occurrenceData) async {
    final normalizedData = _normalizeOccurrenceData(occurrenceData);
    final lectureId = normalizedData['id'] as String?;
    final subject = normalizedData['subject'] as String? ?? 'Lecture';
    final occurrenceIndex = normalizedData['occurrenceIndex'] as int? ?? 0;

    if (lectureId == null) return;

    // Get all occurrences to determine if multiple
    final lectureService = LectureService();
    final allOccurrences = await lectureService.getAllOccurrences(lectureId);
    final currentOccurrence = occurrenceData['occurrence'] as LectureOccurrence?;

    // Find occurrence index (in case it wasn't passed correctly)
    int foundOccurrenceIndex = occurrenceIndex;
    if (currentOccurrence != null) {
      for (int i = 0; i < allOccurrences.length; i++) {
        final occ = allOccurrences[i];
        if (occ.dayOfWeek == currentOccurrence.dayOfWeek &&
            occ.startTime.hour == currentOccurrence.startTime.hour &&
            occ.startTime.minute == currentOccurrence.startTime.minute) {
          foundOccurrenceIndex = i;
          break;
        }
      }
    }

    final isMultipleOccurrence = allOccurrences.length > 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subject,
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_formatTimeOfDay(occurrenceData['occurrenceStartTime'] as TimeOfDay?)} • ${occurrenceData['occurrenceRoom'] ?? occurrenceData['room'] ?? 'No room'}",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (isMultipleOccurrence)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Occurrence ${foundOccurrenceIndex + 1} of ${allOccurrences.length}",
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Swap option
            if (_swapMode)
              ListTile(
                leading: Icon(Icons.swap_horiz, color: _warningColor),
                title: Text(
                  "Select for swap",
                  style: TextStyle(color: _textPrimary),
                ),
                subtitle: isMultipleOccurrence
                    ? Text(
                  "Occurrence ${foundOccurrenceIndex + 1}",
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                )
                    : null,
                trailing: _getSwapTrailingIcon(lectureId, foundOccurrenceIndex),
                onTap: () {
                  Navigator.pop(context);
                  // Add occurrence index to the data
                  occurrenceData['occurrenceIndex'] = foundOccurrenceIndex;
                  _selectForSwap(occurrenceData);
                },
              ),

            // Mark Attendance option
            ListTile(
              leading: Icon(Icons.check, color: _primaryColor),
              title: Text(
                "Mark Attendance",
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () async {
                Navigator.pop(context);

                // Get attendance for this specific occurrence
                final today = DateTime.now();
                final att = await _attendanceService.getAttendanceForOccurrence(
                  lectureId: lectureId!,
                  date: today,
                  occurrenceIndex: foundOccurrenceIndex,
                );

                if (!mounted) return;

                showDialog(
                  context: context,
                  builder: (_) => AttendanceDialog(
                    lecture: occurrenceData,
                    date: today,
                    onUpdated: _refreshTimetable,
                    occurrenceIndex: foundOccurrenceIndex,
                  ),
                );
              },
            ),

            // Attendance History option
            ListTile(
              leading: Icon(Icons.history, color: _secondaryColor),
              title: Text(
                "Attendance History",
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => LectureAttendanceHistory(
                    lectureId: lectureId!,
                    lectureName: subject,
                  ),
                );
              },
            ),

            // View Timetable History option
            ListTile(
              leading: Icon(Icons.history, color: Colors.deepPurple),
              title: Text(
                "View Timetable History",
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimetableHistoryScreen(
                      lectureId: lectureId!,
                      lectureName: subject,
                    ),
                  ),
                );
              },
            ),

            // Edit Lecture option
            ListTile(
              leading: Icon(Icons.edit, color: _primaryColor),
              title: Text(
                "Edit Lecture",
                style: TextStyle(color: _textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditLectureScreen(
                      lectureId: lectureId,
                      initialData: occurrenceData,
                    ),
                  ),
                ).then((_) => _refreshTimetable());
              },
            ),

            // DELETE OPTION
            ListTile(
              leading: Icon(Icons.delete, color: _errorColor),
              title: Text(
                isMultipleOccurrence ? "Delete This Occurrence" : "Delete Lecture",
                style: TextStyle(color: _errorColor, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(
                  occurrenceData,
                  foundOccurrenceIndex,
                  isMultipleOccurrence,
                  allOccurrences,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _getSwapTrailingIcon(String lectureId, int occurrenceIndex) {
    final occurrenceKey = '$lectureId-$occurrenceIndex';

    if (occurrenceKey == _swapFirstKey) {
      return CircleAvatar(
        backgroundColor: _swapFirstColor,
        radius: 12,
        child: Text("1", style: TextStyle(color: Colors.white, fontSize: 10)),
      );
    } else if (occurrenceKey == _swapSecondKey) {
      return CircleAvatar(
        backgroundColor: _swapSecondColor,
        radius: 12,
        child: Text("2", style: TextStyle(color: Colors.white, fontSize: 10)),
      );
    }
    return null;
  }

  void _showDeleteConfirmation(
      Map<String, dynamic> occurrenceData,
      int occurrenceIndex,
      bool isMultipleOccurrence,
      List<LectureOccurrence> allOccurrences,
      ) {
    final lectureId = occurrenceData['id'] as String?;
    final subject = occurrenceData['subject'] as String? ?? 'Lecture';
    final occurrence = allOccurrences[occurrenceIndex];

    if (lectureId == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isMultipleOccurrence ? "🗑️ Delete Occurrence" : "🗑️ Delete Lecture",
          style: TextStyle(color: _errorColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isMultipleOccurrence
                  ? "Delete this occurrence of '$subject'?"
                  : "Are you sure you want to delete '$subject'?",
              style: TextStyle(color: _textPrimary),
            ),

            if (isMultipleOccurrence) ...[
              const SizedBox(height: 12),
              Card(
                color: _backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Occurrence Details:",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Day: ${_dayName(occurrence.dayOfWeek)}",
                        style: TextStyle(color: _textSecondary),
                      ),
                      Text(
                        "Time: ${occurrence.formattedStartTime} - ${occurrence.formattedEndTime}",
                        style: TextStyle(color: _textSecondary),
                      ),
                      if (occurrence.room != null)
                        Text(
                          "Room: ${occurrence.room}",
                          style: TextStyle(color: _textSecondary),
                        ),
                      Text(
                        "Occurrence: ${occurrenceIndex + 1} of ${allOccurrences.length}",
                        style: TextStyle(
                          color: _accentColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                "This will remove only this specific occurrence. Other occurrences will remain scheduled.",
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                "⚠️ This action cannot be undone. All attendance records and schedule history will be deleted.",
                style: TextStyle(
                  color: _errorColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _deleteLectureOrOccurrence(
              lectureId,
              occurrenceIndex,
              isMultipleOccurrence,
              occurrenceData,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  String _dayName(int dayOfWeek) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek - 1];
  }

  Future<void> _deleteLectureOrOccurrence(
      String lectureId,
      int occurrenceIndex,
      bool isMultipleOccurrence,
      Map<String, dynamic> occurrenceData,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      if (isMultipleOccurrence) {
        // Delete specific occurrence
        await _lectureService.deleteLecture(
          lectureId: lectureId,
          specificDate: DateTime.now(),
          occurrenceIndex: occurrenceIndex,
        );
      } else {
        // Delete entire lecture
        await _lectureService.deleteLecture(lectureId: lectureId);
      }

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMultipleOccurrence
                ? "✅ Occurrence deleted successfully"
                : "✅ Lecture deleted successfully",
          ),
          backgroundColor: _successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Close dialogs and refresh
      Navigator.pop(context); // Close delete confirmation
      _refreshTimetable();

    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      _showError("Failed to delete: ${e.toString()}");
    }
  }

  // ─────────────────────────────────────────
  // TIME HELPERS
  // ─────────────────────────────────────────
  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '--:--';

    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // ─────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────
  Widget _buildError(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: _errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshTimetable,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Try Again"),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty({String message = 'No data'}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 48,
            color: _textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditLectureScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Add Lecture"),
          ),
        ],
      ),
    ),
  );

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}