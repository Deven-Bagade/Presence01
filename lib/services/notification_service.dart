// lib/services/notification_service.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'lecture_service.dart';

class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Channel constants
  static const String _channelId = 'lecture_reminders';
  static const String _highPriorityChannelId = 'high_priority'; // ✅ Changed!
  // Storage keys
  static const String _prefEnabled = 'notifications_enabled';
  static const String _prefReminderMinutes = 'reminder_minutes';
  static const String _prefScheduledNotifications = 'scheduled_notifications';

  // Default values
  static const int _defaultReminderMinutes = 15;

  bool _initialized = false;
  final Map<String, List<int>> _scheduledNotificationIds = {};

  Future<void> initialize() async {
    if (_initialized) return;


    try {
      // 1. Initialize timezone PROPERLY
      tz_data.initializeTimeZones();
      final local = tz.local;
      print('📱 Timezone initialized: $local'); // ✅ Add logging

      // 2. Request permissions
      await _requestPermissions();

      // 3. Initialize Awesome Notifications
      await _initializeAwesomeNotifications();

      // 4. Setup Firebase Messaging for background/terminated
      await _setupFirebaseMessaging();

      // 5. Restore scheduled notifications after reboot
      await _restoreScheduledNotifications();

      _initialized = true;
      print('✅ Notification service initialized');

    } catch (e) {
      print('❌ Notification initialization error: $e');
      // Fallback to local-only notifications
      await _initializeFallback();
    }
  }

  // =========================================================
  // 1. PERMISSIONS & INITIALIZATION
  // =========================================================
  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      // iOS permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
    }

    // AwesomeNotifications permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  Future<void> _initializeAwesomeNotifications() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        // This must be EXACTLY the same as fcm_background_handler.dart
        NotificationChannel(
          channelKey: 'high_priority', // ⬅️ MUST MATCH
          channelName: 'Lecture Reminders',
          channelDescription: 'Reminders for upcoming lectures',
          importance: NotificationImportance.Max,
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          enableVibration: true,
          playSound: true,
          soundSource: 'resource://raw/notification',
          criticalAlerts: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
          enableLights: true,
        ),
        NotificationChannel(
          channelKey: 'lecture_reminders',
          channelName: 'App Notifications',
          channelDescription: 'General app notifications',
          importance: NotificationImportance.High,
          defaultColor: Colors.green,
          ledColor: Colors.green,
          enableVibration: true,
          playSound: true,
        ),
      ],
      debug: false,
    );

    // Set listeners
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
      onNotificationCreatedMethod: _onNotificationCreatedMethod,
      onNotificationDisplayedMethod: _onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: _onDismissActionReceivedMethod,
    );
  }

  Future<void> _setupFirebaseMessaging() async {
    try {
      // Get FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('📱 FCM Token: $fcmToken');

      // Save token locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken ?? '');

      // 🔥 CRITICAL: Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Foreground message: ${message.messageId}');
        _showNotificationFromFCM(message);
      });

      // Handle when app is opened from terminated state
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          print('📱 App opened from terminated state with message');
          _handleNotificationPayload(message.data);
        }
      });

      // Handle when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('📱 App opened from background with message');
        _handleNotificationPayload(message.data);
      });

    } catch (e) {
      print('⚠️ Firebase Messaging setup error: $e');
    }
  }

  // 🔥 CRITICAL: Background message handler for terminated app
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('📨 Background FCM message: ${message.messageId}');

    // Initialize timezone in background
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      print('⚠️ Timezone init failed in background: $e');
    }

    // Initialize AwesomeNotifications in background
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: _highPriorityChannelId,
          channelName: 'Lecture Reminders',
          channelDescription: 'Reminders for upcoming lectures',
          importance: NotificationImportance.Max,
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          enableVibration: true,
          playSound: true,
          criticalAlerts: true,
          locked: true,
        ),
      ],
      debug: false,
    );

    // Show the notification
    _showNotificationFromFCM(message);
  }



  static void _showNotificationFromFCM(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _generateNotificationId(message.messageId ?? DateTime.now().toString()),
        channelKey: _highPriorityChannelId,
        title: notification.title ?? 'Lecture Reminder',
        body: notification.body ?? '',
        payload: message.data.map((key, value) => MapEntry(key, value.toString())),
        criticalAlert: true,
        wakeUpScreen: true,
        fullScreenIntent: true,
      ),
    );
  }

  static int _generateNotificationId(String seed) {
    return seed.hashCode.abs() % 1000000;
  }

  Future<void> _initializeFallback() async {
    // Fallback if main initialization fails
    try {
      tz_data.initializeTimeZones();
      await _initializeAwesomeNotifications();
      _initialized = true;
      print('✅ Notification service (fallback mode) initialized');
    } catch (e) {
      print('❌ Fallback initialization failed: $e');
    }
  }

  // =========================================================
  // 2. NOTIFICATION SCHEDULING (MAIN FUNCTION)
  // =========================================================
  Future<void> scheduleLectureNotifications({
    required String lectureId,
    required String subject,
    required List<LectureOccurrence> occurrences,
    required DateTime validFrom,
    required DateTime validUntil,
  }) async {
    if (!_initialized) await initialize();

    final enabled = await notificationsEnabled;
    if (!enabled) return;

    final minutesBefore = await reminderMinutes;
    final now = DateTime.now();

    // Cancel existing notifications for this lecture
    await cancelLectureNotifications(lectureId);

    int scheduledCount = 0;

    for (final occurrence in occurrences) {
      // Get all dates for this occurrence
      final dates = _getOccurrenceDates(
        occurrence: occurrence,
        startDate: validFrom.isAfter(now) ? validFrom : now,
        endDate: validUntil,
      );

      for (final date in dates) {
        // Skip past dates
        if (date.isBefore(now)) continue;

        // Schedule notification
        final notificationTime = DateTime(
          date.year,
          date.month,
          date.day,
          occurrence.startTime.hour,
          occurrence.startTime.minute,
        ).subtract(Duration(minutes: minutesBefore));

        // Skip if notification time is in past
        if (notificationTime.isBefore(now)) continue;

        await _scheduleSingleNotification(
          notificationId: _generateUniqueId(lectureId, date, occurrence),
          lectureId: lectureId,
          subject: subject,
          notificationTime: notificationTime,
          occurrence: occurrence,
          date: date,
        );

        scheduledCount++;
      }
    }

    // Save to persistent storage
    await _saveScheduledNotifications();

    print('📅 Scheduled $scheduledCount notification(s) for "$subject"');
  }

  Future<void> ensureChannelsCreated() async {
    // Try to create a test notification to check if channels exist
    try {
      // Create a temporary notification to test if channel exists
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999999, // Temporary ID
          channelKey: _highPriorityChannelId, // Try to use the channel
          title: 'Channel Test',
          body: 'Testing channel existence',
        ),
      );

      // If we get here, channel exists - cancel the test notification
      await AwesomeNotifications().cancel(999999);
      print('✅ Channel exists: $_highPriorityChannelId');

    } catch (e) {
      // Channel doesn't exist, re-initialize
      print('⚠️ Channel missing: $e. Recreating channels...');
      await _initializeAwesomeNotifications();
    }
  }

  Future<void> _scheduleSingleNotification({
    required int notificationId,
    required String lectureId,
    required String subject,
    required DateTime notificationTime,
    required LectureOccurrence occurrence,
    required DateTime date,
  }) async {
    try {
      print('   🛠️ Creating notification #$notificationId');
      print('   🕐 Target time: ${notificationTime.toLocal()}');

      // Schedule with AwesomeNotifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: _highPriorityChannelId,
          title: '📚 $subject',
          body: '${occurrence.formattedStartTime} • ${occurrence.room ?? "No room"}',
          payload: {
            'type': 'lecture',
            'lectureId': lectureId,
            'date': date.toIso8601String(),
            'subject': subject,
            'time': occurrence.formattedStartTime,
          },
          criticalAlert: true,
          wakeUpScreen: true,
          fullScreenIntent: true,
          category: NotificationCategory.Reminder,
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(
          date: notificationTime,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      // Track this notification
      _scheduledNotificationIds.putIfAbsent(lectureId, () => []).add(notificationId);

      // Verify it was scheduled
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      final found = scheduled.any((n) => n.content?.id == notificationId);

      if (found) {
        print('   ✅ Successfully scheduled in system');
      } else {
        print('   ⚠️ Scheduled but not found in list');
      }

    } catch (e) {
      print('   ❌ Error scheduling notification #$notificationId: $e');

      // Try alternative method
      try {
        print('   🔄 Trying alternative scheduling method...');

        // Get timezone identifier
        final timeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: _highPriorityChannelId,
            title: '📚 $subject',
            body: '${occurrence.formattedStartTime} • ${occurrence.room ?? "No room"}',
            notificationLayout: NotificationLayout.Default,
          ),
          schedule: NotificationCalendar(
            year: notificationTime.year,
            month: notificationTime.month,
            day: notificationTime.day,
            hour: notificationTime.hour,
            minute: notificationTime.minute,
            second: 0,
            timeZone: timeZone,
            allowWhileIdle: true,
            preciseAlarm: true,
          ),
        );

        print('   ✅ Alternative method succeeded');

      } catch (e2) {
        print('   ❌ Alternative method also failed: $e2');
      }
    }
  }

  int _generateUniqueId(String lectureId, DateTime date, LectureOccurrence occurrence) {
    final uniqueString = '$lectureId-${date.year}-${date.month}-${date.day}-'
        '${occurrence.dayOfWeek}-${occurrence.startTime.hour}-${occurrence.startTime.minute}';
    return uniqueString.hashCode.abs() % 1000000;
  }

  List<DateTime> _getOccurrenceDates({
    required LectureOccurrence occurrence,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final dates = <DateTime>[];

    // Ensure dates are in local time
    final localStart = startDate.toLocal();
    final localEnd = endDate.toLocal();

    print('     📅 Date range: ${localStart.toLocal()} to ${localEnd.toLocal()}');
    print('     📅 Day of week: ${occurrence.dayOfWeek} (start day: ${localStart.weekday})');

    // Find first occurrence of this weekday
    int daysToAdd = (occurrence.dayOfWeek - localStart.weekday) % 7;
    if (daysToAdd < 0) daysToAdd += 7;

    // Special case: if today is the target day and time hasn't passed yet
    if (daysToAdd == 0 && localStart.weekday == occurrence.dayOfWeek) {
      // Check if the occurrence time is still in the future today
      final todayOccurrenceTime = DateTime(
        localStart.year,
        localStart.month,
        localStart.day,
        occurrence.startTime.hour,
        occurrence.startTime.minute,
      );

      if (todayOccurrenceTime.isAfter(localStart)) {
        daysToAdd = 0;
      } else {
        daysToAdd = 7; // Move to next week
      }
    }

    DateTime current = localStart.add(Duration(days: daysToAdd));

    print('     📅 First occurrence: ${current.toLocal()}');

    // Collect all occurrences
    while (!current.isAfter(localEnd)) {
      dates.add(current);
      print('     📅 Adding date: ${current.toLocal()}');
      current = current.add(const Duration(days: 7));
    }

    print('     📅 Total dates found: ${dates.length}');
    return dates;
  }

  // =========================================================
  // 3. PERSISTENCE & RECOVERY
  // =========================================================
  Future<void> _saveScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationData = _scheduledNotificationIds.entries.map((entry) {
        return '${entry.key}:${entry.value.join(',')}';
      }).join(';');
      await prefs.setString(_prefScheduledNotifications, notificationData);
    } catch (e) {
      print('⚠️ Error saving notifications: $e');
    }
  }

  Future<void> _restoreScheduledNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationData = prefs.getString(_prefScheduledNotifications);

      if (notificationData != null && notificationData.isNotEmpty) {
        final entries = notificationData.split(';');
        for (final entry in entries) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            final lectureId = parts[0];
            final ids = parts[1].split(',').map(int.parse).toList();
            _scheduledNotificationIds[lectureId] = ids;
          }
        }
        print('📋 Restored ${_scheduledNotificationIds.length} lectures with notifications');
      }
    } catch (e) {
      print('⚠️ Error restoring notifications: $e');
    }
  }

  Future<void> rescheduleAllNotifications() async {
    if (!_initialized) await initialize();

    // Clear all existing notifications
    await AwesomeNotifications().cancelAll();
    _scheduledNotificationIds.clear();

    // Get all lectures and reschedule
    final lectureService = LectureService();
    final lectures = await lectureService.fetchAllLecturesOnce();

    for (final lecture in lectures) {
      if (lecture['isRecurring  Weekly'] == true) {
        final occurrences = _extractOccurrencesFromLecture(lecture);
        if (occurrences.isNotEmpty) {
          await scheduleLectureNotifications(
            lectureId: lecture['id'],
            subject: lecture['subject'],
            occurrences: occurrences,
            validFrom: lecture['validFrom'] ?? DateTime.now(),
            validUntil: lecture['validUntil'] ?? DateTime(2100, 12, 31),
          );
        }
      }
    }

    print('🔔 Rescheduled all notifications');
  }

  // =========================================================
  // 4. PUBLIC METHODS
  // =========================================================
  Future<void> cancelLectureNotifications(String lectureId) async {
    final notificationIds = _scheduledNotificationIds[lectureId];

    if (notificationIds != null && notificationIds.isNotEmpty) {
      for (final id in notificationIds) {
        await AwesomeNotifications().cancel(id);
      }
      _scheduledNotificationIds.remove(lectureId);
      await _saveScheduledNotifications();
      print('🔕 Cancelled notifications for lecture $lectureId');
    }
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    _scheduledNotificationIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefScheduledNotifications);
    print('🔕 Cancelled all notifications');
  }

  Future<void> sendTestNotification() async {
    if (!_initialized) await initialize();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 1000000,
        channelKey: _highPriorityChannelId,
        title: '🔔 Test Notification',
        body: 'This confirms notifications are working',
        payload: {'type': 'test'},
        criticalAlert: true,
      ),
    );
  }

  Future<bool> requestNotificationPermissions() async {
    if (!_initialized) await initialize();
    return await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // =========================================================
  // 5. PREFERENCES
  // =========================================================
  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  Future<bool> get notificationsEnabled async {
    final prefs = await _prefs;
    return prefs.getBool(_prefEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_prefEnabled, enabled);

    if (!enabled) {
      await cancelAllNotifications();
    } else {
      await rescheduleAllNotifications();
    }
  }

  Future<int> get reminderMinutes async {
    final prefs = await _prefs;
    return prefs.getInt(_prefReminderMinutes) ?? _defaultReminderMinutes;
  }

  Future<void> setReminderMinutes(int minutes) async {
    final prefs = await _prefs;
    await prefs.setInt(_prefReminderMinutes, minutes);
    await rescheduleAllNotifications();
  }

  // =========================================================
  // 6. HELPER METHODS
  // =========================================================
  List<LectureOccurrence> _extractOccurrencesFromLecture(Map<String, dynamic> lecture) {
    final List<LectureOccurrence> occurrences = [];

    if (lecture['occurrences'] is List) {
      final occurrencesList = lecture['occurrences'] as List<dynamic>;
      for (final occurrenceMap in occurrencesList) {
        if (occurrenceMap is Map<String, dynamic>) {
          try {
            occurrences.add(LectureOccurrence.fromMap(occurrenceMap));
          } catch (e) {
            print('Error extracting occurrence: $e');
          }
        }
      }
    }

    // Fallback to single occurrence format
    if (occurrences.isEmpty && lecture['dayOfWeek'] != null) {
      final dayOfWeek = lecture['dayOfWeek'] as int;
      final startMap = lecture['startTime'] as Map<String, dynamic>?;
      final endMap = lecture['endTime'] as Map<String, dynamic>?;

      if (startMap != null && endMap != null) {
        occurrences.add(LectureOccurrence(
          dayOfWeek: dayOfWeek,
          startTime: TimeOfDay(hour: startMap['hour'] ?? 9, minute: startMap['minute'] ?? 0),
          endTime: TimeOfDay(hour: endMap['hour'] ?? 10, minute: endMap['minute'] ?? 0),
          room: lecture['room'] as String?,
          topic: lecture['topic'] as String?,
        ));
      }
    }

    return occurrences;
  }

  void _handleNotificationPayload(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;

    if (type == 'lecture') {
      final lectureId = payload['lectureId'] as String?;
      final dateStr = payload['date'] as String?;

      if (lectureId != null && dateStr != null) {
        print('📱 Notification tapped: Lecture $lectureId on $dateStr');
        // Navigate to lecture details
      }
    }
  }
  // Add this method to NotificationService class
  Future<void> handlePostRebootRecovery() async {
    if (!_initialized) await initialize();

    print('🔄 Handling post-reboot notification recovery...');

    final prefs = await SharedPreferences.getInstance();
    final needsRecovery = prefs.getBool('needs_notification_recovery') ?? false;

    if (needsRecovery) {
      print('📋 Restoring notifications after reboot...');

      // Clear the flag
      await prefs.setBool('needs_notification_recovery', false);

      // Restore from SharedPreferences
      await _restoreScheduledNotifications();

      // Reschedule all notifications
      await rescheduleAllNotifications();

      print('✅ Notifications restored after reboot');

      // Send confirmation notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          channelKey: _highPriorityChannelId,
          title: '✅ Notifications Restored',
          body: 'All lecture reminders have been restored',
          payload: {'type': 'recovery_complete'},
        ),
      );
    } else {
      print('ℹ️ No notification recovery needed');
    }
  }

  // =========================================================
  // 7. AWESOME NOTIFICATIONS CALLBACKS
  // =========================================================
  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    print('📝 Notification created: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    print('📱 Notification displayed: ${receivedNotification.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('❌ Notification dismissed: ${receivedAction.id}');
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    print('🎯 Action received: ${receivedAction.id}');
    final payload = receivedAction.payload ?? {};
    final type = payload['type'] as String?;

    if (type == 'lecture') {
      final lectureId = payload['lectureId'] as String?;
      final dateStr = payload['date'] as String?;
      print('📱 Notification action: Navigate to lecture $lectureId on $dateStr');
    }
  }

  // Add to notification_service.dart
  Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': await notificationsEnabled,
      'reminderMinutes': await reminderMinutes,
      'analyticalEnabled': prefs.getBool('analytical_enabled') ?? true,
      'attendanceReminders': prefs.getBool('attendance_reminders') ?? true,
    };
  }

  Future<bool> checkNotificationPermissions() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

}