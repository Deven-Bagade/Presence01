// lib/pages/analytics_screen.dart - ENHANCED
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/lecture_service.dart';
import '../widgets/lecture_attendance_history.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final LectureService _lectureService = LectureService();

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  // Data containers
  Map<String, dynamic> _overallStats = {};
  Map<String, Map<String, dynamic>> _subjectDetailedStats = {};
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _occurrenceStats = [];
  Map<String, List<Map<String, dynamic>>> _attendanceHistoryBySubject = {};
  Map<String, Map<String, dynamic>> _performanceTrends = {};
  List<Map<String, dynamic>> _comparativeAnalysis = [];

  // UI State
  bool _isLoading = true;
  String _selectedTab = 'overview';
  late TabController _tabController;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index == 0 ? 'overview' :
        _tabController.index == 1 ? 'subjects' : 'comparative';
      });
    });
    _loadAllAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // Parallel loading of independent data
      await Future.wait([
        _loadOverallStats(),
        _loadLectures(),
        _loadAttendanceRecords(),
      ]);

      // Sequential loading of dependent data
      await _loadSubjectDetailedStats();
      await _loadOccurrenceStats();
      await _loadAttendanceHistory();
      await _loadPerformanceTrends();
      await _loadComparativeAnalysis();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOverallStats() async {
    _overallStats = await _attendanceService.getAttendanceStats();
  }

  Future<void> _loadLectures() async {
    _lectures = await _lectureService.fetchAllLecturesOnce();
  }

  Future<void> _loadAttendanceRecords() async {
    final stream = _attendanceService.getAllAttendance();
    _attendanceRecords = await stream.first;
  }

  Future<void> _loadSubjectDetailedStats() async {
    final detailedMap = <String, Map<String, dynamic>>{};

    for (final lecture in _lectures) {
      try {
        final lectureId = lecture['id'];
        final subjectName = lecture['subject'] ?? 'Unknown Subject';

        // Get basic stats
        final basicStats = await _attendanceService.getLectureAttendanceStats(lectureId);

        // Get detailed occurrence stats
        final occurrences = await _lectureService.getAllOccurrences(lectureId);
        final occurrenceDetails = <Map<String, dynamic>>[];

        for (int i = 0; i < occurrences.length; i++) {
          final occStats = await _attendanceService.getOccurrenceAttendanceStats(
            lectureId: lectureId,
            occurrenceIndex: i,
          );

          occurrenceDetails.add({
            'index': i,
            'dayOfWeek': occurrences[i].dayOfWeek,
            'dayName': _dayName(occurrences[i].dayOfWeek),
            'timeRange': occurrences[i].timeRange,
            'room': occurrences[i].room,
            'stats': occStats,
          });
        }

        // Calculate attendance pattern by month
        final monthlyPattern = await _calculateMonthlyPattern(lectureId);

        // Calculate consistency score
        final consistency = _calculateConsistencyScore(basicStats);

        detailedMap[lectureId] = {
          'id': lectureId,
          'subject': subjectName,
          'room': lecture['room'] ?? lecture['defaultRoom'] ?? '',
          'topic': lecture['topic'] ?? lecture['defaultTopic'] ?? '',
          'isSingle': lecture['isSingleLecture'] == true,
          'isRecurring': lecture['isRecurringWeekly'] == true,
          'basicStats': basicStats,
          'occurrenceDetails': occurrenceDetails,
          'monthlyPattern': monthlyPattern,
          'consistencyScore': consistency,
          'totalOccurrences': occurrences.length,
          'schedule': lecture['validFrom'] != null && lecture['validUntil'] != null
              ? '${DateFormat('dd/MM/yy').format(lecture['validFrom'] as DateTime)} - ${DateFormat('dd/MM/yy').format(lecture['validUntil'] as DateTime)}'
              : 'Continuous',
        };
      } catch (e) {
        print('Error loading detailed stats for ${lecture['subject']}: $e');
      }
    }

    _subjectDetailedStats = detailedMap;
  }

  Future<List<Map<String, dynamic>>> _calculateMonthlyPattern(String lectureId) async {
    final months = List.generate(6, (i) {
      final date = DateTime(DateTime.now().year, DateTime.now().month - (5 - i), 1);
      return date;
    }).where((d) => d.year >= 2020).toList();

    final pattern = <Map<String, dynamic>>[];

    for (final month in months) {
      final monthEnd = DateTime(month.year, month.month + 1, 0);

      final lecturesInMonth = await _attendanceService.calculateLecturesInDateRange(
        lectureId: lectureId,
        startDate: month,
        endDate: monthEnd,
      );

      final monthAttendance = _attendanceRecords.where((record) {
        if (record['lectureId'] != lectureId) return false;
        final dateStr = record['date'] as String?;
        if (dateStr == null) return false;
        final date = _parseDate(dateStr);
        if (date == null) return false;
        return date.isAfter(month.subtract(const Duration(days: 1))) &&
            date.isBefore(monthEnd.add(const Duration(days: 1)));
      }).toList();

      final present = monthAttendance.where((r) => r['status'] == 'present').length;
      final absent = monthAttendance.where((r) => r['status'] == 'absent').length;
      final late = monthAttendance.where((r) => r['status'] == 'late').length;

      pattern.add({
        'month': DateFormat('MMM yyyy').format(month),
        'total': lecturesInMonth,
        'present': present,
        'absent': absent,
        'late': late,
        'percentage': lecturesInMonth > 0 ? ((present / lecturesInMonth) * 100).round() : 0,
        'attendanceRecords': monthAttendance,
      });
    }

    return pattern;
  }

  double _calculateConsistencyScore(Map<String, dynamic> stats) {
    final present = (stats['present'] ?? 0) as int;
    final total = (stats['totalOccurred'] ?? 1) as int;
    final percentage = stats['percentage'] ?? 0;

    if (total == 0) return 0.0;

    // Base score from percentage
    double score = (percentage / 100) * 0.6;

    // Bonus for high volume
    if (total >= 10) score += 0.1;

    // Penalty for high absence rate
    final absentRate = ((stats['absent'] ?? 0) as int) / total;
    if (absentRate > 0.3) score -= 0.1;

    return score.clamp(0.0, 1.0);
  }

  Future<void> _loadOccurrenceStats() async {
    final stats = <Map<String, dynamic>>[];

    for (final lecture in _lectures) {
      final lectureId = lecture['id'];
      final occurrences = await _lectureService.getAllOccurrences(lectureId);

      for (int i = 0; i < occurrences.length; i++) {
        final occurrence = occurrences[i];
        final occStats = await _attendanceService.getOccurrenceAttendanceStats(
          lectureId: lectureId,
          occurrenceIndex: i,
        );

        stats.add({
          'lectureId': lectureId,
          'subject': lecture['subject'],
          'occurrenceIndex': i,
          'dayOfWeek': occurrence.dayOfWeek,
          'dayName': _dayName(occurrence.dayOfWeek),
          'timeRange': occurrence.timeRange,
          'room': occurrence.room,
          'stats': occStats,
          'startTime': occurrence.formattedStartTime,
          'endTime': occurrence.formattedEndTime,
        });
      }
    }

    _occurrenceStats = stats;
  }

  Future<void> _loadAttendanceHistory() async {
    final historyMap = <String, List<Map<String, dynamic>>>{};

    for (final lecture in _lectures) {
      final lectureId = lecture['id'];
      final lectureHistory = _attendanceRecords
          .where((record) => record['lectureId']?.toString() == lectureId)
          .toList();

      // Sort by date
      lectureHistory.sort((a, b) {
        final dateA = _parseTimestamp(a['markedAt'] ?? a['date'] ?? '');
        final dateB = _parseTimestamp(b['markedAt'] ?? b['date'] ?? '');
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      historyMap[lectureId] = lectureHistory;
    }

    _attendanceHistoryBySubject = historyMap;
  }

  Future<void> _loadPerformanceTrends() async {
    final trends = <String, Map<String, dynamic>>{};
    final now = DateTime.now();

    for (final lecture in _lectures) {
      final lectureId = lecture['id'];

      // Calculate trend over last 4 weeks
      final weeklyTrend = List.generate(4, (i) async {
        final weekStart = now.subtract(Duration(days: (4 - i) * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));

        final lecturesInWeek = await _attendanceService.calculateLecturesInDateRange(
          lectureId: lectureId,
          startDate: weekStart,
          endDate: weekEnd,
        );

        final weekAttendance = _attendanceRecords.where((record) {
          if (record['lectureId'] != lectureId) return false;
          final dateStr = record['date'] as String?;
          if (dateStr == null) return false;
          final date = _parseDate(dateStr);
          if (date == null) return false;
          return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              date.isBefore(weekEnd.add(const Duration(days: 1))) &&
              record['status'] == 'present';
        }).length;

        return {
          'week': 'W${4 - i}',
          'percentage': lecturesInWeek > 0 ? ((weekAttendance / lecturesInWeek) * 100).round() : 0,
          'present': weekAttendance,
          'total': lecturesInWeek,
        };
      });

      final weeklyData = await Future.wait(weeklyTrend);

      // Calculate trend direction
      String trendDirection = 'stable';
      if (weeklyData.length >= 2) {
        final first = weeklyData.first['percentage'] as int;
        final last = weeklyData.last['percentage'] as int;
        if (last > first + 10) trendDirection = 'improving';
        else if (last < first - 10) trendDirection = 'declining';
      }

      trends[lectureId] = {
        'weeklyTrend': weeklyData,
        'trendDirection': trendDirection,
        'averageWeekly': weeklyData.isNotEmpty
            ? weeklyData.map((w) => w['percentage'] as int).reduce((a, b) => a + b) ~/ weeklyData.length
            : 0,
      };
    }

    _performanceTrends = trends;
  }

  Future<void> _loadComparativeAnalysis() async {
    final analysis = <Map<String, dynamic>>[];

    // Sort subjects by performance
    final subjectsByPerformance = _subjectDetailedStats.entries.toList()
      ..sort((a, b) => (b.value['basicStats']['percentage'] ?? 0).compareTo(a.value['basicStats']['percentage'] ?? 0));

    // Best performing
    if (subjectsByPerformance.isNotEmpty) {
      final best = subjectsByPerformance.first;
      analysis.add({
        'type': 'best',
        'subject': best.value['subject'],
        'percentage': best.value['basicStats']['percentage'] ?? 0,
        'stats': best.value['basicStats'],
        'reason': 'Highest attendance percentage',
      });
    }

    // Worst performing
    if (subjectsByPerformance.length > 1) {
      final worst = subjectsByPerformance.last;
      if ((worst.value['basicStats']['percentage'] ?? 0) < 70) {
        analysis.add({
          'type': 'worst',
          'subject': worst.value['subject'],
          'percentage': worst.value['basicStats']['percentage'] ?? 0,
          'stats': worst.value['basicStats'],
          'reason': 'Needs improvement',
        });
      }
    }

    // Most consistent
    final mostConsistent = subjectsByPerformance
        .where((e) => (e.value['basicStats']['totalOccurred'] ?? 0) >= 5)
        .toList()
      ..sort((a, b) => (b.value['consistencyScore'] ?? 0.0).compareTo(a.value['consistencyScore'] ?? 0.0));

    if (mostConsistent.isNotEmpty) {
      analysis.add({
        'type': 'consistent',
        'subject': mostConsistent.first.value['subject'],
        'consistency': mostConsistent.first.value['consistencyScore'] ?? 0.0,
        'stats': mostConsistent.first.value['basicStats'],
        'reason': 'Most consistent attendance pattern',
      });
    }

    // Most attended day
    final dayStats = <int, Map<String, dynamic>>{};
    for (final occ in _occurrenceStats) {
      final day = occ['dayOfWeek'] as int;
      final stats = occ['stats'] as Map<String, dynamic>;
      dayStats.putIfAbsent(day, () => {'present': 0, 'total': 0, 'count': 0});
      dayStats[day]!['present'] = (dayStats[day]!['present'] ?? 0) + (stats['present'] ?? 0);
      dayStats[day]!['total'] = (dayStats[day]!['total'] ?? 0) + (stats['totalOccurred'] ?? 0);
      dayStats[day]!['count'] = (dayStats[day]!['count'] ?? 0) + 1;
    }

    if (dayStats.isNotEmpty) {
      final bestDayEntry = dayStats.entries.reduce((a, b) {
        final aPercentage = a.value['total'] > 0 ? (a.value['present'] / a.value['total']) : 0;
        final bPercentage = b.value['total'] > 0 ? (b.value['present'] / b.value['total']) : 0;
        return aPercentage > bPercentage ? a : b;
      });

      analysis.add({
        'type': 'best_day',
        'day': _dayName(bestDayEntry.key),
        'percentage': bestDayEntry.value['total'] > 0
            ? ((bestDayEntry.value['present'] / bestDayEntry.value['total']) * 100).round()
            : 0,
        'reason': 'Highest attendance rate',
      });
    }

    _comparativeAnalysis = analysis;
  }

  Widget _buildDetailedSubjectCard(Map<String, dynamic> subjectData) {
    final basicStats = subjectData['basicStats'] as Map<String, dynamic>;
    final percentage = basicStats['percentage'] ?? 0;
    final present = basicStats['present'] ?? 0;
    final total = basicStats['totalOccurred'] ?? 0;
    final occurrences = subjectData['occurrenceDetails'] as List<dynamic>;
    final monthlyPattern = subjectData['monthlyPattern'] as List<Map<String, dynamic>>;
    final trend = _performanceTrends[subjectData['id']];

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectData['subject'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subjectData['room'] ?? 'No room',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPercentageBadge(percentage),
              ],
            ),

            const SizedBox(height: 16),

            // Quick Stats
            _buildQuickStatsRow(basicStats),

            const SizedBox(height: 16),

            // Occurrence Breakdown
            if (occurrences.isNotEmpty) ...[
              const Text(
                'Occurrence Breakdown:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              ...occurrences.map<Widget>((occ) {
                final occStats = occ['stats'] as Map<String, dynamic>;
                final occPercentage = occStats['percentage'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${occ['dayName']} ${occ['timeRange']}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '$occPercentage%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getColorForPercentage(occPercentage),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            // Monthly Pattern
            if (monthlyPattern.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Monthly Pattern:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: monthlyPattern.map((month) {
                    final monthPercentage = month['percentage'] as int;
                    return Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Text(
                            month['month'].toString().split(' ')[0],
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 20,
                            width: 40,
                            decoration: BoxDecoration(
                              color: _getColorForPercentage(monthPercentage),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '$monthPercentage%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Trend
            if (trend != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Trend: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Icon(
                    trend['trendDirection'] == 'improving' ? Icons.trending_up :
                    trend['trendDirection'] == 'declining' ? Icons.trending_down :
                    Icons.trending_flat,
                    color: trend['trendDirection'] == 'improving' ? Colors.green :
                    trend['trendDirection'] == 'declining' ? Colors.red :
                    Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trend['trendDirection'].toString().toUpperCase(),
                    style: TextStyle(
                      color: trend['trendDirection'] == 'improving' ? Colors.green :
                      trend['trendDirection'] == 'declining' ? Colors.red :
                      Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('View History'),
                    onPressed: () {
                      _showSubjectHistory(
                        subjectData['id'] as String,
                        subjectData['subject'] as String,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.insights, size: 16),
                    label: const Text('Deep Analysis'),
                    onPressed: () {
                      _showDeepAnalysis(subjectData);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow(Map<String, dynamic> stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMiniStat(
          title: 'Present',
          value: '${stats['present'] ?? 0}',
          color: Colors.green,
        ),
        _buildMiniStat(
          title: 'Absent',
          value: '${stats['absent'] ?? 0}',
          color: Colors.red,
        ),
        _buildMiniStat(
          title: 'Late',
          value: '${stats['late'] ?? 0}',
          color: Colors.orange,
        ),
        _buildMiniStat(
          title: 'Pending',
          value: '${stats['pending'] ?? 0}',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPercentageBadge(int percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getColorForPercentage(percentage).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getColorForPercentage(percentage),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percentage%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getColorForPercentage(percentage),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            percentage >= 75 ? Icons.check_circle :
            percentage >= 60 ? Icons.warning :
            Icons.error,
            size: 16,
            color: _getColorForPercentage(percentage),
          ),
        ],
      ),
    );
  }

  void _showSubjectHistory(String lectureId, String lectureName) {
    showDialog(
      context: context,
      builder: (context) => LectureAttendanceHistory(
        lectureId: lectureId,
        lectureName: lectureName,
      ),
    );
  }

  void _showDeepAnalysis(Map<String, dynamic> subjectData) {
    final basicStats = subjectData['basicStats'] as Map<String, dynamic>;
    final percentage = basicStats['percentage'] ?? 0;
    final occurrences = subjectData['occurrenceDetails'] as List<dynamic>;
    final monthlyPattern = subjectData['monthlyPattern'] as List<Map<String, dynamic>>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deep Analysis: ${subjectData['subject']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Overall Score
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Overall Performance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _getColorForPercentage(percentage),
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey[200],
                          color: _getColorForPercentage(percentage),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${basicStats['present'] ?? 0} of ${basicStats['totalOccurred'] ?? 0} lectures attended',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Occurrence Analysis
                if (occurrences.isNotEmpty) ...[
                  const Text(
                    'Occurrence Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...occurrences.map<Widget>((occ) {
                    final occStats = occ['stats'] as Map<String, dynamic>;
                    final occPercentage = occStats['percentage'] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${occ['dayName']} ${occ['timeRange']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Attendance: ${occStats['present'] ?? 0}/${occStats['totalOccurred'] ?? 0}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Text(
                                  '$occPercentage%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getColorForPercentage(occPercentage),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: occPercentage / 100,
                              backgroundColor: Colors.grey[200],
                              color: _getColorForPercentage(occPercentage),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],

                // Monthly Analysis
                if (monthlyPattern.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Monthly Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: monthlyPattern.map((month) {
                        final monthPercentage = month['percentage'] as int;
                        final present = month['present'] as int;
                        final total = month['total'] as int;

                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    month['month'].toString(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getColorForPercentage(monthPercentage),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$monthPercentage%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$present/$total',
                                    style: const TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

// Recommendations
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Build recommendations list
                        ...[
                          if (percentage < 75)
                            _buildRecommendation(
                              icon: Icons.warning,
                              color: Colors.orange,
                              text: 'Attendance below target (75%). Consider improving.',
                            ),
                          if (percentage >= 85)
                            _buildRecommendation(
                              icon: Icons.star,
                              color: Colors.green,
                              text: 'Excellent attendance! Keep up the good work.',
                            ),
                          if (occurrences.isNotEmpty) ...[
                                () {
                              final worstOcc = occurrences.reduce((a, b) {
                                final aPerc = (a['stats']['percentage'] ?? 0) as int;
                                final bPerc = (b['stats']['percentage'] ?? 0) as int;
                                return aPerc < bPerc ? a : b;
                              });
                              if ((worstOcc['stats']['percentage'] ?? 0) < 60) {
                                return _buildRecommendation(
                                  icon: Icons.schedule,
                                  color: Colors.red,
                                  text: 'Focus on ${worstOcc['dayName']} ${worstOcc['timeRange']} - lowest attendance',
                                );
                              }
                              return const SizedBox.shrink();
                            }(),
                          ],
                        ].where((widget) => widget is! SizedBox || (widget as SizedBox).child != null),
                      ],
                    ),
                  ),
                ),
        ],
        ),
        );
      },
    );
  }

  Widget _buildRecommendation({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativeAnalysisView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Best vs Worst
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performance Comparison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._comparativeAnalysis.where((a) => ['best', 'worst'].contains(a['type'])).map((analysis) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          analysis['type'] == 'best' ? Icons.emoji_events : Icons.warning,
                          color: analysis['type'] == 'best' ? Colors.amber : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                analysis['type'] == 'best' ? 'Best Performer' : 'Needs Attention',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: analysis['type'] == 'best' ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                '${analysis['subject']} - ${analysis['percentage']}%',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Day Analysis
        if (_comparativeAnalysis.any((a) => a['type'] == 'best_day')) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Best Day',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _comparativeAnalysis.firstWhere((a) => a['type'] == 'best_day')['day'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Highest attendance rate',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_comparativeAnalysis.firstWhere((a) => a['type'] == 'best_day')['percentage']}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Consistency Analysis
        if (_comparativeAnalysis.any((a) => a['type'] == 'consistent')) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Most Consistent',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.trending_flat, color: Colors.purple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _comparativeAnalysis.firstWhere((a) => a['type'] == 'consistent')['subject'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Most reliable attendance pattern',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${((_comparativeAnalysis.firstWhere((a) => a['type'] == 'consistent')['consistency'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Advanced Analytics"),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Subject Details'),
              Tab(text: 'Comparative'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllAnalytics,
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: () async {
                final newRange = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _dateRange,
                );
                if (newRange != null) {
                  setState(() => _dateRange = newRange);
                  _loadAllAnalytics();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          controller: _tabController,
          children: [
            // Overview Tab
            SingleChildScrollView(
              child: Column(
                children: [
                  // Overall Stats
                  _buildOverallStatsCard(),

                  // Performance Summary
                  if (_comparativeAnalysis.isNotEmpty)
                    _buildPerformanceSummary(),

                  // Subject Performance Overview
                  if (_subjectDetailedStats.isNotEmpty)
                    _buildSubjectPerformanceOverview(),
                ],
              ),
            ),

            // Subject Details Tab
            _subjectDetailedStats.isEmpty
                ? const Center(child: Text("No subjects found"))
                : ListView.builder(
              itemCount: _subjectDetailedStats.length,
              itemBuilder: (context, index) {
                final subjectKey = _subjectDetailedStats.keys.elementAt(index);
                return _buildDetailedSubjectCard(_subjectDetailedStats[subjectKey]!);
              },
            ),

            // Comparative Tab
            _buildComparativeAnalysisView(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatsCard() {
    final percentage = _overallStats['percentage'] ?? 0;
    final present = _overallStats['present'] ?? 0;
    final total = _overallStats['total'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Overall Attendance",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "$percentage%",
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _getColorForPercentage(percentage),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$present of $total lectures",
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Detailed breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCircle(
                  value: present,
                  label: 'Present',
                  color: Colors.green,
                  total: total,
                ),
                _buildStatCircle(
                  value: _overallStats['absent'] ?? 0,
                  label: 'Absent',
                  color: Colors.red,
                  total: total,
                ),
                _buildStatCircle(
                  value: _overallStats['late'] ?? 0,
                  label: 'Late',
                  color: Colors.orange,
                  total: total,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCircle({
    required int value,
    required String label,
    required Color color,
    required int total,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: total > 0 ? value / total : 0,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.2),
                color: color,
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSummary() {
    final bestSubject = _comparativeAnalysis.firstWhere(
          (a) => a['type'] == 'best',
      orElse: () => {},
    );
    final worstSubject = _comparativeAnalysis.firstWhere(
          (a) => a['type'] == 'worst',
      orElse: () => {},
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (bestSubject.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best: ${bestSubject['subject']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${bestSubject['percentage']}% attendance',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (worstSubject.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Needs Attention: ${worstSubject['subject']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${worstSubject['percentage']}% attendance',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPerformanceOverview() {
    final subjects = _subjectDetailedStats.values.toList()
      ..sort((a, b) => (b['basicStats']['percentage'] ?? 0).compareTo(a['basicStats']['percentage'] ?? 0));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject Performance Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sorted by attendance percentage',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            ...subjects.take(5).map((subject) {
              final stats = subject['basicStats'] as Map<String, dynamic>;
              final percentage = stats['percentage'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subject['subject'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '$percentage%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getColorForPercentage(percentage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      color: _getColorForPercentage(percentage),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }).toList(),

            if (subjects.length > 5) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Text(
                  '${subjects.length - 5} more subjects...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper Methods
  Color _getColorForPercentage(int percentage) {
    if (percentage >= 85) return Colors.green;
    if (percentage >= 75) return Colors.lightGreen;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _dayName(int dayOfWeek) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek - 1];
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return null;
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) return DateTime.parse(timestamp);
      if (timestamp is Map && timestamp.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          (timestamp['_seconds'] as int) * 1000,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}