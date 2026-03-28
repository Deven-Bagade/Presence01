// lib/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../services/lecture_service.dart';
import '../services/attendance_service.dart';
import '../widgets/attendance_dialog.dart';
import './add_lecture_screen.dart';
import '../themes/app_themes.dart'; // Add this import


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LectureService _lectureService = LectureService();
  final AttendanceService _attendanceService = AttendanceService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (_isDisposed) return;
        setState(() {
          _isLoading = false;
          _error = 'Not logged in';
        });
        return;
      }

      await _attendanceService.autoMarkPresentForMissed();
      final s = await _attendanceService.getAttendanceStats();

      if (_isDisposed) return;
      setState(() {
        _stats = s;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (_isDisposed) return;
      setState(() {
        _isLoading = false;
        _error = 'Error loading home data: $e';
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeData;
    final user = _auth.currentUser;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your schedule...',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.card,
          elevation: 0,
          title: Text(
            "Home",
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.card,
        elevation: 0,
        title: Text(
          'Attendigo',
          style: TextStyle(
            color: theme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: theme.primary,
        backgroundColor: theme.card,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user, theme),
              const SizedBox(height: 16),
              _buildQuickStats(theme),
              const SizedBox(height: 24),
              _buildWeeklyPreview(theme),
              const SizedBox(height: 24),
              _buildTodaysSchedule(theme),
              const SizedBox(height: 24),
              _buildRecentActivity(theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user, AppThemeData theme) {
    final name = user?.displayName ?? "Student";
    final email = user?.email ?? "";

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : "S",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Good ${_getTimeOfDayGreeting()},",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(AppThemeData theme) {
    final percent = _stats['percentage'] ?? 0;
    final present = _stats['present'] ?? 0;
    final total = _stats['total'] ?? 0;

    Color color = AppThemeData.absentColor;
    String status = "Low";
    if (percent >= 85) {
      color = AppThemeData.presentColor;
      status = "Excellent";
    } else if (percent >= 75) {
      color = AppThemeData.lateColor;
      status = "Good";
    } else if (percent >= 60) {
      color = AppThemeData.lateColor;
      status = "Fair";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.trending_up,
                  color: color,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ATTENDANCE OVERVIEW",
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "$percent%",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$present of $total lectures",
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: percent / 100,
                    backgroundColor: theme.background,
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyPreview(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: StreamBuilder<Map<int, List<Map<String, dynamic>>>>(
              stream: _lectureService.getWeeklyTimetableStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final map = snapshot.data!;
                final List<String> days = ["M", "T", "W", "T", "F", "S", "S"];
                final List<String> fullDays = [
                  "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
                ];
                final int today = DateTime.now().weekday - 1;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    final dayLectures = map[day] ?? [];

                    final Set<String> uniqueLectureIds = {};
                    for (final lecture in dayLectures) {
                      uniqueLectureIds.add(lecture['id'] as String? ?? '');
                    }

                    final count = uniqueLectureIds.length;
                    final isToday = index == today;

                    return Column(
                      children: [
                        Text(
                          days[index],
                          style: TextStyle(
                            color: isToday ? theme.primary : theme.textSecondary,
                            fontSize: 14,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isToday
                                ? theme.primary
                                : count > 0
                                ? theme.accent.withOpacity(0.1)
                                : theme.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isToday
                                  ? theme.primary
                                  : count > 0
                                  ? theme.accent.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "$count",
                              style: TextStyle(
                                color: isToday
                                    ? Colors.white
                                    : count > 0
                                    ? theme.accent
                                    : theme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fullDays[index],
                          style: TextStyle(
                            color: isToday ? theme.primary : theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSchedule(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "TODAY'S SCHEDULE",
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _lectureService.getTodaysLecturesStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.card,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                    ),
                  ),
                );
              }

              final lectures = snapshot.data!;
              if (lectures.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.calendar_today_outlined,
                  title: "No lectures today",
                  subtitle: "Enjoy your free time!",
                  theme: theme,
                );
              }

              return Column(
                children: lectures.map((lecture) => _buildLectureCard(lecture, theme)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCard(Map<String, dynamic> lecture, AppThemeData theme) {
    final id = lecture['id'];
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _attendanceService.getLectureAttendanceStream(
        lectureId: id,
        date: date,
      ),
      builder: (context, snapshot) {
        final att = snapshot.data;
        final status = att?['status'] ?? "pending";
        final subject = lecture['subject'] ?? "Untitled";

        Color statusColor = theme.textSecondary;
        IconData statusIcon = Icons.access_time;
        String statusText = "PENDING";

        if (status == 'present') {
          statusColor = AppThemeData.presentColor;
          statusIcon = Icons.check_circle;
          statusText = "PRESENT";
        } else if (status == 'absent') {
          statusColor = AppThemeData.absentColor;
          statusIcon = Icons.cancel;
          statusText = "ABSENT";
        } else if (status == 'late') {
          statusColor = AppThemeData.lateColor;
          statusIcon = Icons.watch_later;
          statusText = "LATE";
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
            elevation: 0,
            child: InkWell(
              onTap: () => _openAttendanceDialog(lecture),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: theme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${_formatTime(lecture['startDateTime'])} - ${_formatTime(lecture['endDateTime'])}",
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: theme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  lecture['location'] ?? "No location",
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(AppThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "RECENT ACTIVITY",
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.card,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _attendanceService.getRecentActivityStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                    ),
                  );
                }

                final list = snapshot.data!;
                if (list.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.history,
                    title: "No recent activity",
                    subtitle: "Your attendance updates will appear here",
                    theme: theme,
                  );
                }

                return Column(
                  children: list
                      .take(3)
                      .map((activity) => _buildActivityItem(activity, theme))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, AppThemeData theme) {
    final status = activity['status'];
    final subject = activity['lectureSubject'] ?? "Lecture";
    final reason = activity['reason'];
    final autoMarked = activity['autoMarked'] == true;

    Color iconColor = theme.textSecondary;
    IconData icon = Icons.access_time;
    String statusText = "Pending";

    if (status == 'present') {
      iconColor = AppThemeData.presentColor;
      icon = Icons.check_circle;
      statusText = "Present";
    } else if (status == 'absent') {
      iconColor = AppThemeData.absentColor;
      icon = Icons.cancel;
      statusText = "Absent";
    } else if (status == 'late') {
      iconColor = AppThemeData.lateColor;
      icon = Icons.watch_later;
      statusText = "Late";
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  autoMarked
                      ? "Auto-marked as $statusText"
                      : reason ?? statusText,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatTime(DateTime.now()),
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.card,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  String _getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  void _openAttendanceDialog(Map<String, dynamic> lecture) async {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);

    final attendanceStream = _attendanceService.getLectureAttendanceStream(
      lectureId: lecture['id'],
      date: date,
    );

    final att = await attendanceStream.first;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AttendanceDialog(
        lecture: lecture,
        date: date,
        onUpdated: _load,
      ),
    );
  }
}