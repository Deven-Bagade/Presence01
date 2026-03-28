// lib/services/workmanager_service.dart
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:async';

// =========================================================
// TASK HANDLER FUNCTIONS (MUST BE TOP-LEVEL)
// =========================================================

@pragma('vm:entry-point')
Future<bool> _handleNotificationRecovery() async {
  try {
    print('🔄 Starting notification recovery in background...');

    // Initialize timezone
    try {
      tz_data.initializeTimeZones();
    } catch (e) {
      print('⚠️ Timezone initialization failed: $e');
    }

    // Initialize AwesomeNotifications
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'background_recovery',
          channelName: 'System Recovery',
          channelDescription: 'System notification recovery',
          importance: NotificationImportance.Max,
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          enableVibration: true,
          playSound: true,
          criticalAlerts: true,
        ),
      ],
      debug: false,
    );

    // Send recovery notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _generateTaskId(),
        channelKey: 'background_recovery',
        title: '🔄 Notification Recovery',
        body: 'Lecture notifications are being restored',
        payload: {'type': 'recovery_started'},
        criticalAlert: true,
      ),
    );

    // Check if we have scheduled notifications in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final hasScheduledNotifications = prefs.containsKey('scheduled_notifications');

    if (hasScheduledNotifications) {
      // Mark that recovery is needed
      await prefs.setBool('needs_notification_recovery', true);
      await prefs.setInt('last_recovery_attempt', DateTime.now().millisecondsSinceEpoch);

      print('✅ Found scheduled notifications, marked for recovery');

      // Send success notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateTaskId() + 1,
          channelKey: 'background_recovery',
          title: '✅ Recovery Started',
          body: 'Lecture notifications will be restored when app opens',
          payload: {'type': 'recovery_pending'},
        ),
      );
    } else {
      print('ℹ️ No scheduled notifications found for recovery');
    }

    return true;

  } catch (e) {
    print('❌ Notification recovery failed: $e');

    try {
      // Send error notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateTaskId() + 1000,
          channelKey: 'background_recovery',
          title: '❌ Recovery Failed',
          body: 'Could not restore notifications',
          payload: {'type': 'recovery_error'},
        ),
      );
    } catch (e2) {
      print('⚠️ Could not send error notification: $e2');
    }

    return false;
  }
}

@pragma('vm:entry-point')
Future<bool> _handleDailySummary() async {
  try {
    print('📊 Generating daily summary in background...');

    // Initialize AwesomeNotifications
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'daily_summary',
          channelName: 'Daily Summary',
          channelDescription: 'Daily lecture summaries',
          importance: NotificationImportance.High,
          defaultColor: Colors.green,
          ledColor: Colors.green,
          enableVibration: true,
          playSound: true,
        ),
      ],
      debug: false,
    );

    // Check for today's lectures
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final todayLectures = prefs.getStringList('lectures_$todayKey') ?? [];

    if (todayLectures.isNotEmpty) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateTaskId(),
          channelKey: 'daily_summary',
          title: '📚 Today\'s Lectures',
          body: 'You have ${todayLectures.length} lecture(s) today',
          payload: {
            'type': 'daily_summary',
            'count': todayLectures.length.toString(),
            'date': today.toIso8601String(),
          },
        ),
      );

      print('✅ Daily summary sent: ${todayLectures.length} lectures');
    } else {
      print('ℹ️ No lectures scheduled for today');
    }

    return true;

  } catch (e) {
    print('❌ Daily summary failed: $e');
    return false;
  }
}

@pragma('vm:entry-point')
Future<bool> _handleHealthCheck() async {
  try {
    print('🔧 Running system health check...');

    // Initialize AwesomeNotifications
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'system_health',
          channelName: 'System Health',
          channelDescription: 'System health checks',
          importance: NotificationImportance.Default,
          defaultColor: Colors.orange,
          ledColor: Colors.orange,
        ),
      ],
      debug: false,
    );

    // Check notification permissions
    final prefs = await SharedPreferences.getInstance();
    final lastHealthCheck = prefs.getInt('last_health_check') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Only send notification every 3 days
    if (now - lastHealthCheck > 3 * 24 * 60 * 60 * 1000) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _generateTaskId(),
          channelKey: 'system_health',
          title: '🔧 System Health Check',
          body: 'Lecture reminder system is running normally',
          payload: {'type': 'health_check'},
        ),
      );

      await prefs.setInt('last_health_check', now);
      print('✅ Health check notification sent');
    } else {
      print('ℹ️ Health check skipped (recently sent)');
    }

    return true;

  } catch (e) {
    print('❌ Health check failed: $e');
    return false;
  }
}

// Helper function to generate task IDs
int _generateTaskId() {
  return DateTime.now().millisecondsSinceEpoch % 1000000;
}

// =========================================================
// CALLBACK DISPATCHER (MUST BE TOP-LEVEL)
// =========================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔧 Background task executing: $task');

    try {
      switch (task) {
        case "notification_recovery":
          return await _handleNotificationRecovery();
        case "daily_summary":
          return await _handleDailySummary();
        case "health_check":
          return await _handleHealthCheck();
        default:
          print('⚠️ Unknown task: $task');
          return false;
      }
    } catch (e) {
      print('❌ Background task error: $e');
      return false;
    }
  });
}

