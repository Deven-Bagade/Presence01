// // lib/widgets/move_lecture_dialog.dart - UPDATED FOR MULTIPLE OCCURRENCES
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../services/lecture_service.dart';
//
// class MoveLectureDialog extends StatefulWidget {
//   final Map<String, dynamic> lecture;
//   final VoidCallback onMoved;
//
//   const MoveLectureDialog({
//     super.key,
//     required this.lecture,
//     required this.onMoved,
//   });
//
//   @override
//   State<MoveLectureDialog> createState() => _MoveLectureDialogState();
// }
//
// class _MoveLectureDialogState extends State<MoveLectureDialog> {
//   final LectureService _lectureService = LectureService();
//   DateTime? _effectiveDate;
//   List<LectureOccurrence> _occurrences = []; // CHANGED: Use occurrences list
//   final TextEditingController _reasonController = TextEditingController();
//   bool _isMoving = false;
//
//   final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//   final List<String> fullDays = [
//     'Monday', 'Tuesday', 'Wednesday', 'Thursday',
//     'Friday', 'Saturday', 'Sunday'
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _effectiveDate = DateTime.now();
//
//     // Extract current occurrences from lecture
//     _loadOccurrencesFromLecture();
//   }
//
//   void _loadOccurrencesFromLecture() {
//     final lectureData = widget.lecture;
//
//     // Try to load from occurrences field (new format)
//     if (lectureData['occurrences'] is List) {
//       final occurrencesList = lectureData['occurrences'] as List<dynamic>;
//       for (final item in occurrencesList) {
//         if (item is Map<String, dynamic>) {
//           try {
//             _occurrences.add(LectureOccurrence.fromMap(item));
//           } catch (e) {
//             print('Error parsing occurrence: $e');
//           }
//         }
//       }
//     }
//
//     // If no occurrences loaded, try old format or create default
//     if (_occurrences.isEmpty) {
//       final dayOfWeek = lectureData['dayOfWeek'] as int? ?? DateTime.now().weekday;
//
//       final startTime = lectureData['startTime'] is Map<String, dynamic>
//           ? TimeOfDay(
//         hour: lectureData['startTime']['hour'] ?? 9,
//         minute: lectureData['startTime']['minute'] ?? 0,
//       )
//           : TimeOfDay(hour: 9, minute: 0);
//
//       final endTime = lectureData['endTime'] is Map<String, dynamic>
//           ? TimeOfDay(
//         hour: lectureData['endTime']['hour'] ?? 10,
//         minute: lectureData['endTime']['minute'] ?? 0,
//       )
//           : TimeOfDay(hour: 10, minute: 0);
//
//       final room = lectureData['room'] as String? ?? lectureData['defaultRoom'] as String?;
//       final topic = lectureData['topic'] as String? ?? lectureData['defaultTopic'] as String?;
//
//       _occurrences.add(LectureOccurrence(
//         dayOfWeek: dayOfWeek,
//         startTime: startTime,
//         endTime: endTime,
//         room: room,
//         topic: topic,
//       ));
//     }
//   }
//
//   Future<void> _moveLecture() async {
//     if (_effectiveDate == null || _occurrences.isEmpty) {
//       _showError("Please configure at least one occurrence");
//       return;
//     }
//
//     // Validate each occurrence
//     for (final occurrence in _occurrences) {
//       final startMin = occurrence.startTime.hour * 60 + occurrence.startTime.minute;
//       final endMin = occurrence.endTime.hour * 60 + occurrence.endTime.minute;
//       if (endMin <= startMin) {
//         _showError("End time must be after start time for all occurrences");
//         return;
//       }
//     }
//
//     // Check for conflicts between occurrences of the same lecture
//     for (int i = 0; i < _occurrences.length; i++) {
//       for (int j = i + 1; j < _occurrences.length; j++) {
//         final a = _occurrences[i];
//         final b = _occurrences[j];
//
//         if (a.dayOfWeek == b.dayOfWeek) {
//           final aStart = a.startTime.hour * 60 + a.startTime.minute;
//           final aEnd = a.endTime.hour * 60 + a.endTime.minute;
//           final bStart = b.startTime.hour * 60 + b.startTime.minute;
//           final bEnd = b.endTime.hour * 60 + b.endTime.minute;
//
//           if (aStart < bEnd && aEnd > bStart) {
//             _showError("Lecture cannot have overlapping occurrences on the same day");
//             return;
//           }
//         }
//       }
//     }
//
//     setState(() => _isMoving = true);
//
//     try {
//       await _lectureService.moveLecture(
//         lectureId: widget.lecture['id'],
//         newOccurrences: _occurrences, // CHANGED: Pass occurrences list
//         effectiveFrom: _effectiveDate!,
//         reason: _reasonController.text.trim().isNotEmpty
//             ? _reasonController.text.trim()
//             : "Timetable change",
//       );
//
//       widget.onMoved();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Lecture moved successfully")),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       if (mounted) {
//         _showError("Error: $e");
//       }
//     } finally {
//       if (mounted) {
//         setState(() => _isMoving = false);
//       }
//     }
//   }
//
//   void _addOccurrence() {
//     setState(() {
//       _occurrences.add(LectureOccurrence(
//         dayOfWeek: DateTime.now().weekday,
//         startTime: TimeOfDay.now(),
//         endTime: TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: TimeOfDay.now().minute),
//       ));
//     });
//   }
//
//   void _removeOccurrence(int index) {
//     setState(() {
//       _occurrences.removeAt(index);
//     });
//   }
//
//   void _updateOccurrence(int index, LectureOccurrence updated) {
//     setState(() {
//       _occurrences[index] = updated;
//     });
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message)),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               "Move Lecture",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//
//             // Effective Date
//             ListTile(
//               title: Text(
//                 _effectiveDate == null
//                     ? "Select effective date"
//                     : "Effective from: ${DateFormat.yMMMd().format(_effectiveDate!)}",
//               ),
//               trailing: const Icon(Icons.calendar_today),
//               onTap: () async {
//                 final date = await showDatePicker(
//                   context: context,
//                   initialDate: _effectiveDate ?? DateTime.now(),
//                   firstDate: DateTime.now(),
//                   lastDate: DateTime(2100),
//                 );
//                 if (date != null) {
//                   setState(() => _effectiveDate = date);
//                 }
//               },
//             ),
//
//             const SizedBox(height: 16),
//
//             // Occurrences Section Header
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text("Occurrences:", style: TextStyle(fontWeight: FontWeight.w500)),
//                 ElevatedButton.icon(
//                   icon: const Icon(Icons.add, size: 16),
//                   label: const Text("Add"),
//                   onPressed: _addOccurrence,
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 8),
//
//             if (_occurrences.isEmpty)
//               _buildEmptyOccurrences()
//             else
//               ..._occurrences.asMap().entries.map((entry) {
//                 return _buildOccurrenceCard(entry.key, entry.value);
//               }).toList(),
//
//             // Show summary if there are occurrences
//             if (_occurrences.isNotEmpty)
//               _buildOccurrencesSummary(),
//
//             const SizedBox(height: 16),
//
//             // Reason
//             TextField(
//               controller: _reasonController,
//               decoration: const InputDecoration(
//                 labelText: "Reason (optional)",
//                 border: OutlineInputBorder(),
//                 hintText: "Why are you moving this lecture?",
//               ),
//               maxLines: 2,
//             ),
//
//             const SizedBox(height: 24),
//
//             // Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 TextButton(
//                   onPressed: _isMoving ? null : () => Navigator.pop(context),
//                   child: const Text("Cancel"),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: _isMoving ? null : _moveLecture,
//                   child: _isMoving
//                       ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                       : const Text("Move Lecture"),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmptyOccurrences() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade100,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
//       ),
//       child: Column(
//         children: [
//           Icon(Icons.schedule, size: 40, color: Colors.grey.shade400),
//           const SizedBox(height: 8),
//           const Text(
//             "No occurrences added",
//             style: TextStyle(color: Colors.grey),
//           ),
//           const SizedBox(height: 4),
//           const Text(
//             "Add at least one weekly occurrence",
//             style: TextStyle(fontSize: 12, color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOccurrenceCard(int index, LectureOccurrence occurrence) {
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Occurrence ${index + 1}',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 if (_occurrences.length > 1)
//                   IconButton(
//                     icon: const Icon(Icons.delete, color: Colors.red, size: 20),
//                     onPressed: () => _removeOccurrence(index),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 12),
//
//             // Day selector
//             Row(
//               children: [
//                 const Icon(Icons.calendar_today, size: 20),
//                 const SizedBox(width: 8),
//                 const Text('Day:', style: TextStyle(fontWeight: FontWeight.w500)),
//                 const SizedBox(width: 8),
//                 DropdownButton<int>(
//                   value: occurrence.dayOfWeek,
//                   items: List.generate(7, (i) {
//                     return DropdownMenuItem<int>(
//                       value: i + 1,
//                       child: Text('${days[i]} (${fullDays[i]})'),
//                     );
//                   }),
//                   onChanged: (value) {
//                     if (value != null) {
//                       _updateOccurrence(index, occurrence.copyWith(dayOfWeek: value));
//                     }
//                   },
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 12),
//
//             // Time selectors
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildTimeSelector(
//                     title: "Start Time",
//                     time: occurrence.startTime,
//                     onTap: () => _pickOccurrenceTime(index, true),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildTimeSelector(
//                     title: "End Time",
//                     time: occurrence.endTime,
//                     onTap: () => _pickOccurrenceTime(index, false),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 12),
//
//             // Room override (optional)
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Room (optional override)',
//                 hintText: 'Leave empty to use default room',
//                 border: OutlineInputBorder(),
//                 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               ),
//               controller: TextEditingController(text: occurrence.room ?? ''),
//               onChanged: (value) {
//                 _updateOccurrence(index, occurrence.copyWith(room: value.isEmpty ? null : value));
//               },
//             ),
//
//             const SizedBox(height: 8),
//
//             // Topic override (optional)
//             TextField(
//               decoration: const InputDecoration(
//                 labelText: 'Topic (optional override)',
//                 hintText: 'Leave empty to use default topic',
//                 border: OutlineInputBorder(),
//                 contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//               ),
//               controller: TextEditingController(text: occurrence.topic ?? ''),
//               onChanged: (value) {
//                 _updateOccurrence(index, occurrence.copyWith(topic: value.isEmpty ? null : value));
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTimeSelector({
//     required String title,
//     required TimeOfDay time,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.grey.shade50,
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.grey.shade300),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 color: Colors.grey,
//                 fontSize: 12,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               _formatTimeOfDay(time),
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _pickOccurrenceTime(int index, bool isStartTime) async {
//     final currentTime = isStartTime
//         ? _occurrences[index].startTime
//         : _occurrences[index].endTime;
//
//     final time = await showTimePicker(
//       context: context,
//       initialTime: currentTime,
//     );
//
//     if (time != null) {
//       setState(() {
//         final occurrence = _occurrences[index];
//         final updated = isStartTime
//             ? occurrence.copyWith(startTime: time)
//             : occurrence.copyWith(endTime: time);
//         _updateOccurrence(index, updated);
//       });
//     }
//   }
//
//   Widget _buildOccurrencesSummary() {
//     // Group occurrences by day
//     final Map<int, List<LectureOccurrence>> occurrencesByDay = {};
//     for (final occurrence in _occurrences) {
//       occurrencesByDay.putIfAbsent(occurrence.dayOfWeek, () => []).add(occurrence);
//     }
//
//     // Sort days
//     final sortedDays = occurrencesByDay.keys.toList()..sort();
//
//     return Card(
//       color: Colors.blue.shade50,
//       margin: const EdgeInsets.only(top: 12),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Schedule Summary',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             ...sortedDays.map((day) {
//               final dayOccurrences = occurrencesByDay[day]!;
//               dayOccurrences.sort((a, b) {
//                 final aStart = a.startTime.hour * 60 + a.startTime.minute;
//                 final bStart = b.startTime.hour * 60 + b.startTime.minute;
//                 return aStart.compareTo(bStart);
//               });
//
//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     fullDays[day - 1],
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w600,
//                       color: Colors.blue,
//                     ),
//                   ),
//                   ...dayOccurrences.map((occurrence) {
//                     final room = occurrence.room ?? widget.lecture['defaultRoom'] ?? '';
//                     return Padding(
//                       padding: const EdgeInsets.only(left: 8, top: 2),
//                       child: Text(
//                         '• ${_formatTimeOfDay(occurrence.startTime)} - ${_formatTimeOfDay(occurrence.endTime)}'
//                             '${room.isNotEmpty ? ' (Room: $room)' : ''}',
//                         style: const TextStyle(
//                           color: Colors.grey,
//                           fontSize: 12,
//                         ),
//                       ),
//                     );
//                   }).toList(),
//                   const SizedBox(height: 4),
//                 ],
//               );
//             }).toList(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _formatTimeOfDay(TimeOfDay time) {
//     final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
//     final minute = time.minute.toString().padLeft(2, '0');
//     final period = time.period == DayPeriod.am ? 'AM' : 'PM';
//     return '$hour:$minute $period';
//   }
//
//   @override
//   void dispose() {
//     _reasonController.dispose();
//     super.dispose();
//   }
// }
//
// // Helper extension for copying occurrences
// extension LectureOccurrenceCopyWith on LectureOccurrence {
//   LectureOccurrence copyWith({
//     int? dayOfWeek,
//     TimeOfDay? startTime,
//     TimeOfDay? endTime,
//     String? room,
//     String? topic,
//   }) {
//     return LectureOccurrence(
//       dayOfWeek: dayOfWeek ?? this.dayOfWeek,
//       startTime: startTime ?? this.startTime,
//       endTime: endTime ?? this.endTime,
//       room: room ?? this.room,
//       topic: topic ?? this.topic,
//     );
//   }
// }