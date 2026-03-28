// lib/services/attendance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'lecture_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _attendanceRef =>
      _firestore.collection('users').doc(_uid!).collection('attendance');

  CollectionReference get _overrideRef =>
      _firestore.collection('users').doc(_uid!).collection('lecture_overrides');

  // =========================================================
  // 🔑 UNIFIED KEY GENERATION SYSTEM
  // =========================================================
  String _generateKey({
    required String lectureId,
    required DateTime date,
    int? occurrenceIndex,
  }) {
    final dateStr = _formatDate(date);
    if (occurrenceIndex != null) {
      return '$lectureId-$dateStr-occ$occurrenceIndex';
    }
    return '$lectureId-$dateStr';
  }

  // Backward compatibility
  String _key(String lectureId, DateTime d) =>
      _generateKey(lectureId: lectureId, date: d);

  String _keyWithOccurrence(String lectureId, DateTime d, int occurrenceIndex) =>
      _generateKey(lectureId: lectureId, date: d, occurrenceIndex: occurrenceIndex);

  // =========================================================
  // 🎯 SINGLE ATTENDANCE STREAM (USED BY TIMETABLE)
  // =========================================================
  Stream<Map<String, dynamic>?> getLectureAttendanceStream({
    required String lectureId,
    required DateTime date,
    int? occurrenceIndex,
  }) {
    if (_uid == null) return Stream.value(null);

    final key = _generateKey(lectureId: lectureId, date: date, occurrenceIndex: occurrenceIndex);

    return _attendanceRef.doc(key).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {...(doc.data() as Map<String, dynamic>), 'id': doc.id};
    });
  }

  // =========================================================
  // 📋 ALL ATTENDANCE FOR A LECTURE (USED BY HISTORY)
  // =========================================================
  Stream<List<Map<String, dynamic>>> getAllAttendanceForLecture(
      String lectureId,
      ) {
    if (_uid == null) return Stream.value([]);

    return _attendanceRef
        .where('lectureId', isEqualTo: lectureId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();
    });
  }

  // =========================================================
  // ✅ MARK ATTENDANCE (MANUAL / AUTO) - FIXED
  // =========================================================
  Future<void> markAttendance({
    required String lectureId,
    required DateTime date,
    required String status, // present | absent | late
    String? reason,
    String? notes,
    bool autoMarked = false,
    int? occurrenceIndex,
  }) async {
    if (_uid == null) return;

    // Validate status
    if (!['present', 'absent', 'late'].contains(status)) {
      throw Exception('Invalid attendance status: $status');
    }

    // ❌ Do not mark if cancelled / holiday
    final override = await getOverrideOnce(
      lectureId: lectureId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    if (override != null) {
      print('Skipping attendance - lecture cancelled/holiday');
      return;
    }

    // Generate correct key
    final key = _generateKey(
        lectureId: lectureId,
        date: date,
        occurrenceIndex: occurrenceIndex
    );

    final attendanceData = {
      'lectureId': lectureId,
      'date': _formatDate(date),
      'status': status,
      'reason': reason,
      'notes': notes,
      'autoMarked': autoMarked,
      'occurrenceIndex': occurrenceIndex,
      'timestamp': FieldValue.serverTimestamp(),
    };

    print('Marking attendance: $attendanceData');

    await _attendanceRef.doc(key).set(attendanceData, SetOptions(merge: true));
  }

  // Alias for backward compatibility
  Future<void> markAttendanceForOccurrence({
    required String lectureId,
    required DateTime date,
    required int occurrenceIndex,
    required String status,
    String? reason,
    String? notes,
    bool autoMarked = false,
  }) async {
    await markAttendance(
      lectureId: lectureId,
      date: date,
      status: status,
      reason: reason,
      notes: notes,
      autoMarked: autoMarked,
      occurrenceIndex: occurrenceIndex,
    );
  }

  // =========================================================
  // 🔄 AUTO-MARK PRESENT FOR MISSED - FIXED
  // =========================================================
  Future<void> autoMarkPresentForMissed() async {
    if (_uid == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    print('🔄 Auto-marking for missed lectures before $today');

    final lecturesRef = _firestore.collection('users').doc(_uid!).collection('lectures');
    final snap = await lecturesRef.get();

    int totalAutoMarked = 0;
    int totalSkipped = 0;
    int totalErrors = 0;

    for (final doc in snap.docs) {
      final lectureId = doc.id;
      final lectureData = Map<String, dynamic>.from(doc.data());

      print('\n📚 Checking lecture: ${lectureData['subject']} (ID: $lectureId)');

      // Skip single lectures
      if (lectureData['isSingleLecture'] == true) {
        print('  ⏭️ Skipping single lecture');
        continue;
      }

      // Skip if not recurring weekly
      if (lectureData['isRecurringWeekly'] != true) {
        print('  ⏭️ Skipping non-recurring lecture');
        continue;
      }

      try {
        final lectureService = LectureService();
        final versions = await lectureService.getLectureScheduleVersions(lectureId);

        if (versions.isEmpty) {
          print('  ⚠️ No schedule versions found');
          continue;
        }

        print('  📅 Found ${versions.length} schedule versions');

        for (final version in versions) {
          // Get all occurrence dates for this version
          final occurrenceDates = _calculateOccurrenceDatesForVersion(
            version: version,
            beforeDate: today,
          );

          if (occurrenceDates.isEmpty) {
            print('  📭 No occurrence dates before today');
            continue;
          }

          print('  📆 Found ${occurrenceDates.length} occurrence dates before today');

          for (final occurrenceDate in occurrenceDates) {
            // Skip if not before today
            if (!occurrenceDate.isBefore(today)) continue;

            // Get occurrences for this specific date
            final dateOccurrences = _getOccurrencesForDate(
              version: version,
              date: occurrenceDate,
            );

            for (final occurrenceInfo in dateOccurrences) {
              final occurrenceIndex = occurrenceInfo['index'] as int;
              final occurrence = occurrenceInfo['occurrence'] as LectureOccurrence;

              // Generate unique key for this specific occurrence
              final occurrenceKey = _generateKey(
                lectureId: lectureId,
                date: occurrenceDate,
                occurrenceIndex: occurrenceIndex,
              );

              // Check if already marked
              final attDoc = await _attendanceRef.doc(occurrenceKey).get();
              if (attDoc.exists) {
                totalSkipped++;
                continue;
              }

              // Check if cancelled/holiday for this specific occurrence
              final override = await getOverrideOnce(
                lectureId: lectureId,
                date: occurrenceDate,
                occurrenceIndex: occurrenceIndex,
              );

              if (override != null) {
                print('  ⏭️ Skipping ${_formatDate(occurrenceDate)} occurrence $occurrenceIndex - cancelled/holiday');
                totalSkipped++;
                continue;
              }

              // Auto-mark as present
              print('  ✅ Auto-marking ${lectureData['subject']} on ${_formatDate(occurrenceDate)} '
                  'occurrence $occurrenceIndex (${occurrence.formattedStartTime}-${occurrence.formattedEndTime})');

              await markAttendance(
                lectureId: lectureId,
                date: occurrenceDate,
                status: 'present',
                autoMarked: true,
                occurrenceIndex: occurrenceIndex,
              );

              totalAutoMarked++;
              await Future.delayed(const Duration(milliseconds: 50));
            }
          }
        }
      } catch (e) {
        print('❌ Error auto-marking for lecture $lectureId: $e');
        totalErrors++;
      }
    }

    print('\n🎯 Auto-marking completed:');
    print('   ✅ Marked: $totalAutoMarked lectures');
    print('   ⏭️ Skipped: $totalSkipped (already marked or cancelled)');
    print('   ❌ Errors: $totalErrors');
  }

  List<Map<String, dynamic>> _getOccurrencesForDate({
    required LectureScheduleVersion version,
    required DateTime date,
  }) {
    final occurrences = <Map<String, dynamic>>[];

    for (int i = 0; i < version.occurrences.length; i++) {
      final occurrence = version.occurrences[i];
      if (occurrence.dayOfWeek == date.weekday) {
        occurrences.add({
          'index': i,
          'occurrence': occurrence,
        });
      }
    }

    return occurrences;
  }

  List<DateTime> _calculateOccurrenceDatesForVersion({
    required LectureScheduleVersion version,
    required DateTime beforeDate,
  }) {
    final dates = <DateTime>[];

    // Normalize dates
    final normalizedBeforeDate = DateTime(beforeDate.year, beforeDate.month, beforeDate.day);
    final versionStart = DateTime(
      version.effectiveFrom.year,
      version.effectiveFrom.month,
      version.effectiveFrom.day,
    );

    final versionEnd = DateTime(
      version.effectiveUntil.year,
      version.effectiveUntil.month,
      version.effectiveUntil.day,
    );

    // Determine actual end date
    final effectiveEnd = versionEnd.isBefore(normalizedBeforeDate)
        ? versionEnd
        : normalizedBeforeDate.subtract(const Duration(days: 1));

    if (versionStart.isAfter(effectiveEnd)) {
      return dates;
    }

    // Calculate for EACH occurrence separately
    for (final occurrence in version.occurrences) {
      // Find first occurrence of this weekday
      int daysToAdd = (occurrence.dayOfWeek - versionStart.weekday) % 7;
      if (daysToAdd < 0) daysToAdd += 7;

      DateTime current = versionStart.add(Duration(days: daysToAdd));

      // Collect all occurrences for this specific schedule
      while (!current.isAfter(effectiveEnd)) {
        dates.add(current);
        current = current.add(const Duration(days: 7));
      }
    }

    // Sort dates chronologically
    dates.sort();
    return dates;
  }

  // =========================================================
  // ❌ CANCELLED / HOLIDAY - FIXED
  // =========================================================
  Future<void> markCancelled({
    required String lectureId,
    required DateTime date,
    required String type, // cancelled | holiday
    String? note,
    int? occurrenceIndex,
  }) async {
    if (_uid == null) return;

    // Generate correct key
    final key = _generateKey(
        lectureId: lectureId,
        date: date,
        occurrenceIndex: occurrenceIndex
    );

    final overrideData = {
      'lectureId': lectureId,
      'date': _formatDate(date),
      'type': type,
      'note': note,
      'occurrenceIndex': occurrenceIndex,
      'timestamp': FieldValue.serverTimestamp(),
    };

    print('Marking cancelled: $overrideData');

    await _overrideRef.doc(key).set(overrideData);

    // Remove attendance if exists
    await _attendanceRef.doc(key).delete();

    // If no occurrenceIndex specified, also remove all attendance for this date
    if (occurrenceIndex == null) {
      final attendanceSnap = await _attendanceRef
          .where('lectureId', isEqualTo: lectureId)
          .where('date', isEqualTo: _formatDate(date))
          .get();

      for (final doc in attendanceSnap.docs) {
        await doc.reference.delete();
      }
    }
  }

  // =========================================================
  // 🔍 GET OVERRIDE - FIXED
  // =========================================================
  Future<Map<String, dynamic>?> getOverrideOnce({
    required String lectureId,
    required DateTime date,
    int? occurrenceIndex,
  }) async {
    if (_uid == null) return null;

    // Check for specific occurrence override first
    if (occurrenceIndex != null) {
      final specificKey = _generateKey(
          lectureId: lectureId,
          date: date,
          occurrenceIndex: occurrenceIndex
      );

      final specificDoc = await _overrideRef.doc(specificKey).get();
      if (specificDoc.exists) {
        return specificDoc.data() as Map<String, dynamic>;
      }
    }

    // Check for general date override
    final generalKey = _generateKey(lectureId: lectureId, date: date);
    final generalDoc = await _overrideRef.doc(generalKey).get();

    return generalDoc.exists ? generalDoc.data() as Map<String, dynamic> : null;
  }

  // =========================================================
  // 📊 GET ATTENDANCE FOR SPECIFIC OCCURRENCE - FIXED
  // =========================================================
  Future<Map<String, dynamic>?> getAttendanceForOccurrence({
    required String lectureId,
    required DateTime date,
    required int occurrenceIndex,
  }) async {
    if (_uid == null) return null;

    final key = _generateKey(
        lectureId: lectureId,
        date: date,
        occurrenceIndex: occurrenceIndex
    );

    final doc = await _attendanceRef.doc(key).get();

    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return {...data, 'id': doc.id};
  }

  // =========================================================
  // 📅 GET OCCURRENCES FOR DATE WITH ATTENDANCE - FIXED
  // =========================================================
  Future<List<Map<String, dynamic>>> getOccurrencesForDate({
    required String lectureId,
    required DateTime date,
  }) async {
    if (_uid == null) return [];

    final lectureService = LectureService();
    final occurrences = await lectureService.getOccurrencesOnDate(
      lectureId: lectureId,
      date: date,
    );

    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < occurrences.length; i++) {
      final occurrence = occurrences[i];
      final attendance = await getAttendanceForOccurrence(
        lectureId: lectureId,
        date: date,
        occurrenceIndex: i,
      );

      final override = await getOverrideOnce(
        lectureId: lectureId,
        date: date,
        occurrenceIndex: i,
      );

      result.add({
        'occurrenceIndex': i,
        'dayOfWeek': occurrence.dayOfWeek,
        'startTime': occurrence.startTime,
        'endTime': occurrence.endTime,
        'room': occurrence.room,
        'topic': occurrence.topic,
        'formattedStartTime': occurrence.formattedStartTime,
        'formattedEndTime': occurrence.formattedEndTime,
        'timeRange': occurrence.timeRange,
        'attendance': attendance,
        'override': override,
        'isCancelled': override != null,
      });
    }

    return result;
  }

  Future<int> calculateTotalLecturesOccurred(String lectureId) async {
    final lectureService = LectureService();
    final versions = await lectureService.getLectureScheduleVersions(lectureId);

    // Sort versions by effectiveFrom
    versions.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    int total = 0;
    final Set<String> countedKeys = {};

    DateTime? lastVersionEndDate;

    for (int v = 0; v < versions.length; v++) {
      final version = versions[v];
      if (!version.isActive) continue;

      // Determine the actual date range for this version
      DateTime versionStart = version.effectiveFrom;
      DateTime versionEnd = version.effectiveUntil;

      // If there was a previous version, adjust start date to avoid overlap
      if (lastVersionEndDate != null && versionStart.isBefore(lastVersionEndDate)) {
        versionStart = lastVersionEndDate.add(const Duration(days: 1));
      }

      // Skip if start is after end (no valid range)
      if (versionStart.isAfter(versionEnd)) {
        lastVersionEndDate = versionEnd;
        continue;
      }

      print('📊 Version ${v + 1}: ${_formatDate(versionStart)} to ${_formatDate(versionEnd)}');

      // Count occurrences for each day in the version's adjusted date range
      for (int occIndex = 0; occIndex < version.occurrences.length; occIndex++) {
        final occurrence = version.occurrences[occIndex];

        // Get all dates for this occurrence in the adjusted range
        final dates = _getOccurrenceDatesInRange(
          occurrence: occurrence,
          startDate: versionStart,
          endDate: versionEnd,
        );

        print('  📅 Occurrence ${occIndex + 1} (${_dayName(occurrence.dayOfWeek)}): ${dates.length} dates');

        for (final date in dates) {
          // Skip if date is before the current version's start
          if (date.isBefore(versionStart)) continue;

          // Create a truly unique key for this specific occurrence
          final uniqueKey = '${_formatDate(date)}-${lectureId}-${occurrence.dayOfWeek}-'
              '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occIndex';

          if (!countedKeys.contains(uniqueKey)) {
            countedKeys.add(uniqueKey);
            total++;
          }
        }
      }

      // Update last version end date for next iteration
      lastVersionEndDate = versionEnd;
    }

    print('✅ Total unique occurrences counted: $total');

    // Subtract overrides
    final overridesSnapshot = await _overrideRef
        .where('lectureId', isEqualTo: lectureId)
        .get();

    int overrideCount = 0;
    for (final doc in overridesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String?;
      final occurrenceIndex = data['occurrenceIndex'] as int?;

      if (dateStr != null) {
        final date = _parseDate(dateStr);
        if (date != null) {
          // Find which version this override belongs to
          for (final version in versions) {
            if (date.isAfter(version.effectiveFrom) ||
                date.isAtSameMomentAs(version.effectiveFrom) &&
                    date.isBefore(version.effectiveUntil)) {

              if (occurrenceIndex != null) {
                // Specific occurrence override
                if (occurrenceIndex < version.occurrences.length) {
                  final occurrence = version.occurrences[occurrenceIndex];
                  final uniqueKey = '${dateStr}-${lectureId}-${occurrence.dayOfWeek}-'
                      '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occurrenceIndex';
                  if (countedKeys.contains(uniqueKey)) {
                    overrideCount++;
                  }
                }
              } else {
                // General date override - count all occurrences on this date
                for (int occIndex = 0; occIndex < version.occurrences.length; occIndex++) {
                  final occurrence = version.occurrences[occIndex];
                  if (occurrence.dayOfWeek == date.weekday) {
                    final uniqueKey = '${dateStr}-${lectureId}-${occurrence.dayOfWeek}-'
                        '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occIndex';
                    if (countedKeys.contains(uniqueKey)) {
                      overrideCount++;
                    }
                  }
                }
              }
              break;
            }
          }
        }
      }
    }

    print('📊 Subtracting $overrideCount overrides');
    total = total - overrideCount;
    if (total < 0) total = 0;

    return total;
  }
// Helper method to get all occurrence dates for a specific occurrence in a date range
  List<DateTime> _getOccurrenceDatesInRange({
    required LectureOccurrence occurrence,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final dates = <DateTime>[];

    // Find first occurrence
    int daysToAdd = (occurrence.dayOfWeek - startDate.weekday) % 7;
    if (daysToAdd < 0) daysToAdd += 7;

    DateTime current = startDate.add(Duration(days: daysToAdd));

    // Collect all occurrences
    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 7));
    }

    return dates;
  }

  Future<int> _getOccurrencesCountOnDate(String lectureId, DateTime date) async {
    final lectureService = LectureService();
    final versions = await lectureService.getLectureScheduleVersions(lectureId);

    int count = 0;
    for (final version in versions) {
      if (date.isBefore(version.effectiveFrom) || date.isAfter(version.effectiveUntil)) {
        continue;
      }

      for (final occurrence in version.occurrences) {
        if (occurrence.dayOfWeek == date.weekday) {
          count++;
        }
      }
    }

    return count;
  }

  Future<int> calculateLecturesInDateRange({
    required String lectureId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final lectureService = LectureService();
    final versions = await lectureService.getLectureScheduleVersions(lectureId);

    int total = 0;
    final Set<String> countedKeys = {};

    // Sort versions by effectiveFrom
    versions.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    DateTime? lastVersionEndDate;

    for (final version in versions) {
      if (!version.isActive) continue;

      // Find overlap between version range and query range
      DateTime versionStart = version.effectiveFrom.isAfter(startDate)
          ? version.effectiveFrom
          : startDate;

      DateTime versionEnd = version.effectiveUntil.isBefore(endDate)
          ? version.effectiveUntil
          : endDate;

      // Adjust for previous version overlap
      if (lastVersionEndDate != null && versionStart.isBefore(lastVersionEndDate)) {
        versionStart = lastVersionEndDate.add(const Duration(days: 1));
      }

      if (versionStart.isAfter(versionEnd)) {
        lastVersionEndDate = version.effectiveUntil;
        continue;
      }

      // Count each occurrence in the version
      for (int occIndex = 0; occIndex < version.occurrences.length; occIndex++) {
        final occurrence = version.occurrences[occIndex];

        final dates = _getOccurrenceDatesInRange(
          occurrence: occurrence,
          startDate: versionStart,
          endDate: versionEnd,
        );

        for (final date in dates) {
          final uniqueKey = '${_formatDate(date)}-${lectureId}-${occurrence.dayOfWeek}-'
              '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occIndex';
          if (!countedKeys.contains(uniqueKey)) {
            countedKeys.add(uniqueKey);
            total++;
          }
        }
      }

      lastVersionEndDate = version.effectiveUntil;
    }

    // Subtract overrides in this range
    final overridesSnapshot = await _overrideRef
        .where('lectureId', isEqualTo: lectureId)
        .get();

    int overrideCount = 0;
    for (final doc in overridesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String?;
      final occurrenceIndex = data['occurrenceIndex'] as int?;

      if (dateStr != null) {
        final date = _parseDate(dateStr);
        if (date != null &&
            !date.isBefore(startDate) &&
            !date.isAfter(endDate)) {

          if (occurrenceIndex != null) {
            // Specific occurrence override
            for (final version in versions) {
              if (date.isAfter(version.effectiveFrom) &&
                  date.isBefore(version.effectiveUntil) &&
                  occurrenceIndex < version.occurrences.length) {
                final occurrence = version.occurrences[occurrenceIndex];
                final uniqueKey = '$dateStr-${lectureId}-${occurrence.dayOfWeek}-'
                    '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occurrenceIndex';
                if (countedKeys.contains(uniqueKey)) {
                  overrideCount++;
                }
                break;
              }
            }
          } else {
            // General date override
            for (final version in versions) {
              if (date.isAfter(version.effectiveFrom) &&
                  date.isBefore(version.effectiveUntil)) {
                for (int occIndex = 0; occIndex < version.occurrences.length; occIndex++) {
                  final occurrence = version.occurrences[occIndex];
                  if (occurrence.dayOfWeek == date.weekday) {
                    final uniqueKey = '$dateStr-${lectureId}-${occurrence.dayOfWeek}-'
                        '${occurrence.startTime.hour}-${occurrence.startTime.minute}-$occIndex';
                    if (countedKeys.contains(uniqueKey)) {
                      overrideCount++;
                    }
                  }
                }
                break;
              }
            }
          }
        }
      }
    }

    total = total - overrideCount;
    if (total < 0) total = 0;

    return total;
  }

  // =========================================================
  // 📈 GET LECTURE ATTENDANCE STATS - FIXED
  // =========================================================
  Future<Map<String, dynamic>> getLectureAttendanceStats(String lectureId) async {
    final totalOccurred = await calculateTotalLecturesOccurred(lectureId);

    final attendanceSnap = await _attendanceRef
        .where('lectureId', isEqualTo: lectureId)
        .get();

    int present = 0;
    int absent = 0;
    int late = 0;

    for (final doc in attendanceSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'present') present++;
      else if (status == 'absent') absent++;
      else if (status == 'late') late++;
    }

    final totalMarked = present + absent + late;
    final pending = totalOccurred - totalMarked;
    final percentage = totalOccurred > 0 ? ((present / totalOccurred) * 100).round() : 0;

    return {
      'totalOccurred': totalOccurred,
      'present': present,
      'absent': absent,
      'late': late,
      'pending': pending > 0 ? pending : 0,
      'percentage': percentage,
      'totalMarked': totalMarked,
    };
  }

  // =========================================================
  // 📊 GET OCCURRENCE ATTENDANCE STATS - FIXED
  // =========================================================
  Future<Map<String, dynamic>> getOccurrenceAttendanceStats({
    required String lectureId,
    required int occurrenceIndex,
  }) async {
    final lectureService = LectureService();
    final versions = await lectureService.getLectureScheduleVersions(lectureId);

    int totalOccurred = 0;
    int present = 0;
    int absent = 0;
    int late = 0;

    for (final version in versions) {
      // Get the occurrence from this version
      if (occurrenceIndex < version.occurrences.length) {
        final occurrence = version.occurrences[occurrenceIndex];

        // Count occurrences in date range
        totalOccurred += _countOccurrencesInDateRange(
          startDate: version.effectiveFrom,
          endDate: version.effectiveUntil,
          dayOfWeek: occurrence.dayOfWeek,
        );
      }
    }

    // Get attendance for this specific occurrence
    final attendanceSnap = await _attendanceRef
        .where('lectureId', isEqualTo: lectureId)
        .where('occurrenceIndex', isEqualTo: occurrenceIndex)
        .get();

    for (final doc in attendanceSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      if (status == 'present') present++;
      else if (status == 'absent') absent++;
      else if (status == 'late') late++;
    }

    final totalMarked = present + absent + late;
    final pending = totalOccurred - totalMarked;
    final percentage = totalOccurred > 0 ? ((present / totalOccurred) * 100).round() : 0;

    return {
      'totalOccurred': totalOccurred,
      'present': present,
      'absent': absent,
      'late': late,
      'pending': pending > 0 ? pending : 0,
      'percentage': percentage,
      'occurrenceIndex': occurrenceIndex,
      'totalMarked': totalMarked,
    };
  }

  // =========================================================
  // 📋 GET ALL OCCURRENCES WITH ATTENDANCE - FIXED
  // =========================================================
  Future<List<Map<String, dynamic>>> getLectureOccurrencesWithAttendance(
      String lectureId) async {
    final lectureService = LectureService();
    final versions = await lectureService.getLectureScheduleVersions(lectureId);

    final result = <Map<String, dynamic>>[];

    for (final version in versions) {
      for (int i = 0; i < version.occurrences.length; i++) {
        final occurrence = version.occurrences[i];

        // Get stats for this occurrence
        final stats = await getOccurrenceAttendanceStats(
          lectureId: lectureId,
          occurrenceIndex: i,
        );

        result.add({
          'occurrenceIndex': i,
          'dayOfWeek': occurrence.dayOfWeek,
          'dayName': _dayName(occurrence.dayOfWeek),
          'startTime': occurrence.formattedStartTime,
          'endTime': occurrence.formattedEndTime,
          'timeRange': occurrence.timeRange,
          'room': occurrence.room,
          'topic': occurrence.topic,
          'stats': stats,
          'versionStart': version.effectiveFrom,
          'versionEnd': version.effectiveUntil,
          'isActive': version.isActive,
        });
      }
    }

    // Sort by day and time
    result.sort((a, b) {
      if (a['dayOfWeek'] != b['dayOfWeek']) {
        return (a['dayOfWeek'] as int).compareTo(b['dayOfWeek'] as int);
      }

      final aTime = a['startTime'] as String;
      final bTime = b['startTime'] as String;
      return aTime.compareTo(bTime);
    });

    return result;
  }

  // =========================================================
  // 🔁 GLOBAL ATTENDANCE STREAM - FIXED
  // =========================================================
  Stream<List<Map<String, dynamic>>> getAllAttendance() {
    if (_uid == null) return Stream.value([]);

    final query = _attendanceRef
        .orderBy('timestamp', descending: true);

    return _getAttendanceWithLectureData(query);
  }

  // =========================================================
  // 📱 RECENT ACTIVITY STREAM - FIXED
  // =========================================================
  Stream<List<Map<String, dynamic>>> getRecentActivityStream() {
    if (_uid == null) return Stream.value([]);

    final query = _attendanceRef
        .orderBy('timestamp', descending: true)
        .limit(10);

    return _getAttendanceWithLectureData(query);
  }

  // =========================================================
  // 📊 GLOBAL STATS - FIXED
  // =========================================================
  Future<Map<String, dynamic>> getAttendanceStats() async {
    if (_uid == null) return {
      'present': 0, 'absent': 0, 'late': 0, 'total': 0, 'percentage': 0
    };

    // First fetch all lectures
    final lecturesRef = _firestore.collection('users').doc(_uid!).collection('lectures');
    final lecturesSnap = await lecturesRef.get();

    int totalOccurred = 0;
    final List<Map<String, dynamic>> lectures = [];

    for (final doc in lecturesSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Convert Firestore timestamps to DateTime
      Map<String, dynamic> convertedData = {...data, 'id': doc.id};

      if (data['validFrom'] is Timestamp) {
        convertedData['validFrom'] = (data['validFrom'] as Timestamp).toDate();
      }
      if (data['validUntil'] is Timestamp) {
        convertedData['validUntil'] = (data['validUntil'] as Timestamp).toDate();
      }

      lectures.add(convertedData);

      // Calculate total for this lecture with schedule versioning
      final lectureTotal = await calculateTotalLecturesOccurred(doc.id);
      totalOccurred += lectureTotal;
    }

    // Now get attendance counts
    final attendanceSnap = await _attendanceRef.get();

    int present = 0;
    int absent = 0;
    int late = 0;

    for (final d in attendanceSnap.docs) {
      final s = d['status'] as String?;
      if (s == 'present') present++;
      if (s == 'absent') absent++;
      if (s == 'late') late++;
    }

    final percentage = totalOccurred > 0 ? ((present / totalOccurred) * 100).round() : 0;

    return {
      'present': present,
      'absent': absent,
      'late': late,
      'total': totalOccurred,
      'percentage': percentage,
      'totalMarked': present + absent + late,
      'pending': totalOccurred - (present + absent + late),
    };
  }

  // =========================================================
  // 🛠️ HELPER METHODS
  // =========================================================

  // REFACTORED: Common method for attendance streams
  Stream<List<Map<String, dynamic>>> _getAttendanceWithLectureData(Query query) {
    final lecturesRef = _firestore.collection('users').doc(_uid!).collection('lectures');

    return query.snapshots().asyncMap((snap) async {
      final records = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lectureId = data['lectureId'] as String?;

        String lectureSubject = 'Lecture';
        String? lectureRoom;
        String? lectureTopic;

        // 🔗 JOIN lecture data safely
        if (lectureId != null) {
          final lecDoc = await lecturesRef.doc(lectureId).get();
          if (lecDoc.exists) {
            lectureSubject = lecDoc['subject'] ?? lectureSubject;
            lectureRoom = lecDoc['room'] as String?;
            lectureTopic = lecDoc['topic'] as String?;
          }
        }

        records.add({
          ...data,
          'id': doc.id,
          'lectureSubject': lectureSubject,
          'lectureRoom': lectureRoom,
          'lectureTopic': lectureTopic,
          'markedAt': data['timestamp'],
        });
      }

      return records;
    });
  }

  // OPTIMIZED: Count occurrences mathematically
  int _countOccurrencesInDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required int dayOfWeek,
  }) {
    // Normalize dates to midnight
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (start.isAfter(end)) return 0;

    // Find first occurrence of the weekday
    int daysToAdd = (dayOfWeek - start.weekday) % 7;
    if (daysToAdd < 0) daysToAdd += 7;

    final firstOccurrence = start.add(Duration(days: daysToAdd));

    if (firstOccurrence.isAfter(end)) return 0;

    // Calculate number of weeks between first occurrence and end date
    final daysBetween = end.difference(firstOccurrence).inDays;
    return (daysBetween ~/ 7) + 1;
  }

  // =========================================================
  // 🔧 UTILITY METHODS
  // =========================================================
  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      print('Error parsing date: $dateStr - $e');
      return null;
    }
  }

  String _dayName(int dayOfWeek) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'];
    return days[dayOfWeek - 1];
  }

  // =========================================================
  // 🚨 EMERGENCY FIX FOR KEY CONFLICTS
  // =========================================================
  Future<void> fixKeyConflicts() async {
    if (_uid == null) return;

    print('🛠️ Fixing attendance key conflicts...');

    // Get all attendance records
    final snap = await _attendanceRef.get();
    int fixed = 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lectureId = data['lectureId'] as String?;
      final dateStr = data['date'] as String?;
      final occurrenceIndex = data['occurrenceIndex'] as int?;

      if (lectureId == null || dateStr == null) continue;

      final date = _parseDate(dateStr);
      if (date == null) continue;

      // Generate correct key
      final correctKey = _generateKey(
          lectureId: lectureId,
          date: date,
          occurrenceIndex: occurrenceIndex
      );

      // If key is different, fix it
      if (doc.id != correctKey) {
        print('  🔄 Fixing key: ${doc.id} -> $correctKey');
        await _attendanceRef.doc(correctKey).set(data);
        await doc.reference.delete();
        fixed++;
      }
    }

    print('✅ Fixed $fixed attendance key conflicts');

    // Fix override keys too
    final overrideSnap = await _overrideRef.get();
    int overrideFixed = 0;

    for (final doc in overrideSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lectureId = data['lectureId'] as String?;
      final dateStr = data['date'] as String?;
      final occurrenceIndex = data['occurrenceIndex'] as int?;

      if (lectureId == null || dateStr == null) continue;

      final date = _parseDate(dateStr);
      if (date == null) continue;

      final correctKey = _generateKey(
          lectureId: lectureId,
          date: date,
          occurrenceIndex: occurrenceIndex
      );

      if (doc.id != correctKey) {
        print('  🔄 Fixing override key: ${doc.id} -> $correctKey');
        await _overrideRef.doc(correctKey).set(data);
        await doc.reference.delete();
        overrideFixed++;
      }
    }

    print('✅ Fixed $overrideFixed override key conflicts');
    print('🎉 Key conflict fix completed!');
  }

  // =========================================================
  // 🗑️ CLEANUP METHODS
  // =========================================================
  Future<void> cleanupDuplicateAttendance() async {
    if (_uid == null) return;

    print('🧹 Cleaning up duplicate attendance records...');

    final snap = await _attendanceRef.get();
    final Map<String, DocumentSnapshot> uniqueRecords = {};
    int duplicates = 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lectureId = data['lectureId'] as String?;
      final dateStr = data['date'] as String?;
      final occurrenceIndex = data['occurrenceIndex'] as int?;

      if (lectureId == null || dateStr == null) continue;

      // Create unique key
      final uniqueKey = '$lectureId-$dateStr${occurrenceIndex != null ? '-$occurrenceIndex' : ''}';

      if (uniqueRecords.containsKey(uniqueKey)) {
        // Keep the most recent one
        final existing = uniqueRecords[uniqueKey]!;
        final existingTimestamp = existing['timestamp'];
        final newTimestamp = data['timestamp'];

        if (newTimestamp is Timestamp && existingTimestamp is Timestamp) {
          if (newTimestamp.compareTo(existingTimestamp) > 0) {
            // Newer record, delete old one
            await existing.reference.delete();
            uniqueRecords[uniqueKey] = doc;
          } else {
            // Older record, delete this one
            await doc.reference.delete();
          }
        } else {
          // Default: keep existing, delete new
          await doc.reference.delete();
        }
        duplicates++;
      } else {
        uniqueRecords[uniqueKey] = doc;
      }
    }

    print('✅ Removed $duplicates duplicate attendance records');
  }
}