import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/lecture_service.dart';
import '../themes/app_themes.dart'; // Add this import

class AddEditLectureScreen extends StatefulWidget {
  final String? lectureId;
  final Map<String, dynamic>? initialData;

  const AddEditLectureScreen({
    super.key,
    this.lectureId,
    this.initialData,
  });

  @override
  State<AddEditLectureScreen> createState() => _AddEditLectureScreenState();
}

class _AddEditLectureScreenState extends State<AddEditLectureScreen> {
  final _formKey = GlobalKey<FormState>();
  final LectureService _lectureService = LectureService();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _defaultRoomController = TextEditingController();
  final TextEditingController _defaultTopicController = TextEditingController();

  // 🆕 FIXED: Proper occurrence management
  List<LectureOccurrence> _occurrences = [];
  bool _isSingleLecture = false;
  DateTime? _singleLectureDate;
  TimeOfDay? _singleStartTime;
  TimeOfDay? _singleEndTime;

  DateTime? _semesterStart;
  DateTime? _semesterEnd;

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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final now = DateTime.now();

    // Set default semester dates
    _semesterStart = DateTime(now.year, now.month < 7 ? 1 : 7, 1);
    _semesterEnd = DateTime(now.year, now.month < 7 ? 6 : 12, 30);

    if (widget.initialData != null) {
      final d = widget.initialData!;
      _subjectController.text = d['subject']?.toString() ?? '';
      _defaultRoomController.text = (d['defaultRoom'] ?? d['room'])?.toString() ?? '';
      _defaultTopicController.text = (d['defaultTopic'] ?? d['topic'])?.toString() ?? '';

      _isSingleLecture = d['isSingleLecture'] == true;

      if (_isSingleLecture) {
        _singleLectureDate = d['specificDate'] is Timestamp
            ? (d['specificDate'] as Timestamp).toDate()
            : d['specificDate'] as DateTime?;

        // Get single lecture times
        if (d['startTime'] is Map<String, dynamic>) {
          final startMap = d['startTime'] as Map<String, dynamic>;
          _singleStartTime = TimeOfDay(
            hour: startMap['hour'] ?? 9,
            minute: startMap['minute'] ?? 0,
          );
        }

        if (d['endTime'] is Map<String, dynamic>) {
          final endMap = d['endTime'] as Map<String, dynamic>;
          _singleEndTime = TimeOfDay(
            hour: endMap['hour'] ?? 10,
            minute: endMap['minute'] ?? 0,
          );
        }

        // Add single occurrence for time selection
        _occurrences.add(LectureOccurrence(
          dayOfWeek: _singleLectureDate?.weekday ?? now.weekday,
          startTime: _singleStartTime ?? TimeOfDay.now(),
          endTime: _singleEndTime ?? TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute),
        ));
      } else {
        // Load occurrences from data
        _loadOccurrencesFromData(d);
      }

