// lib/services/fcm_background_handler.dart - COMPLETE FIXED VERSION
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  tz_data.initializeTimeZones();

  // Initialize with icon
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
        channelShowBadge: true,
        onlyAlertOnce: false,
        defaultRingtoneType: DefaultRingtoneType.Alarm,
        enableLights: true,
      ),
    ],
    debug: false,
  );

  final notification = message.notification;
  final data = message.data;

  if (notification != null) {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch % 1000000,
        channelKey: 'high_priority',
        title: notification.title ?? 'Lecture Reminder',
        body: notification.body ?? '',
        payload: data.map((key, value) => MapEntry(key, value.toString())),
        criticalAlert: true,
        wakeUpScreen: true,
        fullScreenIntent: true,
        notificationLayout: NotificationLayout.Default,
        // ✅ Optional: Add specific icon
        largeIcon: 'resource://drawable/ic_notification',
      ),
    );
  }
}