// android/app/src/main/kotlin/com/vynox/attendigo/MyFirebaseMessagingService.kt
package com.vynox.attendigo

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "Refreshed FCM token: $token")

        // The token will be automatically handled by Flutter's FirebaseMessaging plugin
        // No need to manually save it here
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        Log.d(TAG, "From: ${remoteMessage.from}")

        // Check if message contains a notification payload
        remoteMessage.notification?.let { notification ->
            Log.d(TAG, "Notification Title: ${notification.title}")
            Log.d(TAG, "Notification Body: ${notification.body}")
        }

        // Check if message contains a data payload
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Data payload: ${remoteMessage.data}")
        }

        // IMPORTANT: Do NOT launch FlutterActivity or create notifications here
        // The Flutter FirebaseMessaging plugin will forward this to:
        // 1. firebaseMessagingBackgroundHandler (for background messages)
        // 2. onMessage stream (for foreground messages)

        // Let Flutter handle the notification via AwesomeNotifications
        // This ensures consistency with your Dart code
    }
}