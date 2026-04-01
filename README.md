# Attendigo

Attendigo is a Flutter-based mobile application powered by Firebase that helps students efficiently manage class timetables, track attendance, and receive automated lecture notifications.

The application focuses on reliability, automation, and accurate timetable management while maintaining a complete audit history of schedule changes. It is designed to reduce manual attendance tracking, prevent scheduling conflicts, and ensure users never miss important lectures.

---

## Features

### 1. Timetable Management

- Schedule recurring weekly lectures
- Create single-occurrence classes
- Automatic conflict detection
- Timetable versioning for safe updates
- Move, swap, or cancel specific lecture occurrences
- Prevent overlapping lectures using validation logic

### 2. Attendance Tracking

- Mark attendance as:
    - Present
    - Absent
    - Late
- Override attendance for:
    - Cancelled classes
    - Holidays
- Automatic attendance marking system
- Attendance percentage analytics
- Pending lecture tracking

### 3. Authentication

- Firebase Authentication integration
- Google Sign-In support
- Phone authentication using SMS OTP
- Secure user session handling

### 4. Notifications & Background Tasks

- High-priority lecture reminders
- Daily summary notifications
- Background task scheduling
- Automatic alarm rescheduling after device reboot
- Firebase Cloud Messaging (FCM) integration

### 5. Lecture Notes

- Create notes for specific lecture dates
- Update existing notes
- Delete notes
- Store notes securely in Firebase Firestore

### 6. History Audit System

- Logs all timetable changes including:
    - Lecture swaps
    - Lecture moves
    - Lecture deletions
- Maintains historical records for debugging and transparency

---

## Tech Stack

### Frontend

- Flutter
- Dart

### Backend

- Firebase Firestore
- Firebase Authentication
- Firebase Cloud Messaging (FCM)

### Notifications & Background Processing

- awesome_notifications
- workmanager

### Development Tools

- Android Studio
- Firebase Console
- Git & GitHub

---

## Project Structure

```
lib/
│
├── services/
│   ├── attendance_service.dart
│   ├── auth_service.dart
│   ├── lecture_service.dart
│   ├── notes_service.dart
│   ├── notification_service.dart
│   ├── timetable_history_service.dart
│   ├── workmanager_service.dart
│   └── fcm_background_handler.dart
│
├── screens/
│   ├── home_screen.dart
│   ├── timetable_screen.dart
│   ├── attendance_screen.dart
│   ├── add_lecture_screen.dart
│   └── settings_screen.dart
│
└── main.dart
```

---

## Service Responsibilities

### attendance_service.dart

Handles:

- Attendance status updates
- Overrides and cancellations
- Attendance percentage calculations
- Firestore attendance data management

### auth_service.dart

Handles:

- Firebase authentication
- Google Sign-In
- Phone number verification
- User session management

### lecture_service.dart

Handles:

- Timetable generation
- Lecture occurrence management
- Conflict resolution
- Schedule versioning using LectureScheduleVersion

### notes_service.dart

Handles:

- Create notes
- Read notes
- Update notes
- Delete notes

### notification_service.dart

Handles:

- Notification channel setup
- Permission requests
- Lecture reminder scheduling
- Alarm rescheduling after reboot

### timetable_history_service.dart

Handles:

- Logging timetable changes
- Maintaining audit history
- Tracking swaps and deletions

### workmanager_service.dart

Handles:

- Background task scheduling
- Daily summary notifications
- System health checks

---

## Installation

### Prerequisites

- Flutter SDK installed
- Android Studio installed
- Firebase project configured
- Android device or emulator

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/attendigo.git
cd attendigo
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Configure Firebase

Place your Firebase configuration file:

```
android/app/google-services.json
```

Make sure:

- Firebase project is created
- Authentication is enabled
- Firestore database is enabled
- FCM is enabled

---

## Running the Application

```bash
flutter run
```

---

## Background Tasks

Attendigo automatically runs scheduled background jobs using WorkManager.

Daily tasks include:

- Attendance summary notification
- Lecture reminder recovery
- System health checks

Default Schedule:

```
Daily Summary: 8:00 AM
```

---

## Notification System

The application uses:

- Local notifications for lecture reminders
- Push notifications via Firebase Cloud Messaging
- Automatic alarm recovery after device reboot

---

## Data Storage

All data is stored securely using Firebase Firestore.

Collections include:

```
users
lectures
attendance
notes
timetable_history
schedule_versions
```

---

## Security Features

- Firebase Authentication
- Secure Firestore rules
- OTP verification
- Protected user data access
- Background task isolation

---

## Future Improvements

- Cloud backup support
- Web dashboard version
- AI-based attendance prediction
- Multi-device synchronization
- Export attendance reports
- Dark mode UI
- Calendar integration

---

## Author

Deven  
B.Tech Information Technology Student  


---
---