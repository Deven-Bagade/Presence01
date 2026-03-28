// lib/pages/notification_debug_screen.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/workmanager_service.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  final NotificationService _notificationService = NotificationService();
  List<String> _logs = [];
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLogs = prefs.getStringList('notification_logs') ?? [];
    setState(() => _logs = savedLogs);
  }

  Future<void> _saveLog(String message) async {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final log = '[$timestamp] $message';

    setState(() => _logs.insert(0, log));

    // Keep only last 50 logs
    if (_logs.length > 50) {
      _logs = _logs.sublist(0, 50);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notification_logs', _logs);
  }

// In _runFullTest() method, remove setDefaultIcon() calls:
  Future<void> _runFullTest() async {
    setState(() => _isTesting = true);

    try {
      await _saveLog('Starting full notification test...');

      // 1. CREATE CHANNELS DIRECTLY
      await _saveLog('Step 1: Creating notification channels DIRECTLY...');
      try {
        await AwesomeNotifications().initialize(
          'resource://drawable/ic_launcher', // ✅ Icon source
          [
            NotificationChannel(
              channelKey: 'high_priority',
              channelName: 'Lecture Reminders',
              channelDescription: 'Reminders for upcoming lectures',
              importance: NotificationImportance.Max,
              defaultColor: Colors.blue,
              ledColor: Colors.blue,
              enableVibration: true,
              playSound: true,
              criticalAlerts: true,
              locked: true,
              defaultRingtoneType: DefaultRingtoneType.Alarm,
            ),
          ],
          debug: true,
        );
        await _saveLog('✅ Channels created successfully');
      } catch (e) {
        await _saveLog('❌ Channel creation failed: $e');
        throw Exception('Cannot create notification channels');
      }

      // 2. Wait for Android to register
      await Future.delayed(Duration(milliseconds: 1500));

      // 3. Check permissions
      await _saveLog('Step 2: Checking permissions...');
      final granted = await AwesomeNotifications().requestPermissionToSendNotifications();
      await _saveLog(granted ? '✓ Permissions granted' : '✗ Permissions denied');

      // 4. Test immediate notification
      await _saveLog('Step 3: Testing immediate notification...');
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1001,
            channelKey: 'high_priority',
            title: '🔔 Test Notification',
            body: 'This confirms notifications are working',
            payload: {'type': 'test'},
            criticalAlert: true,
            notificationLayout: NotificationLayout.Default,
            // ✅ Optional: Set specific icon
            largeIcon: 'resource://drawable/ic_notification',
          ),
        );
        await _saveLog('✓ Test notification sent successfully');
      } catch (e) {
        await _saveLog('❌ Test notification failed: $e');

        // Try without largeIcon
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 1002,
              channelKey: 'high_priority',
              title: 'Test without largeIcon',
              body: 'Using default app icon',
              notificationLayout: NotificationLayout.Default,
              // ✅ Don't specify largeIcon, use default
            ),
          );
          await _saveLog('✓ Test without largeIcon succeeded');
        } catch (e2) {
          await _saveLog('❌ All attempts failed: $e2');
          rethrow;
        }
      }

      // 5. Test scheduled notification
      await _saveLog('Step 4: Testing scheduled notification...');
      try {
        final futureTime = DateTime.now().add(const Duration(minutes: 2));
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 88888,
            channelKey: 'high_priority', // ✅ FIXED: Was 'high_priority_reminders'
            title: 'Scheduled Test',
            body: 'This notification was scheduled 2 minutes ahead',
            payload: {'type': 'test_scheduled'},
            notificationLayout: NotificationLayout.Default, // ✅ ADD THIS
          ),
          schedule: NotificationCalendar.fromDate(date: futureTime),
        );
        await _saveLog('✓ Scheduled notification set for ${futureTime.hour}:${futureTime.minute}');
      } catch (e) {
        await _saveLog('❌ Scheduled notification failed: $e');
      }

      // 6. Check WorkManager
      await _saveLog('Step 5: Checking WorkManager...');
      try {
        await WorkManagerService.testWorkManager();
        await _saveLog('✓ WorkManager tasks scheduled');
      } catch (e) {
        await _saveLog('❌ WorkManager test failed: $e');
      }

      // 7. Check existing notifications
      await _saveLog('Step 6: Checking existing notifications...');
      try {
        final scheduled = await AwesomeNotifications().listScheduledNotifications();
        await _saveLog('✓ Found ${scheduled.length} scheduled notifications');
      } catch (e) {
        await _saveLog('❌ Failed to list scheduled notifications: $e');
      }

      await _saveLog('✅ All tests completed successfully!');

    } catch (e) {
      await _saveLog('❌ Test failed: $e');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _clearAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    await _saveLog('Cleared all notifications');
  }

  Future<void> _rescheduleAll() async {
    await _notificationService.rescheduleAllNotifications();
    await _saveLog('Rescheduled all notifications');
  }

