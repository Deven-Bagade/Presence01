  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import '../services/timetable_history_service.dart';
  import '../services/notification_service.dart';
  
  // =========================================================
  // NEW: Unified Occurrence Manager
  // =========================================================
  class OccurrenceManager {
    static String generateKey({
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
  
    static String _formatDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  
    static bool isValidIndex({
      required List<LectureOccurrence> occurrences,
      required int index,
    }) {
      return index >= 0 && index < occurrences.length;
    }
  
    static List<Map<String, dynamic>> getOccurrencesForDate({
      required List<LectureOccurrence> occurrences,
      required DateTime date,
    }) {
      final result = <Map<String, dynamic>>[];
  
      for (int i = 0; i < occurrences.length; i++) {
        final occurrence = occurrences[i];
        if (occurrence.dayOfWeek == date.weekday) {
          result.add({
            'index': i,
            'occurrence': occurrence,
            'startTime': occurrence.startTime,
            'endTime': occurrence.endTime,
            'room': occurrence.room,
            'topic': occurrence.topic,
            'dayOfWeek': occurrence.dayOfWeek,
          });
        }
      }
  
      return result;
    }
  
    static List<int> getUniqueDays(List<LectureOccurrence> occurrences) {
      return occurrences.map((o) => o.dayOfWeek).toSet().toList();
    }
  
    static void sortOccurrences(List<LectureOccurrence> occurrences) {
      occurrences.sort((a, b) {
        if (a.dayOfWeek != b.dayOfWeek) return a.dayOfWeek.compareTo(b.dayOfWeek);
        final aStart = a.startTime.hour * 60 + a.startTime.minute;
        final bStart = b.startTime.hour * 60 + b.startTime.minute;
        return aStart.compareTo(bStart);
      });
    }
  }
  
  // =========================================================
  // LectureOccurrence class (UPDATED)
  // =========================================================
  class LectureOccurrence {
    final int dayOfWeek; // 1=Mon … 7=Sun
    final TimeOfDay startTime;
    final TimeOfDay endTime;
    final String? room;
    final String? topic;
  
    const LectureOccurrence({
      required this.dayOfWeek,
      required this.startTime,
      required this.endTime,
      this.room,
      this.topic,
    });
  
    Map<String, dynamic> toMap() {
      return {
        'dayOfWeek': dayOfWeek,
        'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
        'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
        'room': room,
        'topic': topic,
      };
    }
  
    static LectureOccurrence fromMap(Map<String, dynamic> map) {
      final startMap = map['startTime'] as Map<String, dynamic>;
      final endMap = map['endTime'] as Map<String, dynamic>;
  
      return LectureOccurrence(
        dayOfWeek: map['dayOfWeek'] as int,
        startTime: TimeOfDay(hour: startMap['hour'], minute: startMap['minute']),
        endTime: TimeOfDay(hour: endMap['hour'], minute: endMap['minute']),
        room: map['room'] as String?,
        topic: map['topic'] as String?,
      );
    }
  
    String get formattedStartTime => _formatTime(startTime);
    String get formattedEndTime => _formatTime(endTime);
    String get timeRange => '$formattedStartTime - $formattedEndTime';
  
    String _formatTime(TimeOfDay time) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
  
    LectureOccurrence copyWith({
      int? dayOfWeek,
      TimeOfDay? startTime,
      TimeOfDay? endTime,
      String? room,
      String? topic,
    }) {
      return LectureOccurrence(
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        room: room ?? this.room,
        topic: topic ?? this.topic,
      );
    }
  
    bool overlapsWith(LectureOccurrence other) {
      if (dayOfWeek != other.dayOfWeek) return false;
  
      final thisStart = startTime.hour * 60 + startTime.minute;
      final thisEnd = endTime.hour * 60 + endTime.minute;
      final otherStart = other.startTime.hour * 60 + other.startTime.minute;
      final otherEnd = other.endTime.hour * 60 + other.endTime.minute;
  
      return thisStart < otherEnd && thisEnd > otherStart;
    }
  }
  
  // =========================================================
  // LectureScheduleVersion (UPDATED)
  // =========================================================
  class LectureScheduleVersion {
    final String versionId;
    final String lectureId;
    final List<LectureOccurrence> occurrences;
    final DateTime effectiveFrom;
    final DateTime effectiveUntil;
    final bool isActive;
    final DateTime createdAt;
    final String changeReason;
  
    LectureScheduleVersion({
      required this.versionId,
      required this.lectureId,
      required this.occurrences,
      required this.effectiveFrom,
      required this.effectiveUntil,
      this.isActive = true,
      required this.createdAt,
      this.changeReason = 'Schedule created',
    });
  
    Map<String, dynamic> toMap() {
      return {
        'versionId': versionId,
        'lectureId': lectureId,
        'occurrences': occurrences.map((o) => o.toMap()).toList(),
        'effectiveFrom': effectiveFrom,
        'effectiveUntil': effectiveUntil,
        'isActive': isActive,
        'createdAt': createdAt,
        'changeReason': changeReason,
      };
    }
  
    List<int> get daysOfWeek => occurrences.map((o) => o.dayOfWeek).toSet().toList();
    int get occurrenceCount => occurrences.length;
  
    bool hasOccurrenceOnDay(int dayOfWeek) {
      return occurrences.any((o) => o.dayOfWeek == dayOfWeek);
    }
  
    bool hasOccurrenceOnDate(DateTime date) {
      return occurrences.any((o) => o.dayOfWeek == date.weekday);
    }
  
    List<LectureOccurrence> getOccurrencesOnDay(int dayOfWeek) {
      return occurrences.where((o) => o.dayOfWeek == dayOfWeek).toList();
    }
  
    List<LectureOccurrence> getOccurrencesOnDate(DateTime date) {
      return occurrences.where((o) => o.dayOfWeek == date.weekday).toList();
    }
  
    static LectureScheduleVersion fromMap(Map<String, dynamic> data) {
      List<LectureOccurrence> occurrences = [];
  
      if (data.containsKey('occurrences')) {
        final occurrencesList = data['occurrences'] as List<dynamic>;
        occurrences = occurrencesList.map((item) {
          if (item is Map<String, dynamic>) {
            return LectureOccurrence.fromMap(item);
          }
          return LectureOccurrence(
            dayOfWeek: 1,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 10, minute: 0),
          );
        }).toList();
      } else if (data.containsKey('daysOfWeek')) {
        final daysList = data['daysOfWeek'] as List<dynamic>;
        final daysOfWeek = daysList.map((day) => (day as int)).toList();
        final startMap = data['startTime'] as Map<String, dynamic>;
        final endMap = data['endTime'] as Map<String, dynamic>;
  
        occurrences = daysOfWeek.map((day) {
          return LectureOccurrence(
            dayOfWeek: day,
            startTime: TimeOfDay(hour: startMap['hour'], minute: startMap['minute']),
            endTime: TimeOfDay(hour: endMap['hour'], minute: endMap['minute']),
          );
        }).toList();
      } else {
        final dayOfWeek = data['dayOfWeek'] as int;
        final startMap = data['startTime'] as Map<String, dynamic>;
        final endMap = data['endTime'] as Map<String, dynamic>;
  
        occurrences = [LectureOccurrence(
          dayOfWeek: dayOfWeek,
          startTime: TimeOfDay(hour: startMap['hour'], minute: startMap['minute']),
          endTime: TimeOfDay(hour: endMap['hour'], minute: endMap['minute']),
        )];
      }
  
      return LectureScheduleVersion(
        versionId: data['versionId'] ?? '',
        lectureId: data['lectureId'] ?? '',
        occurrences: occurrences,
        effectiveFrom: (data['effectiveFrom'] as Timestamp).toDate(),
        effectiveUntil: (data['effectiveUntil'] as Timestamp).toDate(),
        isActive: data['isActive'] ?? true,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        changeReason: data['changeReason'] as String? ?? 'Schedule change',
      );
    }
  }
  
  // =========================================================
  // LectureService (COMPLETELY FIXED)
  // =========================================================
  class LectureService {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final TimetableHistoryService _historyService = TimetableHistoryService();
    final NotificationService _notificationService = NotificationService();
  
    String? get _uid => _auth.currentUser?.uid;
  
    CollectionReference get _ref =>
        _firestore.collection('users').doc(_uid).collection('lectures');
  
    CollectionReference _versionsRef(String lectureId) =>
        _ref.doc(lectureId).collection('schedule_versions');
  
    // ─────────────────────────────────────────────
    // CORE METHODS (FIXED)
    // ─────────────────────────────────────────────
  
    Future<String> _saveLecture(Map<String, dynamic> data, {
      String? lectureId,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      final doc = lectureId == null ? _ref.doc() : _ref.doc(lectureId);
      await doc.set(_toFirestore(data), SetOptions(merge: true));
      return doc.id;
    }
  
    Future<String> saveWeeklyLectureWithOccurrences({
      String? lectureId,
      required String subject,
      required String defaultRoom,
      required String defaultTopic,
      required List<LectureOccurrence> occurrences,
      required DateTime validFrom,
      required DateTime validUntil,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      // Sort occurrences
      OccurrenceManager.sortOccurrences(occurrences);
  
      // Validate each occurrence for conflicts
      for (final occurrence in occurrences) {
        final hasConflict = await _hasConflictForOccurrence(
          occurrence: occurrence,
          editingLectureId: lectureId,
        );
  
        if (hasConflict) {
          throw Exception(
              'Lecture conflicts with existing schedule on ${_dayName(occurrence.dayOfWeek)} '
                  'at ${occurrence.formattedStartTime}'
          );
        }
      }
  
      // Validate internal overlaps
      final internalOverlaps = _findInternalOverlaps(occurrences);
      if (internalOverlaps.isNotEmpty) {
        throw Exception(
            'Lecture cannot have overlapping occurrences: $internalOverlaps'
        );
      }
  
      // Get unique days
      final uniqueDays = OccurrenceManager.getUniqueDays(occurrences);
  
      // Use first occurrence for base datetime
      final firstOccurrence = occurrences.first;
      final base = _nextWeekday(validFrom, firstOccurrence.dayOfWeek);
  
      // If editing existing lecture, end previous schedule version FIRST
      if (lectureId != null) {
        // End previous schedule at yesterday
        final yesterday = validFrom.subtract(const Duration(days: 1));
        await _endScheduleVersion(lectureId, yesterday);
      }
  
      final savedLectureId = await _saveLecture({
        'subject': subject,
        'room': defaultRoom,
        'topic': defaultTopic,
        'defaultRoom': defaultRoom,
        'defaultTopic': defaultTopic,
        'occurrences': occurrences.map((o) => o.toMap()).toList(),
        'dayOfWeek': firstOccurrence.dayOfWeek,
        'daysOfWeek': uniqueDays,
        'occurrenceCount': occurrences.length,
        'isRecurringWeekly': true,
        'isSingleLecture': false,
        'validFrom': validFrom,
        'validUntil': validUntil,
        'startDateTime': DateTime(
          base.year,
          base.month,
          base.day,
          firstOccurrence.startTime.hour,
          firstOccurrence.startTime.minute,
        ),
        'endDateTime': DateTime(
          base.year,
          base.month,
          base.day,
          firstOccurrence.endTime.hour,
          firstOccurrence.endTime.minute,
        ),
        'startTime': {'hour': firstOccurrence.startTime.hour, 'minute': firstOccurrence.startTime.minute},
        'endTime': {'hour': firstOccurrence.endTime.hour, 'minute': firstOccurrence.endTime.minute},
        'updatedAt': FieldValue.serverTimestamp(),
      }, lectureId: lectureId);
  
      // Create schedule version with CORRECT date range
      await createScheduleVersionWithOccurrences(
        lectureId: savedLectureId,
        occurrences: occurrences,
        effectiveFrom: validFrom,
        effectiveUntil: validUntil, // Use the actual validUntil, not default
        changeReason: lectureId == null ? 'Lecture created' : 'Lecture updated',
      );
  
      await _historyService.recordChange(
        action: lectureId == null ? 'create' : 'update',
        lectureData: {
          'id': savedLectureId,
          'subject': subject,
          'defaultRoom': defaultRoom,
          'defaultTopic': defaultTopic,
          'occurrences': occurrences.map((o) => o.toMap()).toList(),
          'validFrom': validFrom,
          'validUntil': validUntil,
        },
        reason: 'Weekly lecture ${lectureId == null ? 'created' : 'updated'}',
      );
      await _notificationService.scheduleLectureNotifications(
        lectureId: savedLectureId,
        subject: subject,
        occurrences: occurrences,
        validFrom: validFrom,
        validUntil: validUntil,
      );
  
      return savedLectureId;
    }
  
    List<String> _findInternalOverlaps(List<LectureOccurrence> occurrences) {
      final overlaps = <String>[];
  
      for (int i = 0; i < occurrences.length; i++) {
        for (int j = i + 1; j < occurrences.length; j++) {
          final a = occurrences[i];
          final b = occurrences[j];
  
          if (a.dayOfWeek == b.dayOfWeek && a.overlapsWith(b)) {
            overlaps.add('${_dayName(a.dayOfWeek)} ${a.formattedStartTime}-${a.formattedEndTime}');
          }
        }
      }
  
      return overlaps;
    }
  
    // ─────────────────────────────────────────────
    // CONFLICT CHECKING (FIXED)
    // ─────────────────────────────────────────────
    Future<bool> _hasConflictForOccurrence({
      required LectureOccurrence occurrence,
      String? editingLectureId,
    }) async {
      if (_uid == null) return false;
  
      // Get all lectures on this day
      final snap = await _ref.where('dayOfWeek', isEqualTo: occurrence.dayOfWeek).get();
  
      for (final doc in snap.docs) {
        if (doc.id == editingLectureId) continue;
  
        final lecture = _fromFirestore(doc);
  
        // Skip single lectures
        if (lecture['isSingleLecture'] == true) continue;
  
        // Get occurrences for this lecture
        final lectureOccurrences = _getOccurrencesFromLecture(lecture);
  
        // Check each occurrence for overlap
        for (final existingOccurrence in lectureOccurrences) {
          if (existingOccurrence.dayOfWeek != occurrence.dayOfWeek) continue;
  
          if (existingOccurrence.overlapsWith(occurrence)) {
            return true;
          }
        }
      }
  
      return false;
    }
  
    Future<bool> _hasConflictExcluding({
      required LectureOccurrence occurrence,
      required List<String> excludeLectureIds,
    }) async {
      if (_uid == null) return false;
  
      final snap = await _ref.where('dayOfWeek', isEqualTo: occurrence.dayOfWeek).get();
  
      for (final doc in snap.docs) {
        if (excludeLectureIds.contains(doc.id)) continue;
  
        final lecture = _fromFirestore(doc);
  
        if (lecture['isSingleLecture'] == true) continue;
  
        final lectureOccurrences = _getOccurrencesFromLecture(lecture);
  
        for (final existingOccurrence in lectureOccurrences) {
          if (existingOccurrence.dayOfWeek != occurrence.dayOfWeek) continue;
  
          if (existingOccurrence.overlapsWith(occurrence)) {
            return true;
          }
        }
      }
  
      return false;
    }
  
    // ─────────────────────────────────────────────
    // SAVE SINGLE LECTURE (FIXED)
    // ─────────────────────────────────────────────
    Future<String> saveSingleLecture({
      String? lectureId,
      required String subject,
      required String room,
      required String topic,
      required DateTime date,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      // Validate no conflicts
      final hasConflict = await hasConflictForSpecificDate(
        date: date,
        startTime: startTime,
        endTime: endTime,
        editingLectureId: lectureId,
      );
  
      if (hasConflict) {
        throw Exception('Lecture conflicts with existing schedule on this date');
      }
  
      // Validate time
      final startMin = startTime.hour * 60 + startTime.minute;
      final endMin = endTime.hour * 60 + endTime.minute;
      if (endMin <= startMin) {
        throw Exception('End time must be after start time');
      }
  
      final savedLectureId = await _saveLecture({
        'subject': subject,
        'room': room,
        'topic': topic,
        'defaultRoom': room,
        'defaultTopic': topic,
        'specificDate': date,
        'dayOfWeek': date.weekday,
        'isRecurringWeekly': false,
        'isSingleLecture': true,
        'validFrom': date,
        'validUntil': date,
        'startDateTime': DateTime(
          date.year,
          date.month,
          date.day,
          startTime.hour,
          startTime.minute,
        ),
        'endDateTime': DateTime(
          date.year,
          date.month,
          date.day,
          endTime.hour,
          endTime.minute,
        ),
        'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
        'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
        'updatedAt': FieldValue.serverTimestamp(),
      }, lectureId: lectureId);
  
      // Create schedule version
      await createScheduleVersion(
        lectureId: savedLectureId,
        daysOfWeek: [date.weekday],
        startTime: startTime,
        endTime: endTime,
        effectiveFrom: date,
        effectiveUntil: date,
        changeReason: lectureId == null ? 'Single lecture created' : 'Single lecture updated',
      );
  
      return savedLectureId;
    }
  
    Future<void> swapLectures({
      required String lectureAId,
      required String lectureBId,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      try {
        // Validate swap first
        final validation = await _validateSwap(lectureAId, lectureBId);
        if (!validation['valid']) {
          throw Exception(validation['errors'].join('\n'));
        }
  
        final a = validation['lectureA'] as Map<String, dynamic>;
        final b = validation['lectureB'] as Map<String, dynamic>;
        final aOccurrences = validation['aOccurrences'] as List<LectureOccurrence>;
        final bOccurrences = validation['bOccurrences'] as List<LectureOccurrence>;
  
        final effectiveFrom = DateTime.now();
  
        // Perform the swap in a transaction
        await _firestore.runTransaction((tx) async {
          final aRef = _ref.doc(lectureAId);
          final bRef = _ref.doc(lectureBId);
  
          // End previous schedules
          final yesterday = effectiveFrom.subtract(const Duration(days: 1));
          await _endScheduleVersion(lectureAId, yesterday);
          await _endScheduleVersion(lectureBId, yesterday);
  
          // Create new schedule versions with PROPER occurrence handling
          await _createSwappedVersion(
            lectureId: lectureAId,
            occurrences: bOccurrences,
            effectiveFrom: effectiveFrom,
            validUntil: a['validUntil'] as DateTime? ?? DateTime(2100, 12, 31),
            swapWith: b['subject'] ?? 'Lecture',
            isSingle: a['isSingleLecture'] == true,
          );
  
          await _createSwappedVersion(
            lectureId: lectureBId,
            occurrences: aOccurrences,
            effectiveFrom: effectiveFrom,
            validUntil: b['validUntil'] as DateTime? ?? DateTime(2100, 12, 31),
            swapWith: a['subject'] ?? 'Lecture',
            isSingle: b['isSingleLecture'] == true,
          );
  
          // Update main lecture records
          await _updateLectureAfterSwap(
            tx: tx,
            ref: aRef,
            occurrences: bOccurrences,
            originalData: a,
            effectiveFrom: effectiveFrom,
            swapWith: b['subject'] ?? 'Lecture',
          );
  
          await _updateLectureAfterSwap(
            tx: tx,
            ref: bRef,
            occurrences: aOccurrences,
            originalData: b,
            effectiveFrom: effectiveFrom,
            swapWith: a['subject'] ?? 'Lecture',
          );
        });
  
        // Record history
        await _historyService.recordChange(
          action: 'swap',
          lectureData: {
            'id': lectureAId,
            'subject': a['subject'],
            'defaultRoom': a['defaultRoom'] ?? a['room'],
            'defaultTopic': a['defaultTopic'] ?? a['topic'],
            'occurrences': bOccurrences.map((o) => o.toMap()).toList(),
            'validFrom': effectiveFrom,
            'validUntil': a['validUntil'] as DateTime?,
            'isSingleLecture': a['isSingleLecture'] == true,
          },
          previousData: a,
          previousLectureId: lectureBId,
          reason: 'Swapped with ${b['subject']}',
        );
  
        await _historyService.recordChange(
          action: 'swap',
          lectureData: {
            'id': lectureBId,
            'subject': b['subject'],
            'defaultRoom': b['defaultRoom'] ?? b['room'],
            'defaultTopic': b['defaultTopic'] ?? b['topic'],
            'occurrences': aOccurrences.map((o) => o.toMap()).toList(),
            'validFrom': effectiveFrom,
            'validUntil': b['validUntil'] as DateTime?,
            'isSingleLecture': b['isSingleLecture'] == true,
          },
          previousData: b,
          previousLectureId: lectureAId,
          reason: 'Swapped with ${a['subject']}',
        );
  
        // Validate no overlaps
        await validateFinalTimetable();
  
      } catch (e) {
        print('❌ Error swapping lectures: $e');
        rethrow; // Re-throw the error so the UI can catch it
      }
    }
  
    Future<Map<String, dynamic>> _validateSwap(String lectureAId, String lectureBId) async {
      final errors = <String>[];
  
      // Get both lectures
      final aSnap = await _ref.doc(lectureAId).get();
      final bSnap = await _ref.doc(lectureBId).get();
  
      if (!aSnap.exists || !bSnap.exists) {
        errors.add('One or both lectures not found');
        return {'valid': false, 'errors': errors, 'lectureA': null, 'lectureB': null};
      }
  
      final a = _fromFirestore(aSnap);
      final b = _fromFirestore(bSnap);
  
      // Check lecture types
      final aIsSingle = a['isSingleLecture'] == true;
      final bIsSingle = b['isSingleLecture'] == true;
  
      if (aIsSingle != bIsSingle) {
        errors.add('Cannot swap single lecture with weekly lecture');
      }
      // Also check if trying to swap an occurrence within the same lecture
      if (lectureAId == lectureBId) {
        errors.add('Cannot swap a lecture with itself');
        return {'valid': false, 'errors': errors, 'lectureA': a, 'lectureB': b};
      }
  
      // Get occurrences PROPERLY
      final aOccurrences = _getOccurrencesFromLecture(a);
      final bOccurrences = _getOccurrencesFromLecture(b);
  
      // Check for conflicts
      for (final bOccurrence in bOccurrences) {
        final hasConflict = await _hasConflictExcluding(
          occurrence: bOccurrence,
          excludeLectureIds: [lectureAId, lectureBId],
        );
        if (hasConflict) {
          errors.add('Lecture A would conflict on ${_dayName(bOccurrence.dayOfWeek)} at ${bOccurrence.formattedStartTime}');
        }
      }
  
      for (final aOccurrence in aOccurrences) {
        final hasConflict = await _hasConflictExcluding(
          occurrence: aOccurrence,
          excludeLectureIds: [lectureAId, lectureBId],
        );
        if (hasConflict) {
          errors.add('Lecture B would conflict on ${_dayName(aOccurrence.dayOfWeek)} at ${aOccurrence.formattedStartTime}');
        }
      }
  
      return {
        'valid': errors.isEmpty,
        'errors': errors,
        'lectureA': a,
        'lectureB': b,
        'aOccurrences': aOccurrences,
        'bOccurrences': bOccurrences,
      };
    }
  
    Future<void> _createSwappedVersion({
      required String lectureId,
      required List<LectureOccurrence> occurrences,
      required DateTime effectiveFrom,
      required DateTime? validUntil,
      required String swapWith,
      required bool isSingle,
    }) async {
      if (isSingle && occurrences.isNotEmpty) {
        await createScheduleVersion(
          lectureId: lectureId,
          dayOfWeek: occurrences.first.dayOfWeek,
          startTime: occurrences.first.startTime,
          endTime: occurrences.first.endTime,
          effectiveFrom: effectiveFrom,
          effectiveUntil: validUntil ?? effectiveFrom,
          changeReason: 'Swapped with $swapWith',
        );
      } else {
        await createScheduleVersionWithOccurrences(
          lectureId: lectureId,
          occurrences: occurrences,
          effectiveFrom: effectiveFrom,
          effectiveUntil: validUntil,
          changeReason: 'Swapped with $swapWith',
        );
      }
    }
  
    Future<void> _updateLectureAfterSwap({
      required Transaction tx,
      required DocumentReference ref,
      required List<LectureOccurrence> occurrences,
      required Map<String, dynamic> originalData,
      required DateTime effectiveFrom,
      required String swapWith,
    }) async {
      if (occurrences.isEmpty) return;
  
      final firstOccurrence = occurrences.first;
      final uniqueDays = OccurrenceManager.getUniqueDays(occurrences);
  
      tx.update(ref, _toFirestore({
        'subject': originalData['subject'],
        'defaultRoom': originalData['defaultRoom'] ?? originalData['room'],
        'defaultTopic': originalData['defaultTopic'] ?? originalData['topic'],
        'occurrences': occurrences.map((o) => o.toMap()).toList(),
        'dayOfWeek': firstOccurrence.dayOfWeek,
        'daysOfWeek': uniqueDays,
        'occurrenceCount': occurrences.length,
        'startDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.startTime.hour,
          firstOccurrence.startTime.minute,
        ),
        'endDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.endTime.hour,
          firstOccurrence.endTime.minute,
        ),
        'startTime': {'hour': firstOccurrence.startTime.hour, 'minute': firstOccurrence.startTime.minute},
        'endTime': {'hour': firstOccurrence.endTime.hour, 'minute': firstOccurrence.endTime.minute},
        'validFrom': effectiveFrom,
        'validUntil': originalData['validUntil'],
        'lastScheduleChange': effectiveFrom,
        'scheduleChangeReason': 'Swapped with $swapWith',
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
  
    // ─────────────────────────────────────────────
    // MOVE LECTURE (FIXED)
    // ─────────────────────────────────────────────
    Future<void> moveLecture({
      required String lectureId,
      required List<LectureOccurrence> newOccurrences,
      required DateTime effectiveFrom,
      String? reason,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      // Validate each occurrence for conflicts
      for (final occurrence in newOccurrences) {
        final hasConflict = await _hasConflictForOccurrence(
          occurrence: occurrence,
          editingLectureId: lectureId,
        );
  
        if (hasConflict) {
          throw Exception('Move would create schedule conflict on '
              '${_dayName(occurrence.dayOfWeek)} at '
              '${occurrence.formattedStartTime}');
        }
      }
  
      // Validate internal overlaps
      final internalOverlaps = _findInternalOverlaps(newOccurrences);
      if (internalOverlaps.isNotEmpty) {
        throw Exception('Move would create internal overlaps: $internalOverlaps');
      }
  
      final lectureRef = _ref.doc(lectureId);
      final lecture = await lectureRef.get();
      final data = _fromFirestore(lecture);
  
      if (data['isSingleLecture'] == true) {
        throw Exception('Cannot move a single lecture. Please delete and recreate.');
      }
  
      // Sort occurrences
      OccurrenceManager.sortOccurrences(newOccurrences);
  
      // End previous schedule
      await _endScheduleVersion(
          lectureId, effectiveFrom.subtract(const Duration(days: 1)));
  
      // Create new schedule version
      await createScheduleVersionWithOccurrences(
        lectureId: lectureId,
        occurrences: newOccurrences,
        effectiveFrom: effectiveFrom,
        changeReason: reason ?? 'Lecture moved',
      );
  
      // Update main lecture record
      final firstOccurrence = newOccurrences.first;
      final uniqueDays = OccurrenceManager.getUniqueDays(newOccurrences);
  
      await lectureRef.update(_toFirestore({
        'occurrences': newOccurrences.map((o) => o.toMap()).toList(),
        'dayOfWeek': firstOccurrence.dayOfWeek,
        'daysOfWeek': uniqueDays,
        'occurrenceCount': newOccurrences.length,
        'startDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.startTime.hour,
          firstOccurrence.startTime.minute,
        ),
        'endDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.endTime.hour,
          firstOccurrence.endTime.minute,
        ),
        'startTime': {'hour': firstOccurrence.startTime.hour, 'minute': firstOccurrence.startTime.minute},
        'endTime': {'hour': firstOccurrence.endTime.hour, 'minute': firstOccurrence.endTime.minute},
        'validFrom': effectiveFrom,
        'lastScheduleChange': effectiveFrom,
        'scheduleChangeReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }));
  
      await _historyService.recordChange(
        action: 'move',
        lectureData: {
          'id': lectureId,
          'subject': data['subject'],
          'occurrences': newOccurrences.map((o) => o.toMap()).toList(),
          'validFrom': effectiveFrom,
        },
        previousData: data,
        reason: reason ?? 'Lecture moved',
      );
  
      await validateFinalTimetable();
      await _notificationService.rescheduleAllNotifications();
    }
  
    // ─────────────────────────────────────────────
    // DELETE LECTURE (FIXED)
    // ─────────────────────────────────────────────
    Future<void> deleteLecture({
      required String lectureId,
      DateTime? specificDate,
      int? occurrenceIndex,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      final lectureRef = _ref.doc(lectureId);
      final lecture = await lectureRef.get();
  
      if (!lecture.exists) {
        throw Exception('Lecture not found');
      }
  
      final lectureData = _fromFirestore(lecture);
      final isSingleLecture = lectureData['isSingleLecture'] == true;
      final isRecurring = lectureData['isRecurringWeekly'] == true;
  
      // If deleting a specific occurrence
      if (occurrenceIndex != null && specificDate != null) {
        if (!isRecurring) {
          throw Exception('Cannot delete occurrence from a single lecture');
        }
  
        // Get all occurrences
        final occurrences = _getOccurrencesFromLecture(lectureData);
        if (!OccurrenceManager.isValidIndex(occurrences: occurrences, index: occurrenceIndex)) {
          throw Exception('Invalid occurrence index');
        }
        await _notificationService.cancelLectureNotifications(lectureId);
        // Create a schedule version ending before this date for the specific occurrence
        final occurrenceToRemove = occurrences[occurrenceIndex];
        await createScheduleVersionWithOccurrences(
          lectureId: lectureId,
          occurrences: occurrences,
          effectiveFrom: lectureData['validFrom'] as DateTime,
          effectiveUntil: specificDate.subtract(const Duration(days: 1)),
          changeReason: 'Deleted occurrence ${occurrenceIndex + 1}',
        );
  
        // Create new schedule without this occurrence for dates after
        final newOccurrences = List<LectureOccurrence>.from(occurrences);
        newOccurrences.removeAt(occurrenceIndex);
  
        if (newOccurrences.isNotEmpty) {
          await createScheduleVersionWithOccurrences(
            lectureId: lectureId,
            occurrences: newOccurrences,
            effectiveFrom: specificDate,
            effectiveUntil: lectureData['validUntil'] as DateTime? ?? DateTime(2100, 12, 31),
            changeReason: 'After removing occurrence ${occurrenceIndex + 1}',
          );
  
          // Update main lecture record
          await lectureRef.update(_toFirestore({
            'occurrences': newOccurrences.map((o) => o.toMap()).toList(),
            'occurrenceCount': newOccurrences.length,
            'daysOfWeek': OccurrenceManager.getUniqueDays(newOccurrences),
            'updatedAt': FieldValue.serverTimestamp(),
          }));
        } else {
          // No occurrences left, delete the entire lecture
          await _deleteEntireLecture(lectureId);
        }
      } else {
        // Delete entire lecture
        await _deleteEntireLecture(lectureId);
      }
  
      // Record in history
      await _historyService.recordChange(
        action: 'delete',
        lectureData: lectureData,
        reason: occurrenceIndex != null
            ? 'Deleted occurrence ${occurrenceIndex + 1}'
            : 'Deleted lecture',
      );
    }
  
    Future<void> _deleteEntireLecture(String lectureId) async {
      // Delete all schedule versions
      final versionsRef = _ref.doc(lectureId).collection('schedule_versions');
      final versions = await versionsRef.get();
      for (final doc in versions.docs) {
        await doc.reference.delete();
      }
  
      // Delete the lecture
      await _ref.doc(lectureId).delete();
    }
  
    // ─────────────────────────────────────────────
    // SCHEDULE VERSION MANAGEMENT (FIXED)
    // ─────────────────────────────────────────────
    Future<void> createScheduleVersionWithOccurrences({
      required String lectureId,
      required List<LectureOccurrence> occurrences,
      required DateTime effectiveFrom,
      DateTime? effectiveUntil,
      String changeReason = 'Schedule change',
    }) async {
      if (_uid == null) return;
  
      OccurrenceManager.sortOccurrences(occurrences);
  
      final versionId = _versionsRef(lectureId).doc().id;
      final version = LectureScheduleVersion(
        versionId: versionId,
        lectureId: lectureId,
        occurrences: occurrences,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil ?? DateTime(2100, 12, 31),
        changeReason: changeReason,
        createdAt: DateTime.now(),
      );
  
      await _versionsRef(lectureId).doc(versionId).set(_toFirestore(version.toMap()));
    }
  
    Future<void> createScheduleVersion({
      required String lectureId,
      List<int>? daysOfWeek,
      int? dayOfWeek,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
      required DateTime effectiveFrom,
      DateTime? effectiveUntil,
      String changeReason = 'Schedule change',
    }) async {
      final List<int> finalDaysOfWeek;
      if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
        finalDaysOfWeek = daysOfWeek;
      } else if (dayOfWeek != null) {
        finalDaysOfWeek = [dayOfWeek];
      } else {
        throw Exception('Either daysOfWeek or dayOfWeek must be provided');
      }
  
      final occurrences = finalDaysOfWeek.map((day) {
        return LectureOccurrence(
          dayOfWeek: day,
          startTime: startTime,
          endTime: endTime,
        );
      }).toList();
  
      await createScheduleVersionWithOccurrences(
        lectureId: lectureId,
        occurrences: occurrences,
        effectiveFrom: effectiveFrom,
        effectiveUntil: effectiveUntil,
        changeReason: changeReason,
      );
    }
  
    Future<void> _endScheduleVersion(String lectureId, DateTime endDate) async {
      if (_uid == null) return;
  
      // Normalize end date to midnight
      final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);
  
      // Find active versions that extend beyond the end date
      final activeVersions = await _versionsRef(lectureId)
          .where('effectiveUntil', isGreaterThan: normalizedEndDate)
          .get();
  
      for (final doc in activeVersions.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final effectiveFrom = (data['effectiveFrom'] as Timestamp).toDate();
  
        // Only end if the version actually needs to be ended
        if (effectiveFrom.isBefore(normalizedEndDate)) {
          await doc.reference.update({
            'effectiveUntil': normalizedEndDate,
            'isActive': false,
          });
        }
      }
    }
  
    // ─────────────────────────────────────────────
    // GETTERS (FIXED)
    // ─────────────────────────────────────────────
    Future<List<LectureScheduleVersion>> getLectureScheduleVersions(
        String lectureId) async {
      if (_uid == null) return [];
  
      final snap = await _versionsRef(lectureId)
          .orderBy('effectiveFrom')
          .get();
  
      return snap.docs.map((doc) {
        return LectureScheduleVersion.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    }
  
    Future<LectureScheduleVersion?> getActiveScheduleOnDate({
      required String lectureId,
      required DateTime date,
    }) async {
      final versions = await getLectureScheduleVersions(lectureId);
  
      for (final version in versions) {
        if ((date.isAfter(version.effectiveFrom) ||
            date.isAtSameMomentAs(version.effectiveFrom)) &&
            date.isBefore(version.effectiveUntil)) {
          return version;
        }
      }
      return null;
    }
  
    Future<List<LectureOccurrence>> getOccurrencesOnDate({
      required String lectureId,
      required DateTime date,
    }) async {
      final version = await getActiveScheduleOnDate(
        lectureId: lectureId,
        date: date,
      );
  
      if (version == null) return [];
      return version.getOccurrencesOnDate(date);
    }
  
    Future<List<LectureOccurrence>> getAllOccurrences(String lectureId) async {
      final versions = await getLectureScheduleVersions(lectureId);
  
      final allOccurrences = <LectureOccurrence>[];
      for (final version in versions) {
        allOccurrences.addAll(version.occurrences);
      }
  
      return allOccurrences;
    }
  
    List<LectureOccurrence> _getOccurrencesFromLecture(Map<String, dynamic> lecture) {
      final List<LectureOccurrence> occurrences = [];
  
      // Check for new occurrences format
      if (lecture['occurrences'] is List) {
        final occurrencesList = lecture['occurrences'] as List<dynamic>;
        for (final occurrenceMap in occurrencesList) {
          if (occurrenceMap is Map<String, dynamic>) {
            try {
              occurrences.add(LectureOccurrence.fromMap(occurrenceMap));
            } catch (e) {
              print('Error parsing occurrence: $e');
            }
          }
        }
      }
  
      // Fallback to old format
      if (occurrences.isEmpty && lecture['dayOfWeek'] != null) {
        final dayOfWeek = lecture['dayOfWeek'] as int;
        final startTime = lecture['startTime'] is Map<String, dynamic>
            ? TimeOfDay(
          hour: lecture['startTime']['hour'] ?? 9,
          minute: lecture['startTime']['minute'] ?? 0,
        )
            : TimeOfDay(hour: 9, minute: 0);
        final endTime = lecture['endTime'] is Map<String, dynamic>
            ? TimeOfDay(
          hour: lecture['endTime']['hour'] ?? 10,
          minute: lecture['endTime']['minute'] ?? 0,
        )
            : TimeOfDay(hour: 10, minute: 0);
  
        final room = lecture['room'] as String? ?? lecture['defaultRoom'] as String?;
        final topic = lecture['topic'] as String? ?? lecture['defaultTopic'] as String?;
  
        occurrences.add(LectureOccurrence(
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          room: room,
          topic: topic,
        ));
      }
  
      return occurrences;
    }
  
    // ─────────────────────────────────────────────
    // STREAMS (FIXED)
    // ─────────────────────────────────────────────
    Stream<List<Map<String, dynamic>>> getTodaysLecturesStream() {
      if (_uid == null) return const Stream.empty();
  
      final today = DateTime.now();
  
      return _firestore
          .collection('users')
          .doc(_uid!)
          .collection('lectures')
          .snapshots()
          .map((snap) {
        final all = snap.docs.map(_convertLecture).toList();
  
        return all.where((lecture) {
          // Single lecture
          if (lecture['isSingleLecture'] == true &&
              lecture['specificDate'] is DateTime) {
            final d = lecture['specificDate'] as DateTime;
            return _isSameDay(d, today);
          }
  
          // Weekly lecture
          if (lecture['isRecurringWeekly'] == true) {
            final validFrom = lecture['validFrom'] as DateTime?;
            final validUntil = lecture['validUntil'] as DateTime?;
  
            if (validFrom == null || validUntil == null) return false;
            if (today.isBefore(validFrom) || today.isAfter(validUntil)) return false;
  
            final occurrences = _getOccurrencesFromLecture(lecture);
            return occurrences.any((o) => o.dayOfWeek == today.weekday);
          }
  
          return false;
        }).toList();
      });
    }
  
    Stream<Map<int, List<Map<String, dynamic>>>> getWeeklyTimetableStream() {
      if (_uid == null) return const Stream.empty();
  
      return _firestore
          .collection('users')
          .doc(_uid!)
          .collection('lectures')
          .where('isRecurringWeekly', isEqualTo: true)
          .snapshots()
          .map((snap) {
        final Map<int, List<Map<String, dynamic>>> week = {
          1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []
        };
  
        for (final doc in snap.docs) {
          final data = _convertLecture(doc);
          final occurrences = _getOccurrencesFromLecture(data);
  
          for (final occurrence in occurrences) {
            final occurrenceData = Map<String, dynamic>.from(data);
            occurrenceData['occurrence'] = occurrence;
            occurrenceData['occurrenceStartTime'] = occurrence.startTime;
            occurrenceData['occurrenceEndTime'] = occurrence.endTime;
            occurrenceData['occurrenceRoom'] = occurrence.room ?? data['room'];
            occurrenceData['occurrenceTopic'] = occurrence.topic ?? data['topic'];
  
            week[occurrence.dayOfWeek]!.add(occurrenceData);
          }
        }
  
        // sort by start time within each day
        for (final day in week.keys) {
          week[day]!.sort((a, b) {
            final aStart = a['occurrenceStartTime'] as TimeOfDay;
            final bStart = b['occurrenceStartTime'] as TimeOfDay;
            final aStartMin = aStart.hour * 60 + aStart.minute;
            final bStartMin = bStart.hour * 60 + bStart.minute;
            return aStartMin.compareTo(bStartMin);
          });
        }
  
        return week;
      });
    }
  
    Stream<List<Map<String, dynamic>>> getLecturesForDayStream(int weekday) {
      if (_uid == null) return const Stream.empty();
  
      return _firestore
          .collection('users')
          .doc(_uid!)
          .collection('lectures')
          .where('isRecurringWeekly', isEqualTo: true)
          .snapshots()
          .map((snap) {
        final lectures = snap.docs.map(_convertLecture).toList();
  
        return lectures.where((lecture) {
          final occurrences = _getOccurrencesFromLecture(lecture);
          return occurrences.any((o) => o.dayOfWeek == weekday);
        }).map((lecture) {
          final occurrences = _getOccurrencesFromLecture(lecture);
          final dayOccurrences = occurrences.where((o) => o.dayOfWeek == weekday).toList();
  
          return dayOccurrences.map((occurrence) {
            final occurrenceData = Map<String, dynamic>.from(lecture);
            occurrenceData['occurrence'] = occurrence;
            occurrenceData['occurrenceStartTime'] = occurrence.startTime;
            occurrenceData['occurrenceEndTime'] = occurrence.endTime;
            occurrenceData['occurrenceRoom'] = occurrence.room ?? lecture['room'];
            occurrenceData['occurrenceTopic'] = occurrence.topic ?? lecture['topic'];
            return occurrenceData;
          }).toList();
        }).expand((x) => x).toList();
      });
    }
  
    // ─────────────────────────────────────────────
    // VALIDATION (FIXED)
    // ─────────────────────────────────────────────
    Future<bool> hasConflictForSpecificDate({
      required DateTime date,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
      String? editingLectureId,
    }) async {
      if (_uid == null) return false;
  
      final occurrence = LectureOccurrence(
        dayOfWeek: date.weekday,
        startTime: startTime,
        endTime: endTime,
      );
  
      final snap = await _ref.where('dayOfWeek', isEqualTo: date.weekday).get();
  
      for (final doc in snap.docs) {
        if (doc.id == editingLectureId) continue;
  
        final lecture = _fromFirestore(doc);
  
        // Skip if it's a single lecture that doesn't match the date
        if (lecture['isSingleLecture'] == true) {
          final specificDate = lecture['specificDate'] as DateTime?;
          if (specificDate == null || !_isSameDay(specificDate, date)) continue;
        }
        // For recurring lectures, check if occurs on this date
        else if (lecture['isRecurringWeekly'] == true) {
          final validFrom = lecture['validFrom'] as DateTime?;
          final validUntil = lecture['validUntil'] as DateTime?;
  
          if (validFrom == null || validUntil == null) continue;
          if (date.isBefore(validFrom) || date.isAfter(validUntil)) continue;
  
          final occurrences = _getOccurrencesFromLecture(lecture);
          final hasOccurrenceOnThisDay = occurrences.any((o) => o.dayOfWeek == date.weekday);
          if (!hasOccurrenceOnThisDay) continue;
        }
  
        // Check for overlaps
        final lectureOccurrences = _getOccurrencesFromLecture(lecture);
        for (final existingOccurrence in lectureOccurrences) {
          if (existingOccurrence.dayOfWeek != date.weekday) continue;
  
          if (existingOccurrence.overlapsWith(occurrence)) {
            return true;
          }
        }
      }
  
      return false;
    }
  
    Future<bool> hasConflict({
      required int dayOfWeek,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
      String? editingLectureId,
      bool allowTemporaryOverlap = false,
    }) async {
      if (_uid == null) return false;
  
      final occurrence = LectureOccurrence(
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );
  
      final snap = await _ref.where('dayOfWeek', isEqualTo: dayOfWeek).get();
  
      for (final doc in snap.docs) {
        if (doc.id == editingLectureId) continue;
  
        final lecture = _fromFirestore(doc);
  
        if (lecture['isSingleLecture'] == true) continue;
  
        final occurrences = _getOccurrencesFromLecture(lecture);
  
        for (final existingOccurrence in occurrences) {
          if (existingOccurrence.dayOfWeek != dayOfWeek) continue;
  
          if (existingOccurrence.overlapsWith(occurrence)) {
            if (allowTemporaryOverlap && editingLectureId != null) {
              return false;
            }
            return true;
          }
        }
      }
      return false;
    }
  
    Future<void> validateFinalTimetable() async {
      if (_uid == null) return;
  
      final snap = await _ref.get();
      final lectures = snap.docs.map(_fromFirestore).toList();
  
      final Map<int, List<Map<String, dynamic>>> occurrencesByDay = {};
  
      for (final lecture in lectures) {
        if (lecture['isRecurringWeekly'] != true) continue;
  
        final occurrences = _getOccurrencesFromLecture(lecture);
  
        for (final occurrence in occurrences) {
          final day = occurrence.dayOfWeek;
          occurrencesByDay.putIfAbsent(day, () => []).add({
            'lectureId': lecture['id'],
            'subject': lecture['subject'],
            'occurrence': occurrence,
            'validFrom': lecture['validFrom'] as DateTime?,
            'validUntil': lecture['validUntil'] as DateTime?,
          });
        }
      }
  
      for (final day in occurrencesByDay.keys) {
        final dayOccurrences = occurrencesByDay[day]!;
  
        for (int i = 0; i < dayOccurrences.length; i++) {
          for (int j = i + 1; j < dayOccurrences.length; j++) {
            final a = dayOccurrences[i];
            final b = dayOccurrences[j];
  
            if (a['lectureId'] == b['lectureId']) continue;
  
            final aFrom = a['validFrom'] as DateTime?;
            final aUntil = a['validUntil'] as DateTime?;
            final bFrom = b['validFrom'] as DateTime?;
            final bUntil = b['validUntil'] as DateTime?;
  
            if (aFrom == null || aUntil == null ||
                bFrom == null || bUntil == null) continue;
  
            if (aFrom.isAfter(bUntil) || aUntil.isBefore(bFrom)) {
              continue;
            }
  
            final aOccurrence = a['occurrence'] as LectureOccurrence;
            final bOccurrence = b['occurrence'] as LectureOccurrence;
  
            if (aOccurrence.overlapsWith(bOccurrence)) {
              throw Exception("Final timetable has overlapping lectures: "
                  "${a['subject']} and ${b['subject']} on ${_dayName(day)} "
                  "(${aOccurrence.timeRange} "
                  "vs ${bOccurrence.timeRange})");
            }
          }
        }
      }
    }
  
    // Add this method to LectureService class in lecture_service.dart
    Future<void> swapOccurrences({
      required String lectureAId,
      required int occurrenceIndexA,
      required String lectureBId,
      required int occurrenceIndexB,
    }) async {
      if (_uid == null) throw Exception('User not authenticated');
  
      try {
        // Get both lectures
        final aSnap = await _ref.doc(lectureAId).get();
        final bSnap = await _ref.doc(lectureBId).get();
  
        if (!aSnap.exists || !bSnap.exists) {
          throw Exception('One or both lectures not found');
        }
  
        final aData = _fromFirestore(aSnap);
        final bData = _fromFirestore(bSnap);
  
        // Get occurrences
        final aOccurrences = _getOccurrencesFromLecture(aData);
        final bOccurrences = _getOccurrencesFromLecture(bData);
  
        // Validate indices
        if (!OccurrenceManager.isValidIndex(occurrences: aOccurrences, index: occurrenceIndexA) ||
            !OccurrenceManager.isValidIndex(occurrences: bOccurrences, index: occurrenceIndexB)) {
          throw Exception('Invalid occurrence index');
        }
  
        // Extract the specific occurrences to swap
        final occurrenceA = aOccurrences[occurrenceIndexA];
        final occurrenceB = bOccurrences[occurrenceIndexB];
  
        // Create new occurrence lists with swapped times/days
        final newAOccurrences = List<LectureOccurrence>.from(aOccurrences);
        final newBOccurrences = List<LectureOccurrence>.from(bOccurrences);
  
        // Swap only the specific occurrence details (time, day)
        newAOccurrences[occurrenceIndexA] = occurrenceA.copyWith(
          dayOfWeek: occurrenceB.dayOfWeek,
          startTime: occurrenceB.startTime,
          endTime: occurrenceB.endTime,
        );
  
        newBOccurrences[occurrenceIndexB] = occurrenceB.copyWith(
          dayOfWeek: occurrenceA.dayOfWeek,
          startTime: occurrenceA.startTime,
          endTime: occurrenceA.endTime,
        );
  
        // Get active schedule versions
        final aVersions = await getLectureScheduleVersions(lectureAId);
        final bVersions = await getLectureScheduleVersions(lectureBId);
  
        final effectiveFrom = DateTime.now();
        final yesterday = effectiveFrom.subtract(const Duration(days: 1));
  
        // End previous schedule versions
        await _endScheduleVersion(lectureAId, yesterday);
        await _endScheduleVersion(lectureBId, yesterday);
  
        // Create new schedule versions with swapped occurrences
        await createScheduleVersionWithOccurrences(
          lectureId: lectureAId,
          occurrences: newAOccurrences,
          effectiveFrom: effectiveFrom,
          effectiveUntil: aData['validUntil'] as DateTime? ?? DateTime(2100, 12, 31),
          changeReason: 'Swapped occurrence ${occurrenceIndexA + 1} with ${bData['subject']} occurrence ${occurrenceIndexB + 1}',
        );
  
        await createScheduleVersionWithOccurrences(
          lectureId: lectureBId,
          occurrences: newBOccurrences,
          effectiveFrom: effectiveFrom,
          effectiveUntil: bData['validUntil'] as DateTime? ?? DateTime(2100, 12, 31),
          changeReason: 'Swapped occurrence ${occurrenceIndexB + 1} with ${aData['subject']} occurrence ${occurrenceIndexA + 1}',
        );
  
        // Update main lecture records
        await _updateLectureAfterOccurrenceSwap(
          lectureId: lectureAId,
          newOccurrences: newAOccurrences,
          originalData: aData,
          effectiveFrom: effectiveFrom,
        );
  
        await _updateLectureAfterOccurrenceSwap(
          lectureId: lectureBId,
          newOccurrences: newBOccurrences,
          originalData: bData,
          effectiveFrom: effectiveFrom,
        );
  
        // Record history
        await _historyService.recordChange(
          action: 'swap_occurrence',
          lectureData: {
            'id': lectureAId,
            'subject': aData['subject'],
            'occurrences': newAOccurrences.map((o) => o.toMap()).toList(),
            'validFrom': effectiveFrom,
          },
          previousData: aData,
          previousLectureId: lectureBId,
          reason: 'Swapped occurrence ${occurrenceIndexA + 1} with ${bData['subject']} occurrence ${occurrenceIndexB + 1}',
        );
  
        await _historyService.recordChange(
          action: 'swap_occurrence',
          lectureData: {
            'id': lectureBId,
            'subject': bData['subject'],
            'occurrences': newBOccurrences.map((o) => o.toMap()).toList(),
            'validFrom': effectiveFrom,
          },
          previousData: bData,
          previousLectureId: lectureAId,
          reason: 'Swapped occurrence ${occurrenceIndexB + 1} with ${aData['subject']} occurrence ${occurrenceIndexA + 1}',
        );
  
        // Validate final timetable
        await validateFinalTimetable();
        await _notificationService.rescheduleAllNotifications();
  
      } catch (e) {
        print('❌ Error swapping occurrences: $e');
        rethrow;
      }
    }
  
  // Helper method to update lecture after occurrence swap
    Future<void> _updateLectureAfterOccurrenceSwap({
      required String lectureId,
      required List<LectureOccurrence> newOccurrences,
      required Map<String, dynamic> originalData,
      required DateTime effectiveFrom,
    }) async {
      if (newOccurrences.isEmpty) return;
  
      final ref = _ref.doc(lectureId);
      final firstOccurrence = newOccurrences.first;
      final uniqueDays = OccurrenceManager.getUniqueDays(newOccurrences);
  
      await ref.update(_toFirestore({
        'occurrences': newOccurrences.map((o) => o.toMap()).toList(),
        'dayOfWeek': firstOccurrence.dayOfWeek,
        'daysOfWeek': uniqueDays,
        'occurrenceCount': newOccurrences.length,
        'startDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.startTime.hour,
          firstOccurrence.startTime.minute,
        ),
        'endDateTime': DateTime(
          effectiveFrom.year,
          effectiveFrom.month,
          effectiveFrom.day,
          firstOccurrence.endTime.hour,
          firstOccurrence.endTime.minute,
        ),
        'startTime': {'hour': firstOccurrence.startTime.hour, 'minute': firstOccurrence.startTime.minute},
        'endTime': {'hour': firstOccurrence.endTime.hour, 'minute': firstOccurrence.endTime.minute},
        'validFrom': effectiveFrom,
        'lastScheduleChange': effectiveFrom,
        'scheduleChangeReason': 'Occurrence swap',
        'updatedAt': FieldValue.serverTimestamp(),
      }));
    }
  
    Future<void> validateVersionNonOverlap(String lectureId) async {
      final versions = await getLectureScheduleVersions(lectureId);
      versions.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
  
      for (int i = 1; i < versions.length; i++) {
        final prev = versions[i - 1];
        final current = versions[i];
  
        if (current.effectiveFrom.isBefore(prev.effectiveUntil)) {
          print('⚠️ Warning: Schedule versions overlap for lecture $lectureId');
          print('  Previous: ${prev.effectiveFrom} to ${prev.effectiveUntil}');
          print('  Current: ${current.effectiveFrom} to ${current.effectiveUntil}');
  
          // Auto-fix by ending previous version one day before current starts
          final fixDate = current.effectiveFrom.subtract(const Duration(days: 1));
          final prevRef = _versionsRef(lectureId).doc(prev.versionId);
          await prevRef.update({
            'effectiveUntil': fixDate,
            'isActive': fixDate.isAfter(prev.effectiveFrom),
          });
  
          print('  Fixed: Previous version now ends at $fixDate');
        }
      }
    }
    // ─────────────────────────────────────────────
    // HELPERS (FIXED)
    // ─────────────────────────────────────────────
    Map<String, dynamic> _convertLecture(DocumentSnapshot doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['id'] = doc.id;
  
      if (data['occurrences'] is List) {
        try {
          final occurrencesList = data['occurrences'] as List<dynamic>;
          final occurrences = occurrencesList.map((item) {
            if (item is Map<String, dynamic>) {
              return LectureOccurrence.fromMap(item);
            }
            return LectureOccurrence(
              dayOfWeek: 1,
              startTime: TimeOfDay(hour: 9, minute: 0),
              endTime: TimeOfDay(hour: 10, minute: 0),
            );
          }).toList();
          data['occurrencesList'] = occurrences;
        } catch (e) {
          print('Error converting occurrences: $e');
        }
      }
  
      if (data['daysOfWeek'] is List) {
        data['daysOfWeek'] = List<int>.from(data['daysOfWeek']);
      } else if (data['dayOfWeek'] != null) {
        data['daysOfWeek'] = [data['dayOfWeek'] as int];
      }
  
      final timestampFields = [
        'startDateTime',
        'endDateTime',
        'validFrom',
        'validUntil',
        'specificDate',
      ];
  
      for (final field in timestampFields) {
        if (data[field] is Timestamp) {
          data[field] = (data[field] as Timestamp).toDate();
        }
      }
  
      return data;
    }
  
    Map<String, dynamic> _fromFirestore(DocumentSnapshot doc) {
      return _convertLecture(doc);
    }
  
    Map<String, dynamic> _toFirestore(Map<String, dynamic> data) {
      final m = Map<String, dynamic>.from(data);
  
      if (m['occurrences'] is List<LectureOccurrence>) {
        m['occurrences'] = (m['occurrences'] as List<LectureOccurrence>)
            .map((o) => o.toMap())
            .toList();
      }
  
      for (final k in [
        'startDateTime',
        'endDateTime',
        'validFrom',
        'validUntil',
        'specificDate',
        'effectiveFrom',
        'effectiveUntil',
        'createdAt',
      ]) {
        if (m[k] is DateTime) {
          m[k] = Timestamp.fromDate(m[k]);
        }
      }
  
      return m;
    }
  
    DateTime _nextWeekday(DateTime from, int weekday) {
      var d = DateTime(from.year, from.month, from.day);
      while (d.weekday != weekday) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }
  
    bool _isSameDay(DateTime a, DateTime b) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }
  
    String _dayName(int dayOfWeek) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'];
      return days[dayOfWeek - 1];
    }
  
    Future<List<Map<String, dynamic>>> fetchAllLecturesOnce() async {
      if (_uid == null) return [];
  
      final snap = await _firestore
          .collection('users')
          .doc(_uid!)
          .collection('lectures')
          .get();
  
      return snap.docs.map(_convertLecture).toList();
    }
  }