// timetable_history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:presence01/services/lecture_service.dart';

class TimetableHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _historyRef =>
      _firestore.collection('users').doc(_uid).collection('timetable_history');



  Future<void> recordChange({
    required String action,
    required Map<String, dynamic> lectureData,
    String? previousLectureId,
    Map<String, dynamic>? previousData,
    String? reason,
  }) async {
    if (_uid == null) return;

    // Use deepSerialize for both current and previous data
    final safeLectureData = _deepSerialize(lectureData);
    final safePreviousData = previousData != null ? _deepSerialize(previousData) : null;

    // Clean up any remaining problematic fields
    final fieldsToRemove = [
      '__start', '__end', 'occurrence', 'occurrenceList',
      'occurrenceStartTime', 'occurrenceEndTime'
    ];

    for (final field in fieldsToRemove) {
      safeLectureData.remove(field);
      safePreviousData?.remove(field);
    }

    await _historyRef.add({
      'action': action,
      'lectureId': safeLectureData['id'],
      'lectureSubject': safeLectureData['subject'],
      'newData': safeLectureData,
      'previousData': safePreviousData,
      'previousLectureId': previousLectureId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _uid,
    });
  }

  Future<Map<String, dynamic>> _serializeData(Map<String, dynamic> data) async {
    final result = Map<String, dynamic>.from(data);

    // Handle occurrences serialization PROPERLY
    if (result.containsKey('occurrences')) {
      final occurrences = result['occurrences'];

      // Case 1: Already a List<Map<String, dynamic>>
      if (occurrences is List<Map<String, dynamic>>) {
        // Already serialized, keep as is
        result['occurrences'] = occurrences;
      }
      // Case 2: List<LectureOccurrence> - NEED TO CONVERT
      else if (occurrences is List<LectureOccurrence>) {
        // Convert each LectureOccurrence to Map
        result['occurrences'] = occurrences.map((occ) => occ.toMap()).toList();
      }
      // Case 3: Any other List type
      else if (occurrences is List) {
        final List<Map<String, dynamic>> serialized = [];
        for (final item in occurrences) {
          if (item is LectureOccurrence) {
            serialized.add(item.toMap());
          } else if (item is Map<String, dynamic>) {
            serialized.add(item);
          } else {
            print('⚠️ Unknown occurrence type: ${item.runtimeType}');
          }
        }
        result['occurrences'] = serialized;
      }
    }

    // Convert DateTime to ISO string
    for (final key in result.keys.toList()) {
      final value = result[key];

      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is TimeOfDay) {
        // Handle TimeOfDay serialization
        result[key] = {'hour': value.hour, 'minute': value.minute};
      }
    }

    // Remove problematic fields
    final problematicFields = [
      '__start', '__end', 'occurrence', 'occurrenceList',
      'occurrenceStartTime', 'occurrenceEndTime'
    ];

    for (final field in problematicFields) {
      result.remove(field);
    }

    return result;
  }

  // Add this comprehensive serialization method
  Map<String, dynamic> _deepSerialize(Map<String, dynamic> data) {
    final result = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        result[key] = null;
      } else if (value is String || value is num || value is bool) {
        result[key] = value;
      } else if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is TimeOfDay) {
        result[key] = {'hour': value.hour, 'minute': value.minute};
      } else if (value is LectureOccurrence) {
        result[key] = value.toMap();
      } else if (value is Map<String, dynamic>) {
        result[key] = _deepSerialize(value);
      } else if (value is Map) {
        // Convert any map to Map<String, dynamic>
        final map = <String, dynamic>{};
        for (final mapEntry in value.entries) {
          if (mapEntry.key is String) {
            map[mapEntry.key as String] = mapEntry.value;
          }
        }
        result[key] = _deepSerialize(map);
      } else if (value is List) {
        result[key] = _serializeList(value);
      } else {
        // Skip objects that can't be serialized
        print('⚠️ Skipping unsupported type for key $key: ${value.runtimeType}');
      }
    }

    return result;
  }

  List<dynamic> _serializeList(List<dynamic> list) {
    return list.map((item) {
      if (item == null) return null;
      if (item is String || item is num || item is bool) return item;
      if (item is DateTime) return item.toIso8601String();
      if (item is Timestamp) return item.toDate().toIso8601String();
      if (item is TimeOfDay) return {'hour': item.hour, 'minute': item.minute};
      if (item is LectureOccurrence) return item.toMap();
      if (item is Map<String, dynamic>) return _deepSerialize(item);
      if (item is Map) {
        final map = <String, dynamic>{};
        for (final entry in (item as Map).entries) {
          if (entry.key is String) {
            map[entry.key as String] = entry.value;
          }
        }
        return _deepSerialize(map);
      }
      if (item is List) return _serializeList(item);

      print('⚠️ Skipping unsupported list item type: ${item.runtimeType}');
      return null;
    }).toList();
  }

  // Get timetable history
  Stream<List<Map<String, dynamic>>> getTimetableHistory() {
    if (_uid == null) return Stream.value([]);

    return _historyRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        ...data,
        'id': doc.id,
        'timestamp': data['timestamp'],
      };
    }).toList());
  }

  // Get lecture-specific history
  Stream<List<Map<String, dynamic>>> getLectureHistory(String lectureId) {
    if (_uid == null) return Stream.value([]);

    return _historyRef
        .where('lectureId', isEqualTo: lectureId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        ...data,
        'id': doc.id,
        'timestamp': data['timestamp'],
      };
    }).toList());
  }

  // Helper to remove circular references from data
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);

    // Remove fields that might cause issues
    sanitized.remove('id');
    sanitized.remove('__start');
    sanitized.remove('__end');

    // Convert DateTime to String for storage
    for (final key in sanitized.keys) {
      if (sanitized[key] is DateTime) {
        sanitized[key] = (sanitized[key] as DateTime).toIso8601String();
      }
    }

    return sanitized;
  }
}