// Update emergencyIconFix method:
  Future<void> _emergencyIconFix() async {
    await _saveLog('🆘 EMERGENCY ICON FIX...');

    try {
      // Cancel everything
      await AwesomeNotifications().cancelAll();
      await _saveLog('Cleared existing notifications');

      // Test with different icon sources
      try {
        // Try with specific icon
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 9999,
            channelKey: 'high_priority',
            title: 'Test with ic_notification',
            body: 'Testing specific icon',
            notificationLayout: NotificationLayout.Default,
            largeIcon: 'resource://drawable/ic_notification', // Specific icon
          ),
        );
        await _saveLog('✅ Test with ic_notification sent');

        // Also test without largeIcon (uses default)
        await Future.delayed(Duration(milliseconds: 500));
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 9998,
            channelKey: 'high_priority',
            title: 'Test without icon',
            body: 'Using default icon',
            notificationLayout: NotificationLayout.Default,
            // No largeIcon specified - uses default from initialize()
          ),
        );
        await _saveLog('✅ Test with default icon sent');

      } catch (e) {
        await _saveLog('❌ Icon tests failed: $e');

        // Last resort: try with launcher icon
        try {
          // Reinitialize with launcher icon
          await AwesomeNotifications().initialize(
            'resource://mipmap/ic_launcher', // Android launcher icon
            [
              NotificationChannel(
                channelKey: 'high_priority',
                channelName: 'Test Channel',
                channelDescription: 'Emergency test',
                importance: NotificationImportance.Max,
                defaultColor: Colors.red,
              ),
            ],
            debug: true,
          );

          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 9997,
              channelKey: 'high_priority',
              title: 'LAST RESORT TEST',
              body: 'Using mipmap launcher icon',
              notificationLayout: NotificationLayout.Default,
            ),
          );
          await _saveLog('✅ Last resort test sent');
        } catch (e2) {
          await _saveLog('❌ Last resort also failed: $e2');
        }
      }
    } catch (e) {
      await _saveLog('❌ Emergency fix failed: $e');
    }
  }

  // SIMPLE TEST WITHOUT SERVICE
  Future<void> _simpleDirectTest() async {
    await _saveLog('🧪 SIMPLE DIRECT TEST...');

    try {
      // Direct test without any service wrappers
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          channelKey: 'high_priority',
          title: 'Simple Test',
          body: 'Direct notification test',
          notificationLayout: NotificationLayout.Default, // ✅ CRITICAL
        ),
      );
      await _saveLog('✅ Simple direct test successful');
    } catch (e) {
      await _saveLog('❌ Simple test failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh Logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() => _logs.clear());
              SharedPreferences.getInstance().then((prefs) {
                prefs.remove('notification_logs');
              });
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Full Test'),
                  onPressed: _isTesting ? null : _runFullTest,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Simple Test'),
                  onPressed: _isTesting ? null : _simpleDirectTest,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: const Text('Reschedule'),
                  onPressed: _isTesting ? null : _rescheduleAll,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All'),
                  onPressed: _isTesting ? null : _clearAllNotifications,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.emergency),
                  label: const Text('Fix Icon'),
                  onPressed: _isTesting ? null : _emergencyIconFix,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isError = log.contains('✗') || log.contains('❌');
                final isSuccess = log.contains('✓') || log.contains('✅');

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: isError ? Colors.red : (isSuccess ? Colors.green : Colors.grey.shade700),
                      fontFamily: 'Monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}