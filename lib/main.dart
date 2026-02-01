import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/launcher_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/github_service.dart';
import 'services/notification_scheduler_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service (includes background handlers)
  await NotificationService().initialize();

  runApp(const LastMinuteApp());
}

class LastMinuteApp extends StatelessWidget {
  const LastMinuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastMinute',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AppRouter(),
      routes: {'/launcher': (context) => const LauncherScreen()},
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool _isLauncherIntent = false;
  bool _checkedIntent = false;

  @override
  void initState() {
    super.initState();
    _checkIfLauncherIntent();
  }

  Future<void> _checkIfLauncherIntent() async {
    try {
      const platform = MethodChannel('com.lastminute/launcher');
      final result = await platform.invokeMethod('isLauncherIntent');
      if (mounted) {
        setState(() {
          _isLauncherIntent = result == true;
          _checkedIntent = true;
        });
      }
    } catch (e) {
      print('Error checking launcher intent: $e');
      if (mounted) {
        setState(() {
          _checkedIntent = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking intent
    if (!_checkedIntent) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    // If launched as launcher (home button pressed), always show launcher screen
    if (_isLauncherIntent) {
      return const LauncherScreen();
    }

    return const _AuthGate();
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final githubService = GithubService();
    final firestoreService = FirestoreService();
    final notificationScheduler = NotificationSchedulerService();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: authService);
        }

        // Run migration when user logs in
        _runMigration(firestoreService);

        // Start watching for homework changes and sync reminders
        _initializeReminders(notificationScheduler);

        return HomeScreen(
          user: user,
          authService: authService,
          githubService: githubService,
        );
      },
    );
  }

  void _runMigration(FirestoreService firestoreService) {
    // Run migration in background
    firestoreService.migrateSubjectsToOptions().catchError((e) {
      print('Migration error (non-critical): $e');
    });
  }

  void _initializeReminders(NotificationSchedulerService scheduler) {
    // Start listening to homework changes for real-time reminder scheduling
    scheduler.startWatchingHomework().catchError((e) {
      print('Error starting homework listener (non-critical): $e');
    });

    // Sync reminders for all homework on startup
    scheduler.syncRemindersForAllHomework().catchError((e) {
      print('Error syncing reminders (non-critical): $e');
    });
  }
}
