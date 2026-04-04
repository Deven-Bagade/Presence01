// lib/screens/settings_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/workmanager_service.dart';
import '../themes/app_themes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Services
  final NotificationService _notificationService = NotificationService();
  final WorkManagerService _workManagerService = WorkManagerService();

  // State variables
  bool _notificationsEnabled = true;
  int _reminderMinutes = 15;
  bool _analyticalEnabled = true;
  bool _attendanceReminders = true;
  bool _timetableConflictCheck = true;
  bool _use24HourFormat = false;
  bool _holidayReminders = true;
  bool _highPriorityNotifications = true;
  bool _wakeUpScreen = true;
  bool _autoRestartAfterReboot = true;
  bool _batteryOptimizationDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _notificationService.initialize();
    await WorkManagerService.initialize();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          _reminderMinutes = prefs.getInt('reminder_minutes') ?? 15;
          _analyticalEnabled = prefs.getBool('analytical_enabled') ?? true;
          _attendanceReminders = prefs.getBool('attendance_reminders') ?? true;
          _autoRestartAfterReboot = prefs.getBool('auto_restart_after_reboot') ?? true;
          _batteryOptimizationDisabled = prefs.getBool('battery_optimization_disabled') ?? false;
          _highPriorityNotifications = prefs.getBool('high_priority') ?? true;
          _wakeUpScreen = prefs.getBool('wake_up_screen') ?? true;
          _holidayReminders = prefs.getBool('holiday_reminders') ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  // Reminder time options
  final List<int> _reminderOptions = [5, 10, 15, 30, 60];
  final Map<int, String> _reminderLabels = {
    5: '5 minutes before',
    10: '10 minutes before',
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
  };

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeData = themeProvider.themeData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: themeData.card,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.medical_services, color: themeData.primary),
            onPressed: _runNotificationDiagnostics,
            tooltip: "Notification Diagnostics",
          ),
        ],
      ),
      backgroundColor: themeData.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("Appearance", themeData),
          _themeSelector(themeProvider, themeData),
          const Divider(),

          _sectionHeader("Notifications", themeData),
          SwitchListTile(
            title: Text(
              "Enable Notifications",
              style: TextStyle(color: themeData.textPrimary),
            ),
            subtitle: Text(
              "Get reminders for upcoming lectures",
              style: TextStyle(color: themeData.textSecondary),
            ),
            secondary: Icon(
              Icons.notifications,
              color: _notificationsEnabled
                  ? themeData.primary
                  : themeData.textSecondary,
            ),
            value: _notificationsEnabled,
            onChanged: (value) async {
              await _notificationService.setNotificationsEnabled(value);
              setState(() => _notificationsEnabled = value);
              if (value) {
                await _notificationService.rescheduleAllNotifications();
                await WorkManagerService.scheduleAllTasks();
              } else {
                await WorkManagerService.cancelAllTasks();
              }
            },
            activeColor: themeData.primary,
          ),

          if (_notificationsEnabled) ...[
            _sectionHeader("Reminder Settings", themeData),
            _reminderTimeSelector(themeData),

            SwitchListTile(
              title: Text(
                "High Priority Notifications",
                style: TextStyle(color: themeData.textPrimary),
              ),
              subtitle: Text(
                "Wake screen & bypass Do Not Disturb",
                style: TextStyle(color: themeData.textSecondary),
              ),
              secondary: Icon(
                Icons.priority_high,
                color: _highPriorityNotifications
                    ? Colors.orange
                    : themeData.textSecondary,
              ),
              value: _highPriorityNotifications,
              onChanged: (value) async {
                setState(() => _highPriorityNotifications = value);
                await _savePreference('high_priority', value);
              },
              activeColor: Colors.orange,
            ),

            SwitchListTile(
              title: Text(
                "Wake Screen",
                style: TextStyle(color: themeData.textPrimary),
              ),
              subtitle: Text(
                "Turn on screen for important reminders",
                style: TextStyle(color: themeData.textSecondary),
              ),
              secondary: Icon(
                Icons.screen_lock_portrait,
                color: _wakeUpScreen
                    ? Colors.blue
                    : themeData.textSecondary,
              ),
              value: _wakeUpScreen,
              onChanged: (value) async {
                setState(() => _wakeUpScreen = value);
                await _savePreference('wake_up_screen', value);
              },
              activeColor: Colors.blue,
            ),

            SwitchListTile(
              title: Text(
                "Analytical Reminders",
                style: TextStyle(color: themeData.textPrimary),
              ),
              subtitle: Text(
                "Weekly summaries & attendance insights",
                style: TextStyle(color: themeData.textSecondary),
              ),
              secondary: Icon(
                Icons.analytics,
                color: _analyticalEnabled
                    ? themeData.accent
                    : themeData.textSecondary,
              ),
              value: _analyticalEnabled,
              onChanged: (value) async {
                await _savePreference('analytical_enabled', value);
                setState(() => _analyticalEnabled = value);
              },
              activeColor: themeData.accent,
            ),

            SwitchListTile(
              title: Text(
                "Attendance Reminders",
                style: TextStyle(color: themeData.textPrimary),
              ),
              subtitle: Text(
                "Remind to mark attendance after lectures",
                style: TextStyle(color: themeData.textSecondary),
              ),
              secondary: Icon(
                Icons.check_circle,
                color: _attendanceReminders
                    ? Colors.green
                    : themeData.textSecondary,
              ),
              value: _attendanceReminders,
              onChanged: (value) async {
                await _savePreference('attendance_reminders', value);
                setState(() => _attendanceReminders = value);
              },
              activeColor: Colors.green,
            ),

            SwitchListTile(
              title: Text(
                "Holiday Reminders",
                style: TextStyle(color: themeData.textPrimary),
              ),
              subtitle: Text(
                "Notify about upcoming holidays",
                style: TextStyle(color: themeData.textSecondary),
              ),
              secondary: Icon(
                Icons.beach_access,
                color: _holidayReminders
                    ? Colors.cyan
                    : themeData.textSecondary,
              ),
              value: _holidayReminders,
              onChanged: (value) async {
                await _savePreference('holiday_reminders', value);
                setState(() => _holidayReminders = value);
              },
              activeColor: Colors.cyan,
            ),

            _actionTile(
              icon: Icons.notifications_active,
              title: "Test Notification",
              subtitle: "Send a test notification now",
              themeData: themeData,
              onTap: _sendTestNotification,
            ),

            _actionTile(
              icon: Icons.refresh,
              title: "Reschedule All Notifications",
              subtitle: "Force refresh all lecture reminders",
              themeData: themeData,
              onTap: _rescheduleAllNotifications,
            ),

            _actionTile(
              icon: Icons.clear_all,
              title: "Clear All Notifications",
              subtitle: "Remove all scheduled reminders",
              themeData: themeData,
              onTap: _clearAllNotifications,
            ),

            _actionTile(
              icon: Icons.health_and_safety,
              title: "Recover After Reboot",
              subtitle: "Restore notifications after device restart",
              themeData: themeData,
              onTap: _recoverNotificationsAfterReboot,
            ),

            _actionTile(
              icon: Icons.medical_services,
              title: "Notification Health Check",
              subtitle: "Run comprehensive diagnostics",
              themeData: themeData,
              onTap: _runNotificationDiagnostics,
            ),
          ],

          const Divider(),

          _sectionHeader("Background Services", themeData),
          SwitchListTile(
            title: Text(
              "Auto-restart after Reboot",
              style: TextStyle(color: themeData.textPrimary),
            ),
            subtitle: Text(
              "Automatically restore notifications after device restart",
              style: TextStyle(color: themeData.textSecondary),
            ),
            secondary: Icon(
              Icons.power_settings_new,
              color: _autoRestartAfterReboot
                  ? Colors.green
                  : themeData.textSecondary,
            ),
            value: _autoRestartAfterReboot,
            onChanged: (value) async {
              setState(() => _autoRestartAfterReboot = value);
              await _savePreference('auto_restart_after_reboot', value);
              if (value) {
                await WorkManagerService.scheduleRebootRecovery();
              }
            },
            activeColor: Colors.green,
          ),

          SwitchListTile(
            title: Text(
              "Disable Battery Optimization",
              style: TextStyle(color: themeData.textPrimary),
            ),
            subtitle: Text(
              "Allow notifications when device is idle (Android)",
              style: TextStyle(color: themeData.textSecondary),
            ),
            secondary: Icon(
              Icons.battery_charging_full,
              color: _batteryOptimizationDisabled
                  ? Colors.orange
                  : themeData.textSecondary,
            ),
            value: _batteryOptimizationDisabled,
            onChanged: (value) async {
              setState(() => _batteryOptimizationDisabled = value);
              await _savePreference('battery_optimization_disabled', value);
              if (value && Platform.isAndroid) {
                _showBatteryOptimizationGuide();
              }
            },
            activeColor: Colors.orange,
          ),

          _actionTile(
            icon: Icons.construction,
            title: "Test WorkManager",
            subtitle: "Test background task scheduling",
            themeData: themeData,
            onTap: _testWorkManager,
          ),

          const Divider(),

          _sectionHeader("Timetable", themeData),
          SwitchListTile(
            title: Text(
              "Auto Conflict Check",
              style: TextStyle(color: themeData.textPrimary),
            ),
            secondary: const Icon(Icons.warning_amber_rounded),
            value: _timetableConflictCheck,
            onChanged: (value) => setState(() => _timetableConflictCheck = value),
            activeColor: themeData.primary,
          ),

          SwitchListTile(
            title: Text(
              "Use 24-hour Time Format",
              style: TextStyle(color: themeData.textPrimary),
            ),
            secondary: const Icon(Icons.access_time),
            value: _use24HourFormat,
            onChanged: (value) => setState(() => _use24HourFormat = value),
            activeColor: themeData.primary,
          ),

          const Divider(),

          _sectionHeader("Account", themeData),
          _actionTile(
            icon: Icons.person,
            title: "Profile",
            subtitle: "View or edit your personal info",
            themeData: themeData,
            onTap: () => Navigator.pushNamed(context, "/profile"),
          ),


          const Divider(),

          _sectionHeader("Support", themeData),
          _actionTile(
            icon: Icons.help_outline,
            title: "Help & Support",
            themeData: themeData,
            onTap: () => Navigator.pushNamed(context, "/help"),
          ),
          _actionTile(
            icon: Icons.info_outline,
            title: "About App",
            themeData: themeData,
            onTap: () => Navigator.pushNamed(context, "/about"),
          ),
          _actionTile(
            icon: Icons.bug_report,
            title: "Notification Debug",
            subtitle: "Advanced troubleshooting tools",
            themeData: themeData,
            onTap: () => Navigator.pushNamed(context, "/notification-debug"),
          ),

          const Divider(),

          _logoutButton(themeData),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _reminderTimeSelector(AppThemeData themeData) {
    return Card(
      color: themeData.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: themeData.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Reminder Time",
                    style: TextStyle(
                      color: themeData.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  "$_reminderMinutes min before",
                  style: TextStyle(
                    color: themeData.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "When to remind you before each lecture",
              style: TextStyle(
                color: themeData.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reminderOptions.map((minutes) {
                final isSelected = minutes == _reminderMinutes;
                return ChoiceChip(
                  label: Text(_reminderLabels[minutes] ?? '$minutes min'),
                  selected: isSelected,
                  selectedColor: themeData.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : themeData.textPrimary,
                  ),
                  onSelected: (selected) async {
                    if (selected) {
                      await _notificationService.setReminderMinutes(minutes);
                      setState(() => _reminderMinutes = minutes);
                      await _notificationService.rescheduleAllNotifications();
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.sendTestNotification();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test notification sent successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send test notification: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    try {
      await _notificationService.rescheduleAllNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ All notifications rescheduled successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to reschedule notifications: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ All notifications cleared'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to clear notifications: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _recoverNotificationsAfterReboot() async {
    try {
      await _notificationService.handlePostRebootRecovery();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notifications recovered after reboot'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to recover notifications: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testWorkManager() async {
    try {
      await WorkManagerService.testWorkManager();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ WorkManager test scheduled'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ WorkManager test failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showBatteryOptimizationGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🔋 Battery Optimization Guide"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "For notifications to work when app is closed:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _batteryStep("1. Open Device Settings"),
              _batteryStep("2. Go to 'Apps' or 'Applications'"),
              _batteryStep("3. Find 'Timetable App'"),
              _batteryStep("4. Tap on 'Battery'"),
              _batteryStep("5. Select 'Unrestricted' or 'No restrictions'"),
              const SizedBox(height: 16),
              const Text(
                "This prevents Android from putting the app to sleep.",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _runNotificationDiagnostics();
            },
            child: const Text("Run Diagnostics"),
          ),
        ],
      ),
    );
  }

  Widget _batteryStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  // ---------- Notification Diagnostics ----------
  Future<void> _runNotificationDiagnostics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("🔧 Notification Diagnostics"),
        content: FutureBuilder<String>(
          future: _performDiagnostics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Running comprehensive diagnostics..."),
                ],
              );
            }

            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Diagnostic Results:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      snapshot.data ?? "No diagnostic data",
                      style: const TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Recommendations:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._generateRecommendations(snapshot.data ?? ""),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.rescheduleAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Notifications rescheduled'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Fix & Reschedule"),
          ),
        ],
      ),
    );
  }


  Future<String> _performDiagnostics() async {
    final sb = StringBuffer();

    try {
      sb.writeln('📱 NOTIFICATION DIAGNOSTICS REPORT');
      sb.writeln('=' * 50);
      sb.writeln('Timestamp: ${DateTime.now().toLocal()}');
      sb.writeln('Platform: ${Platform.operatingSystem}');
      sb.writeln('');

      // 1. Notification Service Status
      sb.writeln('1. 🔔 NOTIFICATION SERVICE');
      try {
        final allowed = await AwesomeNotifications().isNotificationAllowed();
        sb.writeln('   • Permissions: ${allowed ? "✓ Granted" : "✗ Denied"}');

        final enabled = await _notificationService.notificationsEnabled;
        sb.writeln('   • Enabled: ${enabled ? "✓ Yes" : "✗ No"}');

        final minutes = await _notificationService.reminderMinutes;
        sb.writeln('   • Reminder Minutes: $minutes');

        final prefs = await SharedPreferences.getInstance();
        sb.writeln('   • Attendance Reminders: ${prefs.getBool('attendance_reminders') ?? true}');
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 2. AwesomeNotifications Status
      sb.writeln('');
      sb.writeln('2. 🎯 AWESOME NOTIFICATIONS');
      try {
        // Get scheduled notifications count
        final scheduled = await AwesomeNotifications().listScheduledNotifications();
        sb.writeln('   • Scheduled: ${scheduled.length}');

        final allowed = await AwesomeNotifications().isNotificationAllowed();
        sb.writeln('   • Allowed: ${allowed ? "✓ Yes" : "✗ No"}');

        // Note: listChannels() doesn't exist in AwesomeNotifications
        // Instead, we can check if our channels are working by trying to create a test notification
        sb.writeln('   • Channels: Checking...');

        // Try to get local timezone as a channel health check
        try {
          final timeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();
          sb.writeln('   • TimeZone: $timeZone');
        } catch (e) {
          sb.writeln('   • TimeZone Error: $e');
        }
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 3. Firebase Messaging Status
      sb.writeln('');
      sb.writeln('3. 📡 FIREBASE MESSAGING');
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('fcm_token');
        sb.writeln('   • FCM Token: ${token != null ? "✓ Found" : "✗ Not found"}');

        // Check if token is valid (not empty)
        if (token != null && token.isNotEmpty) {
          sb.writeln('   • Token Status: ✓ Valid (${token.length} chars)');
        } else if (token == null) {
          sb.writeln('   • Token Status: ✗ Not found');
        } else {
          sb.writeln('   • Token Status: ✗ Empty');
        }
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 4. WorkManager Status
      sb.writeln('');
      sb.writeln('4. 🛠️ WORKMANAGER');
      try {
        sb.writeln('   • Initialized: ✓');
        final prefs = await SharedPreferences.getInstance();
        final lastRecovery = prefs.getInt('last_recovery_attempt');
        sb.writeln('   • Last Recovery: ${lastRecovery != null ? DateTime.fromMillisecondsSinceEpoch(lastRecovery) : "Never"}');

        final needsRecovery = prefs.getBool('needs_notification_recovery') ?? false;
        sb.writeln('   • Needs Recovery: ${needsRecovery ? "⚠️ Yes" : "✓ No"}');
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 5. Scheduled Notifications Details
      sb.writeln('');
      sb.writeln('5. 📅 SCHEDULED NOTIFICATIONS DETAILS');
      try {
        final scheduled = await AwesomeNotifications().listScheduledNotifications();
        if (scheduled.isNotEmpty) {
          sb.writeln('   • Total Count: ${scheduled.length}');

          // Sort by next trigger time (we need to extract from schedule)
          scheduled.sort((a, b) {
            final aNext = _getNextTriggerDate(a.schedule);
            final bNext = _getNextTriggerDate(b.schedule);
            return aNext.compareTo(bNext);
          });

          final now = DateTime.now();
          for (int i = 0; i < scheduled.length && i < 5; i++) {
            final notif = scheduled[i];
            final nextDate = _getNextTriggerDate(notif.schedule);
            final timeLeft = nextDate.difference(now);

            sb.writeln('   • ${notif.content?.title ?? "Unknown"}');
            sb.writeln('     Time: ${nextDate.toLocal()}');
            sb.writeln('     In: ${_formatDuration(timeLeft)}');
            sb.writeln('     ID: ${notif.content?.id}');
          }
          if (scheduled.length > 5) {
            sb.writeln('   ... and ${scheduled.length - 5} more');
          }
        } else {
          sb.writeln('   • No scheduled notifications');
        }
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 6. Storage Status
      sb.writeln('');
      sb.writeln('6. 💾 STORAGE');
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasNotifications = prefs.containsKey('scheduled_notifications');
        sb.writeln('   • Saved Notifications: ${hasNotifications ? "✓ Yes" : "✗ No"}');

        final needsRecovery = prefs.getBool('needs_notification_recovery') ?? false;
        sb.writeln('   • Needs Recovery: ${needsRecovery ? "⚠️ Yes" : "✓ No"}');

        final lastRecovery = prefs.getInt('last_recovery_attempt');
        sb.writeln('   • Last Recovery: ${lastRecovery != null ? DateTime.fromMillisecondsSinceEpoch(lastRecovery) : "Never"}');

        // Check other important preferences
        final keys = ['notifications_enabled', 'reminder_minutes', 'fcm_token'];
        for (final key in keys) {
          final exists = prefs.containsKey(key);
          sb.writeln('   • $key: ${exists ? "✓ Set" : "✗ Missing"}');
        }
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 7. Test Notification
      sb.writeln('');
      sb.writeln('7. 🧪 TEST NOTIFICATION');
      try {
        // Create a unique ID for test notification
        final testId = DateTime.now().millisecondsSinceEpoch % 1000000;
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: testId,
            channelKey: 'high_priority',
            title: '🔔 Test Notification',
            body: 'This is a test notification from diagnostics',
            payload: {'type': 'diagnostic_test'},
          ),
        );
        sb.writeln('   • Sent: ✓ Success (ID: $testId)');
        sb.writeln('   • Channel: lecture_reminders');
        sb.writeln('   • Delivery: Should arrive immediately');
      } catch (e) {
        sb.writeln('   • Error: $e');
      }

      // 8. Summary
      sb.writeln('');
      sb.writeln('📊 SUMMARY & RECOMMENDATIONS');
      sb.writeln('=' * 50);

      final issues = <String>[];

      // Check each component
      try {
        final permission = await AwesomeNotifications().isNotificationAllowed();
        if (!permission) issues.add('Notification permissions not granted');

        final scheduled = await AwesomeNotifications().listScheduledNotifications();
        if (scheduled.isEmpty && _notificationsEnabled) {
          issues.add('No notifications scheduled (but enabled)');
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('fcm_token');
        if (token == null || token.isEmpty) {
          issues.add('FCM token not found or empty');
        }

        final needsRecovery = prefs.getBool('needs_notification_recovery') ?? false;
        if (needsRecovery) issues.add('Notifications need recovery after reboot');

        // Check if notifications are enabled in settings
        if (!_notificationsEnabled) {
          issues.add('Notifications disabled in app settings');
        }
      } catch (e) {
        issues.add('Diagnostic error: $e');
      }

      if (issues.isEmpty) {
        sb.writeln('✅ All systems operational!');
        sb.writeln('Notifications should work in all app states.');
      } else {
        sb.writeln('⚠️ Found ${issues.length} issue(s):');
        for (final issue in issues) {
          sb.writeln('• $issue');
        }
        sb.writeln('');
        sb.writeln('🔧 Recommended actions:');
        sb.writeln('1. Click "Fix & Reschedule" button');
        sb.writeln('2. Ensure battery optimization is disabled');
        sb.writeln('3. Grant all notification permissions');
        sb.writeln('4. Restart the app if issues persist');
      }

    } catch (e) {
      sb.writeln('');
      sb.writeln('❌ DIAGNOSTICS ERROR:');
      sb.writeln('$e');
      sb.writeln('');
      sb.writeln('Stack trace:');
      sb.writeln(StackTrace.current.toString());
    }

    return sb.toString();
  }

// Add these helper methods to the _SettingsScreenState class:

  DateTime _getNextTriggerDate(NotificationSchedule? schedule) {
    if (schedule == null) return DateTime.now();

    // Handle different schedule types
    if (schedule is NotificationCalendar) {
      final calendar = schedule;
      try {
        final now = DateTime.now();
        return DateTime(
          calendar.year ?? now.year,
          calendar.month ?? now.month,
          calendar.day ?? now.day,
          calendar.hour ?? 0,
          calendar.minute ?? 0,
          calendar.second ?? 0,
          calendar.millisecond ?? 0,
        );
      } catch (e) {
        return DateTime.now();
      }
    } else if (schedule is NotificationInterval) {
      final interval = schedule;
      return DateTime.now().add(Duration(minutes: interval.interval as int)
      );
    }

    return DateTime.now();
  }
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  List<Widget> _generateRecommendations(String diagnostics) {
    final recommendations = <Widget>[];

    if (diagnostics.contains("✗ Denied")) {
      recommendations.add(
        _recommendationItem(
          "Grant notification permissions in app settings",
          Icons.notifications,
        ),
      );
    }

    if (diagnostics.contains("No notifications scheduled")) {
      recommendations.add(
        _recommendationItem(
          "Reschedule all notifications using 'Reschedule All'",
          Icons.refresh,
        ),
      );
    }

    if (diagnostics.contains("FCM token not found")) {
      recommendations.add(
        _recommendationItem(
          "Reinitialize Firebase Messaging",
          Icons.cloud,
        ),
      );
    }

    if (diagnostics.contains("Needs Recovery")) {
      recommendations.add(
        _recommendationItem(
          "Run 'Recover After Reboot' to restore notifications",
          Icons.restart_alt,
        ),
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        _recommendationItem(
          "All systems are working correctly!",
          Icons.check_circle,
          color: Colors.green,
        ),
      );
    }

    return recommendations;
  }

  Widget _recommendationItem(String text, IconData icon, {Color color = Colors.orange}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // ---------- UI Helper Widgets ----------

  Widget _sectionHeader(String title, AppThemeData themeData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: themeData.textSecondary,
        ),
      ),
    );
  }

  Widget _themeSelector(ThemeProvider themeProvider, AppThemeData themeData) {
    final currentTheme = themeProvider.currentTheme;

    return Column(
      children: AppTheme.values.map((theme) {
        final themeData = AppThemeData.getTheme(theme);
        final isSelected = currentTheme == theme;

        return ListTile(
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: themeData.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? themeData.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          title: Text(
            themeData.name,
            style: TextStyle(color: themeData.textPrimary),
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: themeData.accent)
              : null,
          onTap: () => themeProvider.setTheme(theme),
        );
      }).toList(),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required AppThemeData themeData,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: themeData.primary),
      title: Text(title, style: TextStyle(color: themeData.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: themeData.textSecondary))
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _logoutButton(AppThemeData themeData) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      icon: const Icon(Icons.logout),
      label: const Text("Logout"),
      onPressed: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout? All local data will be preserved."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Logout"),
              ),
            ],
          ),
        );

        if (shouldLogout == true) {
          await _notificationService.cancelAllNotifications();
          await WorkManagerService.cancelAllTasks();
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
        }
      },
    );
  }
}