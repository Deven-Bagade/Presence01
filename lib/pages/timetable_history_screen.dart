import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/timetable_history_service.dart';
import '../themes/app_themes.dart'; // Add this import

class TimetableHistoryScreen extends StatefulWidget {
  final String? lectureId;
  final String? lectureName;

  const TimetableHistoryScreen({
    super.key,
    this.lectureId,
    this.lectureName,
  });

  @override
  State<TimetableHistoryScreen> createState() => _TimetableHistoryScreenState();
}

class _TimetableHistoryScreenState extends State<TimetableHistoryScreen> {
  final TimetableHistoryService _historyService = TimetableHistoryService();
  String _filter = 'all'; // all, create, update, move, swap, delete
  late Stream<List<Map<String, dynamic>>> _historyStream;

  // 🆕 Color scheme from theme provider
  Color get _primaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.primary;
  Color get _secondaryColor => Provider.of<ThemeProvider>(context, listen: false).themeData.secondary;
  Color get _accentColor => Provider.of<ThemeProvider>(context, listen: false).themeData.accent;
  Color get _backgroundColor => Provider.of<ThemeProvider>(context, listen: false).themeData.background;
  Color get _cardColor => Provider.of<ThemeProvider>(context, listen: false).themeData.card;
  Color get _textPrimary => Provider.of<ThemeProvider>(context, listen: false).themeData.textPrimary;
  Color get _textSecondary => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary;
  Color get _borderColor => Provider.of<ThemeProvider>(context, listen: false).themeData.textSecondary.withOpacity(0.2);

  // 🆕 Status colors
  Color get _successColor => AppThemeData.presentColor; // Green
  Color get _errorColor => AppThemeData.absentColor;    // Red
  Color get _warningColor => AppThemeData.lateColor;    // Amber

