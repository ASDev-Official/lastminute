import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'models/maintenance.dart';
import 'screens/home_screen.dart';
import 'screens/launcher_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/github_service.dart';
import 'services/maintenance_service.dart';
import 'services/notification_scheduler_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'widgets/maintenance_widgets.dart';

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
    final maintenanceService = MaintenanceService();

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

        // Check maintenance status
        return StreamBuilder(
          stream: maintenanceService.getMaintenanceStream(),
          builder: (context, snapshot) {
            final maintenance = snapshot.data;

            // If maintenance is ongoing, show full-screen notice and read-only mode
            if (maintenance != null && maintenance.isOngoing) {
              return _MaintenanceReadOnlyWrapper(
                maintenance: maintenance,
                child: HomeScreen(
                  user: user,
                  authService: authService,
                  githubService: githubService,
                  isReadOnly: true,
                ),
              );
            }

            // If maintenance is scheduled, show dialog on top of home screen
            return _MaintenanceDialogWrapper(
              maintenance: maintenance,
              child: HomeScreen(
                user: user,
                authService: authService,
                githubService: githubService,
                isReadOnly: false,
              ),
            );
          },
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

/// Wrapper for scheduled maintenance - shows dialog when maintenance is scheduled
class _MaintenanceDialogWrapper extends StatefulWidget {
  const _MaintenanceDialogWrapper({
    required this.maintenance,
    required this.child,
  });

  final Widget child;
  final Maintenance? maintenance;

  @override
  State<_MaintenanceDialogWrapper> createState() =>
      _MaintenanceDialogWrapperState();
}

class _MaintenanceDialogWrapperState extends State<_MaintenanceDialogWrapper> {
  late Set<String> _dismissedMaintenanceIds;
  bool _showingMaintenance = false;

  @override
  void initState() {
    super.initState();
    _dismissedMaintenanceIds = {};
    _showMaintenanceIfNeeded();
  }

  void _showMaintenanceIfNeeded() {
    if (widget.maintenance != null &&
        widget.maintenance!.isScheduled &&
        !_dismissedMaintenanceIds.contains(widget.maintenance!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _showingMaintenance = true);
      });
    }
  }

  @override
  void didUpdateWidget(_MaintenanceDialogWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showMaintenanceIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingMaintenance && widget.maintenance != null) {
      return ScheduledMaintenanceScreen(
        maintenance: widget.maintenance!,
        onDismiss: () {
          setState(() {
            _dismissedMaintenanceIds.add(widget.maintenance!.id);
            _showingMaintenance = false;
          });
        },
      );
    }
    return widget.child;
  }
}

/// Wrapper for ongoing maintenance - replaces content with read-only notice
class _MaintenanceReadOnlyWrapper extends StatefulWidget {
  const _MaintenanceReadOnlyWrapper({
    required this.maintenance,
    required this.child,
  });

  final Widget child;
  final Maintenance maintenance;

  @override
  State<_MaintenanceReadOnlyWrapper> createState() =>
      _MaintenanceReadOnlyWrapperState();
}

class _MaintenanceReadOnlyWrapperState
    extends State<_MaintenanceReadOnlyWrapper> {
  @override
  Widget build(BuildContext context) {
    return OngoingMaintenanceScreen(maintenance: widget.maintenance);
  }
}
