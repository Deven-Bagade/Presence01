import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:presence01/pages/about_screen.dart';
import 'package:presence01/pages/help_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'pages/splash_screen.dart';
import 'pages/home_screen.dart';
import 'pages/login_screen.dart';
import 'pages/profile_screen.dart';
import 'pages/settings_screen.dart';
import 'pages/timetable_screen.dart';
import 'pages/attendance_screen.dart';
import 'pages/notes_screen.dart';
import 'pages/add_lecture_screen.dart';
import 'pages/notification_debug_screen.dart';
import 'widgets/terms_dialog.dart';
import 'pages/analytics_screen.dart';
import 'pages/terms_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/workmanager_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'themes/app_themes.dart';
import 'package:provider/provider.dart';

/// 🔐 Global singleton instance
final NotificationService notificationService = NotificationService();

// Import the callback dispatcher from workmanager_service
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔧 Background task executing: $task');
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // This hides the red screen / yellow stripes entirely
    // and just shows an empty invisible box instead.
    return const SizedBox.shrink();
  };

  // ⚠️ CRITICAL: CREATE NOTIFICATION CHANNELS IMMEDIATELY
  print('🔄 Creating notification channels in main()...');
  try {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_launcher', // ✅ This sets the default app icon
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
          channelShowBadge: true,
        ),
      ],
      debug: true,
    );

    print('✅ Notification channels created in main()');

    // Test that channels work
    print('📱 Testing channel creation...');
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999999,
          channelKey: 'high_priority',
          title: 'App Started',
          body: 'Notification channels initialized',
          notificationLayout: NotificationLayout.Default,
          // ✅ Icon is automatically taken from initialize() above
        ),
      );
      await Future.delayed(Duration(milliseconds: 500));
      await AwesomeNotifications().cancel(999999);
      print('✅ Channel test successful');
    } catch (e) {
      print('❌ Channel test failed: $e');
    }
  } catch (e) {
    print('❌ Failed to create channels in main(): $e');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    // Initialize WorkManager FIRST (before services)
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    print('✅ WorkManager initialized');

    // Initialize services
    await notificationService.initialize();
    await WorkManagerService.initialize();

    // Try post-reboot recovery
    try {
      await notificationService.handlePostRebootRecovery();
    } catch (e) {
      print('⚠️ Post-reboot recovery failed: $e');
    }

    debugPrint('✅ All core services initialized');

  } catch (e) {
    debugPrint('⚠️ Initialization error: $e');
    // Continue anyway - don't crash the app
  }

  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Attendigo',
            theme: themeProvider.themeData.toThemeData(),
            home: const RootRouter(),
            routes: {
              '/add-lecture': (_) => const AddEditLectureScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/terms': (_) => const TermsScreen(),
              '/analytics': (_) => const AnalyticsScreen(),
              '/notification-debug': (_) => const NotificationDebugScreen(),
              '/help': (context) => const HelpScreen(),
              '/about': (context) => const AboutScreen()
            },
          );
        },
      ),
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  bool _checkingTerms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      // App went to background
        print('📱 App went to background');
        break;
      case AppLifecycleState.resumed:
      // App came to foreground
        print('📱 App came to foreground');
        // Check notification channels when app resumes
        _checkNotificationChannels();
        break;
      default:
        break;
    }
  }

  Future<void> _checkNotificationChannels() async {
    try {
      // Quick test to ensure channels still work
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          channelKey: 'high_priority',
          title: 'App Resumed',
          body: 'Checking notification channels',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      await Future.delayed(Duration(milliseconds: 100));
      // Cancel the test notification
      await AwesomeNotifications().cancelAll();
    } catch (e) {
      print('⚠️ Channel check failed: $e');
    }
  }

  Future<bool> _checkTermsForUser(User user) async {
    final hasAccepted = await _authService.hasAcceptedTerms(user.uid);
    if (hasAccepted) return true;

    return await TermsDialog.show(
      context: context,
      userId: user.uid,
      authService: _authService,
    ) == true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        if (user == null) return const LoginScreen();

        if (!_checkingTerms) {
          _checkingTerms = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final accepted = await _checkTermsForUser(user);
            if (!accepted && mounted) {
              await _authService.signOut();
            } else {
              await _initializeUserNotifications(user);
            }
            _checkingTerms = false;
          });
        }

        return const MainLayout();
      },
    );
  }

  Future<void> _initializeUserNotifications(User user) async {
    try {
      print('📱 Initializing notifications for user: ${user.uid}');

      // First ensure permissions
      final granted = await notificationService.requestNotificationPermissions();
      print('📱 Permissions granted: $granted');

      if (granted) {
        // Test channel immediately
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 1000,
              channelKey: 'high_priority',
              title: 'Welcome!',
              body: 'Notifications are enabled for your account',
              notificationLayout: NotificationLayout.Default,
            ),
          );
          await Future.delayed(Duration(milliseconds: 500));
          await AwesomeNotifications().cancel(1000);
          print('✅ User notification test successful');
        } catch (e) {
          print('❌ User notification test failed: $e');
          // Try to recreate channels
          try {
            await AwesomeNotifications().initialize(
              'resource://drawable/ic_launcher',
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
            print('✅ Recreated channels for user');
          } catch (e2) {
            print('❌ Failed to recreate channels: $e2');
          }
        }

        // Schedule all notifications
        await notificationService.rescheduleAllNotifications();
        debugPrint('✅ Notifications scheduled for ${user.uid}');
      }
    } catch (e) {
      debugPrint('❌ Notification init error: $e');
    }
  }
}