      if (d['validFrom'] != null) {
        _semesterStart = d['validFrom'] is Timestamp
            ? (d['validFrom'] as Timestamp).toDate()
            : d['validFrom'] as DateTime?;
      }
      if (d['validUntil'] != null) {
        _semesterEnd = d['validUntil'] is Timestamp
            ? (d['validUntil'] as Timestamp).toDate()
            : d['validUntil'] as DateTime?;
      }
    } else {
      // Default to one occurrence with current time
      _occurrences.add(LectureOccurrence(
        dayOfWeek: DateTime.now().weekday,
        startTime: TimeOfDay.now(),
        endTime: TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute),
      ));

      // Set default single lecture times
      _singleStartTime = TimeOfDay.now();
      _singleEndTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute);
    }
  }

  void _loadOccurrencesFromData(Map<String, dynamic> data) {
    try {
      // Try to load from occurrences field (new format)
      if (data['occurrences'] is List) {
        final occurrencesList = data['occurrences'] as List<dynamic>;
        for (final item in occurrencesList) {
          if (item is Map<String, dynamic>) {
            _occurrences.add(LectureOccurrence.fromMap(item));
          }
        }
      }

      // If no occurrences loaded, try old format
      if (_occurrences.isEmpty && data['dayOfWeek'] != null) {
        final dayOfWeek = data['dayOfWeek'] as int;
        final startTime = data['startTime'] is Map<String, dynamic>
            ? TimeOfDay(
          hour: data['startTime']['hour'] ?? 9,
          minute: data['startTime']['minute'] ?? 0,
        )
            : TimeOfDay(hour: 9, minute: 0);
        final endTime = data['endTime'] is Map<String, dynamic>
            ? TimeOfDay(
          hour: data['endTime']['hour'] ?? 10,
          minute: data['endTime']['minute'] ?? 0,
        )
            : TimeOfDay(hour: 10, minute: 0);

        final room = data['room'] as String?;
        final topic = data['topic'] as String?;

        _occurrences.add(LectureOccurrence(
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          room: room,
          topic: topic,
        ));
      }
    } catch (e) {
      print('Error loading occurrences: $e');
      // Add default occurrence
      _occurrences.add(LectureOccurrence(
        dayOfWeek: DateTime.now().weekday,
        startTime: TimeOfDay.now(),
        endTime: TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute),
      ));
    }

    // Sort occurrences
    _sortOccurrences();
  }

  void _sortOccurrences() {
    _occurrences.sort((a, b) {
      if (a.dayOfWeek != b.dayOfWeek) return a.dayOfWeek.compareTo(b.dayOfWeek);
      final aStart = a.startTime.hour * 60 + a.startTime.minute;
      final bStart = b.startTime.hour * 60 + b.startTime.minute;
      return aStart.compareTo(bStart);
    });
  }

  Future<void> _saveLecture() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate subject
    if (_subjectController.text.trim().isEmpty) {
      _showError("Please enter a subject name");
      return;
    }

    if (_isSingleLecture) {
      // Validate single lecture
      if (_singleLectureDate == null) {
        _showError("Select lecture date");
        return;
      }

      if (_occurrences.isEmpty) {
        _showError("Please set lecture time");
        return;
      }

      final occurrence = _occurrences.first;
      final startMin = occurrence.startTime.hour * 60 + occurrence.startTime.minute;
      final endMin = occurrence.endTime.hour * 60 + occurrence.endTime.minute;

      if (endMin <= startMin) {
        _showError("End time must be after start time");
        return;
      }

      try {
        await _lectureService.saveSingleLecture(
          lectureId: widget.lectureId,
          subject: _subjectController.text.trim(),
          room: _defaultRoomController.text.trim(),
          topic: _defaultTopicController.text.trim(),
          date: _singleLectureDate!,
          startTime: occurrence.startTime,
          endTime: occurrence.endTime,
        );

        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        _showError("Error: $e");
      }
    } else {
      // Validate weekly lecture
      if (_occurrences.isEmpty) {
        _showError("Add at least one lecture occurrence");
        return;
      }

      if (_semesterStart == null || _semesterEnd == null) {
        _showError("Select semester start and end dates");
        return;
      }

      // Validate each occurrence
      for (final occurrence in _occurrences) {
        final startMin = occurrence.startTime.hour * 60 + occurrence.startTime.minute;
        final endMin = occurrence.endTime.hour * 60 + occurrence.endTime.minute;

        if (endMin <= startMin) {
          _showError("End time must be after start time for all occurrences");
          return;
        }
      }

      // Check for conflicts between occurrences of the same lecture
      for (int i = 0; i < _occurrences.length; i++) {
        for (int j = i + 1; j < _occurrences.length; j++) {
          final a = _occurrences[i];
          final b = _occurrences[j];

          if (a.dayOfWeek == b.dayOfWeek) {
            final aStart = a.startTime.hour * 60 + a.startTime.minute;
            final aEnd = a.endTime.hour * 60 + a.endTime.minute;
            final bStart = b.startTime.hour * 60 + b.startTime.minute;
            final bEnd = b.endTime.hour * 60 + b.endTime.minute;

            if (aStart < bEnd && aEnd > bStart) {
              _showError("Lecture cannot have overlapping occurrences on the same day");
              return;
            }
          }
        }
      }

      try {
        // Check conflicts for each occurrence
        bool hasConflict = false;
        String conflictMessage = '';

        for (final occurrence in _occurrences) {
          final conflict = await _lectureService.hasConflict(
            dayOfWeek: occurrence.dayOfWeek,
            startTime: occurrence.startTime,
            endTime: occurrence.endTime,
            editingLectureId: widget.lectureId,
            allowTemporaryOverlap: true,
          );

          if (conflict) {
            hasConflict = true;
            conflictMessage = "Conflicts on ${_dayName(occurrence.dayOfWeek)} at ${occurrence.formattedStartTime}";
            break;
          }
        }

        if (hasConflict) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Schedule Conflict"),
              content: Text(
                "$conflictMessage\n\nResolve this before finalizing timetable.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Save Anyway"),
                ),
              ],
            ),
          );

          if (proceed != true) return;
        }

        // Save with multiple occurrences
        await _lectureService.saveWeeklyLectureWithOccurrences(
          lectureId: widget.lectureId,
          subject: _subjectController.text.trim(),
          defaultRoom: _defaultRoomController.text.trim(),
          defaultTopic: _defaultTopicController.text.trim(),
          occurrences: _occurrences,
          validFrom: _semesterStart!,
          validUntil: _semesterEnd!,
        );

        // Validate final timetable
        await _lectureService.validateFinalTimetable();

        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        _showError("Error: $e");
      }
    }
  }

  void _addOccurrence() {
    setState(() {
      _occurrences.add(LectureOccurrence(
        dayOfWeek: DateTime.now().weekday,
        startTime: TimeOfDay.now(),
        endTime: TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute),
      ));
      _sortOccurrences();
    });
  }

  void _removeOccurrence(int index) {
    setState(() {
      _occurrences.removeAt(index);
    });
  }

  void _updateOccurrence(int index, LectureOccurrence updated) {
    setState(() {
      _occurrences[index] = updated;
      _sortOccurrences();
    });
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
          widget.lectureId == null ? "Add New Lecture" : "Edit Lecture",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: _textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // Lecture Type Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LECTURE TYPE",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeChip(
                          label: "Weekly",
                          icon: Icons.repeat,
                          selected: !_isSingleLecture,
                          onTap: () => setState(() => _isSingleLecture = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeChip(
                          label: "Single",
                          icon: Icons.event,
                          selected: _isSingleLecture,
                          onTap: () => setState(() => _isSingleLecture = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Subject Input
            _buildInputCard(
              title: "LECTURE DETAILS",
              children: [
                _buildTextField(
                  controller: _subjectController,
                  label: "Subject",
                  icon: Icons.subject,
                  required: true,
                  hintText: "Enter subject name",
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _defaultTopicController,
                  label: "Default Topic (Optional)",
                  icon: Icons.description,
                  hintText: "Enter default lecture topic",
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _defaultRoomController,
                  label: "Default Room",
                  icon: Icons.location_on,
                  hintText: "Enter default room number",
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isSingleLecture) ...[
              // Single lecture date selector
              _buildDateSelector(
                title: "Lecture Date",
                date: _singleLectureDate,
                onTap: _pickSingleDate,
              ),
              const SizedBox(height: 20),

              // Single lecture time selector
              if (_occurrences.isNotEmpty)
                _buildSingleTimeSelector(_occurrences.first),
              const SizedBox(height: 20),
            ],

            // Occurrences Section for Weekly lectures
            if (!_isSingleLecture) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "LECTURE OCCURRENCES",
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _addOccurrence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "A lecture can have multiple occurrences per week with different times.",
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_occurrences.isEmpty)
                      _buildEmptyOccurrences(),

                    ..._occurrences.asMap().entries.map((entry) {
                      return _buildOccurrenceCard(entry.key, entry.value);
                    }).toList(),

                    if (_occurrences.isNotEmpty)
                      _buildOccurrencesSummary(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Semester range for weekly lectures
              _buildSemesterRange(),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveLecture,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Text(
                widget.lectureId == null ? "CREATE LECTURE" : "UPDATE LECTURE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            if (widget.lectureId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _errorColor,
                  side: BorderSide(color: _errorColor.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "DELETE LECTURE",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _primaryColor.withOpacity(0.1) : _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primaryColor : _borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? _primaryColor : _textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? _primaryColor : _textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: _textPrimary,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
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
        prefixIcon: Icon(
          icon,
          size: 20,
          color: _textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: required
          ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildDateSelector({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "LECTURE DATE",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date == null
                              ? "Select date"
                              : DateFormat.yMMMMd().format(date),
                          style: TextStyle(
                            color: date == null ? _textSecondary : _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: _textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTimeSelector(LectureOccurrence occurrence) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "LECTURE TIME",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeSelector(
                  title: "Start Time",
                  time: occurrence.startTime,
                  onTap: () => _pickSingleTime(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeSelector(
                  title: "End Time",
                  time: occurrence.endTime,
                  onTap: () => _pickSingleTime(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOccurrences() {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(
              Icons.schedule,
              size: 48,
              color: _textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "No occurrences added",
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add at least one weekly occurrence",
              style: TextStyle(
                color: _textSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildOccurrenceCard(int index, LectureOccurrence occurrence) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final fullDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Occurrence ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                ),
                if (_occurrences.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete, color: _errorColor, size: 20),
                    onPressed: () => _removeOccurrence(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Day selector
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: _textSecondary),
                const SizedBox(width: 8),
                Text('Day:', style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimary)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: occurrence.dayOfWeek,
                  items: List.generate(7, (i) {
                    return DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('${days[i]} (${fullDays[i]})'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      _updateOccurrence(index, occurrence.copyWith(dayOfWeek: value));
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time selectors
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelector(
                    title: "Start Time",
                    time: occurrence.startTime,
                    onTap: () => _pickOccurrenceTime(index, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelector(
                    title: "End Time",
                    time: occurrence.endTime,
                    onTap: () => _pickOccurrenceTime(index, false),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Room override (optional)
            TextField(
              decoration: InputDecoration(
                labelText: 'Room (optional override)',
                hintText: 'Leave empty to use default room',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              controller: TextEditingController(text: occurrence.room ?? ''),
              onChanged: (value) {
                _updateOccurrence(index, occurrence.copyWith(room: value.isEmpty ? null : value));
              },
            ),

            const SizedBox(height: 8),

            // Topic override (optional)
            TextField(
              decoration: InputDecoration(
                labelText: 'Topic (optional override)',
                hintText: 'Leave empty to use default topic',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              controller: TextEditingController(text: occurrence.topic ?? ''),
              onChanged: (value) {
                _updateOccurrence(index, occurrence.copyWith(topic: value.isEmpty ? null : value));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeOfDay(time),
              style: TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildOccurrencesSummary() {
    // Group occurrences by day
    final Map<int, List<LectureOccurrence>> occurrencesByDay = {};
    for (final occurrence in _occurrences) {
      occurrencesByDay.putIfAbsent(occurrence.dayOfWeek, () => []).add(occurrence);
    }

    // Sort days
    final sortedDays = occurrencesByDay.keys.toList()..sort();

    return Card(
      color: _accentColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...sortedDays.map((day) {
              final dayOccurrences = occurrencesByDay[day]!;
              dayOccurrences.sort((a, b) {
                final aStart = a.startTime.hour * 60 + a.startTime.minute;
                final bStart = b.startTime.hour * 60 + b.startTime.minute;
                return aStart.compareTo(bStart);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayName(day),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                  ...dayOccurrences.map((occurrence) {
                    final room = occurrence.room ?? _defaultRoomController.text;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        '• ${_formatTimeOfDay(occurrence.startTime)} - ${_formatTimeOfDay(occurrence.endTime)}'
                            '${room.isNotEmpty ? ' (Room: $room)' : ''}',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 4),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterRange() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SEMESTER RANGE",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildSemesterDate(
            title: "Valid From",
            date: _semesterStart!,
            onTap: () => _pickSemesterStart(),
          ),
          const SizedBox(height: 12),
          _buildSemesterDate(
            title: "Valid Until",
            date: _semesterEnd!,
            onTap: () => _pickSemesterEnd(),
          ),
          const SizedBox(height: 8),
          Text(
            "This lecture will repeat weekly between these dates",
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterDate({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                title.contains("From") ? Icons.play_arrow : Icons.stop,
                color: _accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    DateFormat.yMMMMd().format(date),
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSingleDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      initialDate: _singleLectureDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _singleLectureDate = date;
        // Update occurrence day of week
        if (_occurrences.isNotEmpty) {
          final updated = _occurrences.first.copyWith(dayOfWeek: date.weekday);
          _occurrences[0] = updated;
        }
      });
    }
  }

  Future<void> _pickSingleTime(bool isStartTime) async {
    final currentTime = isStartTime
        ? _occurrences.first.startTime
        : _occurrences.first.endTime;

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        final occurrence = _occurrences.first;
        final updated = isStartTime
            ? occurrence.copyWith(startTime: time)
            : occurrence.copyWith(endTime: time);
        _occurrences[0] = updated;

        // Update single time variables
        if (isStartTime) {
          _singleStartTime = time;
        } else {
          _singleEndTime = time;
        }
      });
    }
  }

  Future<void> _pickOccurrenceTime(int index, bool isStartTime) async {
    final currentTime = isStartTime
        ? _occurrences[index].startTime
        : _occurrences[index].endTime;

    final time = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );

    if (time != null) {
      setState(() {
        final occurrence = _occurrences[index];
        final updated = isStartTime
            ? occurrence.copyWith(startTime: time)
            : occurrence.copyWith(endTime: time);
        _updateOccurrence(index, updated);
      });
    }
  }

  Future<void> _pickSemesterStart() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      initialDate: _semesterStart!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _semesterStart = date);
    }
  }

  Future<void> _pickSemesterEnd() async {
    final date = await showDatePicker(
      context: context,
      firstDate: _semesterStart!,
      lastDate: DateTime(2050),
      initialDate: _semesterEnd!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _cardColor,
              onSurface: _textPrimary,
            ),
            dialogBackgroundColor: _cardColor,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _semesterEnd = date);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          "Delete Lecture",
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this lecture? This action cannot be undone.",
          style: TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: _textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.lectureId != null) {
      try {
        await _lectureService.deleteLecture(lectureId: widget.lectureId!);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        _showError("Failed to delete lecture: $e");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _dayName(int dayOfWeek) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek - 1];
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _defaultRoomController.dispose();
    _defaultTopicController.dispose();
    super.dispose();
  }
}