  @override
  void initState() {
    super.initState();
    // Initialize the stream based on whether we're viewing lecture-specific or all history
    _historyStream = widget.lectureId != null
        ? _historyService.getLectureHistory(widget.lectureId!)
        : _historyService.getTimetableHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: Text(
          widget.lectureName != null
              ? 'History: ${widget.lectureName}'
              : 'Timetable History',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _historyStream,
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
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: _errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading history',
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
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          size: 64,
                          color: _textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history available',
                          style: TextStyle(
                            fontSize: 16,
                            color: _textSecondary,
                          ),
                        ),
                        if (_filter != 'all')
                          Text(
                            'Try selecting "All" filter',
                            style: TextStyle(color: _textSecondary),
                          ),
                      ],
                    ),
                  );
                }

                var history = snapshot.data!;

                // Debug: Print received data
                print('Received ${history.length} history items');
                if (history.isNotEmpty) {
                  print('First item: ${history.first}');
                }

                // Apply filter
                if (_filter != 'all') {
                  history = history.where((item) => item['action'] == _filter).toList();
                  print('After filter "$_filter": ${history.length} items');
                }

                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 64,
                          color: _textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No "$_filter" history found',
                          style: TextStyle(
                            fontSize: 16,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() => _filter = 'all'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor.withOpacity(0.1),
                            foregroundColor: _primaryColor,
                          ),
                          child: const Text('Show All'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _primaryColor,
                  backgroundColor: _cardColor,
                  onRefresh: () async {
                    // Force refresh by updating the stream
                    setState(() {
                      _historyStream = widget.lectureId != null
                          ? _historyService.getLectureHistory(widget.lectureId!)
                          : _historyService.getTimetableHistory();
                    });
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryItem(history[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'create', 'label': 'Created'},
      {'value': 'update', 'label': 'Updated'},
      {'value': 'move', 'label': 'Moved'},
      {'value': 'swap', 'label': 'Swapped'},
      {'value': 'delete', 'label': 'Deleted'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          final isSelected = _filter == filter['value'];

          Color chipColor = _primaryColor;
          if (filter['value'] == 'create') chipColor = _successColor;
          else if (filter['value'] == 'delete') chipColor = _errorColor;
          else if (filter['value'] == 'swap') chipColor = _accentColor;
          else if (filter['value'] == 'move') chipColor = _warningColor;

          return ChoiceChip(
            label: Text(
              filter['label']!,
              style: TextStyle(
                color: isSelected ? Colors.white : _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => setState(() => _filter = filter['value']!),
            selectedColor: chipColor,
            backgroundColor: chipColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? chipColor : _borderColor,
                width: isSelected ? 0 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final action = item['action'] as String? ?? 'unknown';
    final timestamp = item['timestamp'];
    final reason = item['reason'] as String?;
    final subject = item['lectureSubject'] as String? ?? 'Unknown Lecture';

    Color color = _textSecondary;
    IconData icon = Icons.history;

    switch (action) {
      case 'create':
        color = _successColor;
        icon = Icons.add_circle;
        break;
      case 'update':
        color = _primaryColor;
        icon = Icons.edit;
        break;
      case 'move':
        color = _warningColor;
        icon = Icons.move_to_inbox;
        break;
      case 'swap':
        color = _accentColor;
        icon = Icons.swap_horiz;
        break;
      case 'delete':
        color = _errorColor;
        icon = Icons.delete;
        break;
    }

    // Handle timestamp conversion
    DateTime? displayDate;
    if (timestamp != null) {
      if (timestamp is Timestamp) {
        displayDate = timestamp.toDate();
      } else if (timestamp is DateTime) {
        displayDate = timestamp;
      } else if (timestamp is Map<String, dynamic>) {
        // Handle Firestore timestamp format
        final seconds = timestamp['_seconds'] as int?;
        if (seconds != null) {
          displayDate = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _actionText(action, subject),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (displayDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('MMM dd, HH:mm').format(displayDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reason: $reason',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],

            if (item['newData'] != null && item['newData'] is Map) ...[
              const SizedBox(height: 12),
              Text(
                'Changes:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentColor.withOpacity(0.2)),
                ),
                child: Text(
                  _formatChanges(item['newData'] as Map<String, dynamic>),
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],

            if (item['previousData'] != null && item['previousData'] is Map) ...[
              const SizedBox(height: 8),
              Text(
                'Previous:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  _formatPreviousData(item['previousData'] as Map<String, dynamic>),
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _actionText(String action, String subject) {
    switch (action) {
      case 'create':
        return 'Lecture created: $subject';
      case 'update':
        return 'Lecture updated: $subject';
      case 'move':
        return 'Lecture moved: $subject';
      case 'swap':
        return 'Lectures swapped with $subject';
      case 'delete':
        return 'Lecture deleted: $subject';
      default:
        return 'Action: $action - $subject';
    }
  }

  String _formatChanges(Map<String, dynamic> data) {
    final changes = <String>[];

    // Handle daysOfWeek
    if (data['daysOfWeek'] != null) {
      if (data['daysOfWeek'] is List) {
        final days = List<int>.from(data['daysOfWeek'] as List);
        final dayNames = days.map((day) => _dayName(day)).join(', ');
        changes.add('Days: $dayNames');
      }
    }

    // Handle occurrences
    if (data['occurrences'] != null && data['occurrences'] is List) {
      final occurrences = data['occurrences'] as List;
      changes.add('${occurrences.length} occurrence(s)');
    }

    // Handle startTime
    if (data['startTime'] != null && data['startTime'] is Map) {
      final time = data['startTime'] as Map<String, dynamic>;
      final hour = time['hour'] ?? 0;
      final minute = time['minute'] ?? 0;
      changes.add('Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    }

    // Handle subject
    if (data['subject'] != null) {
      changes.add('Subject: ${data['subject']}');
    }

    // Handle room/topic
    if (data['defaultRoom'] != null) changes.add('Room: ${data['defaultRoom']}');
    if (data['defaultTopic'] != null) changes.add('Topic: ${data['defaultTopic']}');

    return changes.isNotEmpty ? changes.join(', ') : 'No detailed changes';
  }

  String _formatPreviousData(Map<String, dynamic> data) {
    final info = <String>[];

    if (data['subject'] != null) info.add('Subject: ${data['subject']}');
    if (data['daysOfWeek'] != null && data['daysOfWeek'] is List) {
      final days = List<int>.from(data['daysOfWeek'] as List);
      info.add('Days: ${days.length}');
    }

    return info.isNotEmpty ? info.join(', ') : 'Previous data';
  }

  String _dayName(int dayOfWeek) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayOfWeek >= 1 && dayOfWeek <= 7 ? days[dayOfWeek - 1] : 'Day $dayOfWeek';
  }
}