/// ===================== MAIN LAYOUT =====================

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<GlobalKey<NavigatorState>> _navigatorKeys =
  List.generate(5, (_) => GlobalKey<NavigatorState>());

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
    BottomNavigationBarItem(icon: Icon(Icons.schedule), label: "Timetable"),
    BottomNavigationBarItem(
        icon: Icon(Icons.check_circle), label: "Attendance"),
    BottomNavigationBarItem(icon: Icon(Icons.note), label: "Notes"),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
  ];

  // Define routes for each tab
  final List<Map<String, WidgetBuilder>> _tabRoutes = [
    // Home tab routes
    {
      '/home': (_) => const HomeScreen(),
      '/add-lecture': (_) => const AddEditLectureScreen(),
      '/notification-debug': (_) => const NotificationDebugScreen(),
    },
    // Timetable tab routes
    {
      '/timetable': (_) => const TimetableScreen(),
      '/add-lecture': (_) => const AddEditLectureScreen(),
    },
    // Attendance tab routes
    {
      '/attendance': (_) => const AttendanceScreen(),
    },
    // Notes tab routes
    {
      '/notes': (_) => const NotesScreen(),
    },
    // Profile tab routes - THIS IS CRITICAL!
    {
      '/profile': (_) => const ProfileScreen(),
      '/settings': (_) => const SettingsScreen(),
      '/analytics': (_) => const AnalyticsScreen(),
      '/notification-debug': (_) => const NotificationDebugScreen(),
      '/terms': (_) => const TermsScreen(),
    },
  ];

  // Initial routes for each tab
  final List<String> _initialRoutes = [
    '/home',
    '/timetable',
    '/attendance',
    '/notes',
    '/profile',
  ];

  List<Widget> _buildScreens() {
    return List.generate(5, (index) {
      return Navigator(
        key: _navigatorKeys[index],
        initialRoute: _initialRoutes[index],
        onGenerateRoute: (settings) {
          final routeBuilder = _tabRoutes[index][settings.name];
          if (routeBuilder != null) {
            return MaterialPageRoute(
              builder: routeBuilder,
              settings: settings,
            );
          }
          return null;
        },
      );
    });
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: _navItems,
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton(
        onPressed: () {
          // Navigate within the current tab's navigator
          _navigatorKeys[_currentIndex].currentState?.pushNamed('/add-lecture');
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}