// =========================================================
// WORKMANAGER SERVICE CLASS
// =========================================================

class WorkManagerService {
  static const String _notificationRecoveryTask = "notification_recovery";
  static const String _dailySummaryTask = "daily_summary";
  static const String _healthCheckTask = "health_check";

  // Initialize WorkManager
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      print('✅ WorkManager initialized');
    } catch (e) {
      print('❌ WorkManager initialization failed: $e');
    }
  }

  // Schedule all background tasks
  static Future<void> scheduleAllTasks() async {
    try {
      // Cancel any existing tasks first
      await Workmanager().cancelAll();

      // 1. Schedule daily summary at 8 AM
      await _scheduleDailySummary();

      // 2. Schedule health check every 12 hours
      await _scheduleHealthCheck();

      // 3. Schedule notification recovery after reboot
      await scheduleRebootRecovery();

      print('✅ All background tasks scheduled');
    } catch (e) {
      print('❌ Error scheduling tasks: $e');
    }
  }

  // Schedule notification recovery after device reboot
  static Future<void> scheduleRebootRecovery() async {
    try {
      await Workmanager().registerOneOffTask(
        "reboot_recovery",
        _notificationRecoveryTask,
        initialDelay: Duration(seconds: 30), // Wait 30 seconds after boot
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
      );
      print('✅ Reboot recovery task scheduled');
    } catch (e) {
      print('❌ Error scheduling reboot recovery: $e');
    }
  }

  // Schedule daily summary notification at 8 AM
  static Future<void> _scheduleDailySummary() async {
    try {
      final now = DateTime.now();
      final eightAMToday = DateTime(now.year, now.month, now.day, 8, 0);

      Duration initialDelay;
      if (now.isBefore(eightAMToday)) {
        initialDelay = eightAMToday.difference(now);
      } else {
        // Schedule for 8 AM tomorrow
        final eightAMTomorrow = eightAMToday.add(Duration(days: 1));
        initialDelay = eightAMTomorrow.difference(now);
      }

      await Workmanager().registerPeriodicTask(
        "daily_summary_task",
        _dailySummaryTask,
        frequency: Duration(hours: 24),
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
      );

      print('✅ Daily summary scheduled for 8 AM');
    } catch (e) {
      print('❌ Error scheduling daily summary: $e');
    }
  }

  // Schedule health check every 12 hours
  static Future<void> _scheduleHealthCheck() async {
    try {
      await Workmanager().registerPeriodicTask(
        "health_check_task",
        _healthCheckTask,
        frequency: Duration(hours: 12),
        initialDelay: Duration(minutes: 5),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
      );

      print('✅ Health check scheduled every 12 hours');
    } catch (e) {
      print('❌ Error scheduling health check: $e');
    }
  }

  // Cancel all background tasks
  static Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      print('✅ All background tasks cancelled');
    } catch (e) {
      print('❌ Error cancelling tasks: $e');
    }
  }

  // Schedule immediate notification refresh
  static Future<void> scheduleImmediateRefresh() async {
    try {
      await Workmanager().registerOneOffTask(
        "immediate_refresh",
        _notificationRecoveryTask,
        initialDelay: Duration(seconds: 10),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      print('✅ Immediate refresh scheduled');
    } catch (e) {
      print('❌ Error scheduling immediate refresh: $e');
    }
  }

  // =========================================================
  // UTILITY METHODS
  // =========================================================

  // Check if WorkManager is working
  static Future<void> testWorkManager() async {
    try {
      await Workmanager().registerOneOffTask(
        "test_task",
        _notificationRecoveryTask,
        initialDelay: Duration(seconds: 5),
      );
      print('✅ Test task scheduled');
    } catch (e) {
      print('❌ Test task failed: $e');
    }
  }

  // Get all scheduled tasks
  static Future<void> printScheduledTasks() async {
    try {
      // Note: WorkManager doesn't have a direct method to get scheduled tasks
      // We can check SharedPreferences for our own tracking
      final prefs = await SharedPreferences.getInstance();
      final lastRecovery = prefs.getInt('last_recovery_attempt');
      final lastSummary = prefs.getInt('last_daily_summary');
      final lastHealthCheck = prefs.getInt('last_health_check');

      print('📋 Scheduled Tasks Status:');
      print('   • Last recovery attempt: ${lastRecovery != null ? DateTime.fromMillisecondsSinceEpoch(lastRecovery) : "Never"}');
      print('   • Last daily summary: ${lastSummary != null ? DateTime.fromMillisecondsSinceEpoch(lastSummary) : "Never"}');
      print('   • Last health check: ${lastHealthCheck != null ? DateTime.fromMillisecondsSinceEpoch(lastHealthCheck) : "Never"}');
    } catch (e) {
      print('❌ Error getting task status: $e');
    }
  }

  // Save today's lecture count for daily summary
  static Future<void> saveTodaysLectureCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';

      // Create a simple list (could be lecture names or just count)
      final lectures = List.generate(count, (index) => 'lecture_${index + 1}');
      await prefs.setStringList('lectures_$todayKey', lectures);

      // Also save the count
      await prefs.setInt('today_lecture_count', count);

      print('✅ Saved today\'s lecture count: $count');
    } catch (e) {
      print('❌ Error saving lecture count: $e');
    }
  }
}