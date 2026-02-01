import 'dart:async';

import 'package:app_usage/app_usage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/homework.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/github_service.dart';
import '../services/notification_service.dart';
import '../services/study_mode_service.dart';
import '../utils/homework_grouper.dart';
import '../widgets/github_commit_card.dart';
import '../widgets/homework_card.dart';
import '../widgets/stats_card.dart';
import '../widgets/desktop_home_pane.dart';
import 'calendar_screen.dart';
import 'homework_detail_screen.dart';
import 'launcher_screen.dart';
import 'licenses_screen.dart';
import 'subjects_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.githubService,
    this.showLauncherButton = false,
    this.isReadOnly = false,
  });

  final User user;
  final AuthService authService;
  final GithubService githubService;
  final bool showLauncherButton;
  final bool isReadOnly;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final StudyModeService _studyModeService = StudyModeService();
  int _selectedIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _appMonitoringTimer;
  String? _lastForegroundApp;
  bool _completedExpanded = false;
  String? _selectedSubjectFilter;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _startAppMonitoring();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _appMonitoringTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _onNavigationChanged(int index) {
    if (_selectedIndex != index) {
      _fadeController.reset();
      setState(() {
        _selectedIndex = index;
      });
      _fadeController.forward();
    }
  }

  void _startAppMonitoring() {
    print('[HOME_SCREEN] Starting app monitoring with 500ms check interval...');
    _appMonitoringTimer?.cancel();
    _appMonitoringTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!mounted || !_studyModeService.isSessionActive) {
        print('[HOME_SCREEN] Monitor timer cancelled');
        timer.cancel();
        return;
      }

      try {
        final now = DateTime.now();
        final fiveSecondsAgo = now.subtract(const Duration(seconds: 5));

        final usage = await AppUsage().getAppUsage(fiveSecondsAgo, now);

        if (usage.isNotEmpty) {
          // Get the most recently used app
          final recentApp = usage.reduce(
            (a, b) => a.endDate.isAfter(b.endDate) ? a : b,
          );

          final packageName = recentApp.packageName;
          print(
            '[HOME_SCREEN] Current foreground: $packageName (last: $_lastForegroundApp)',
          );

          // Skip if it's the same app as before or if it's LastMinute
          if (packageName == _lastForegroundApp ||
              packageName == 'com.lastminute' ||
              packageName.startsWith('com.lastminute.')) {
            print('[HOME_SCREEN] Skipping (same app or LastMinute)');
            return;
          }

          _lastForegroundApp = packageName;

          // Check if app is disallowed
          if (!_studyModeService.isAppAllowed(packageName)) {
            // Use display name if available, otherwise package name
            final appNames = _studyModeService.appDisplayNames;
            final appName =
                appNames[packageName] ?? packageName.split('.').last;

            print(
              '🚫 [HOME_SCREEN] Blocked app detected: $packageName ($appName)',
            );

            // Navigate back to launcher
            if (mounted) {
              print('[HOME_SCREEN] Navigating back to launcher...');
              Navigator.pop(context);
            }
          } else {
            print('✅ [HOME_SCREEN] App allowed: $packageName');
          }
        } else {
          print('[HOME_SCREEN] No usage data found');
        }
      } catch (e) {
        print('❌ [HOME_SCREEN] Error monitoring apps: $e');
      }
    });
  }

  Future<void> _returnToLauncher() async {
    try {
      // Navigate back to home (launcher)
      SystemNavigator.pop();
    } catch (e) {
      print('Error returning to launcher: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to return to launcher: $e')),
        );
      }
    }
  }

  Future<void> _openFocusMode() async {
    const platform = MethodChannel('com.lastminute/launcher');
    try {
      final isDefault = await platform.invokeMethod('isDefaultLauncher');
      if (isDefault == true) {
        // Already set as launcher, navigate to launcher screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LauncherScreen()),
          );
        }
      } else {
        // Not set as launcher, show prompt
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Set LastMinute as Launcher'),
              content: const Text(
                'To use Focus Mode, you need to set LastMinute as your default launcher. This allows the app to control which apps you can access during study sessions.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await platform.invokeMethod('openLauncherSettings');
                    } catch (e) {
                      print('Error opening launcher settings: $e');
                    }
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking launcher status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Desktop Drawer Navigation
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onNavigationChanged,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main Content
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    title: Row(
                      children: [
                        Icon(Icons.alarm, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'LastMinute',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      PopupMenuButton<int>(
                        icon: CircleAvatar(
                          radius: 16,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            (widget.user.displayName?.trim().isNotEmpty ??
                                    false)
                                ? widget.user.displayName![0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        itemBuilder: (context) => <PopupMenuEntry<int>>[
                          PopupMenuItem(
                            child: Text(widget.user.displayName ?? 'User'),
                            enabled: false,
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            onTap: () async {
                              try {
                                await widget.authService.signOut();
                              } catch (e) {
                                print('❌ ERROR in logout popup: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Logout failed: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.logout_rounded),
                                SizedBox(width: 8),
                                Text('Sign out'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _selectedIndex == 0
                          ? _buildHomeTab()
                          : _buildProfileTab(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _selectedIndex == 0 && !widget.isReadOnly
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeworkDetailScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Homework'),
              )
            : null,
      );
    } else {
      // Mobile Layout
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.alarm, color: colorScheme.primary, size: 28),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'LastMinute',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (widget.showLauncherButton)
              IconButton(
                tooltip: 'Return to Launcher',
                onPressed: _returnToLauncher,
                icon: const Icon(Icons.home_rounded),
              ),
            IconButton(
              tooltip: 'Calendar',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                );
              },
              icon: const Icon(Icons.calendar_today_rounded),
            ),
            IconButton(
              tooltip: 'Focus Mode',
              onPressed: _openFocusMode,
              icon: const Icon(Icons.psychology_rounded),
            ),
            PopupMenuButton<int>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  (widget.user.displayName?.trim().isNotEmpty ?? false)
                      ? widget.user.displayName![0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              itemBuilder: (context) => <PopupMenuEntry<int>>[
                PopupMenuItem(
                  child: Text(widget.user.displayName ?? 'User'),
                  enabled: false,
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  onTap: () async {
                    try {
                      await widget.authService.signOut();
                    } catch (e) {
                      print('❌ ERROR in logout popup: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logout failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded),
                      SizedBox(width: 8),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: _selectedIndex == 0 ? _buildHomeTab() : _buildProfileTab(),
        ),
        floatingActionButton: _selectedIndex == 0 && !widget.isReadOnly
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeworkDetailScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Homework'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavigationChanged,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: StreamBuilder<List<Homework>>(
        stream: _firestoreService.getHomeworkStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            print('❌ ERROR loading homework: ${snapshot.error}');
            print('📋 Stack trace: ${snapshot.stackTrace}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading homework',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final allHomework = snapshot.data ?? [];

          // Get all unique subjects for filter
          final allSubjects = HomeworkGrouper.getUniqueSubjects(allHomework);

          // Apply subject filter
          final filteredHomework = HomeworkGrouper.filterBySubject(
            allHomework,
            _selectedSubjectFilter,
          );

          // Separate completed and incomplete
          final completed =
              filteredHomework.where((h) => h.isCompleted).toList()..sort(
                (a, b) => (b.completedAt ?? b.dueDate).compareTo(
                  a.completedAt ?? a.dueDate,
                ),
              );

          final incomplete = filteredHomework
              .where((h) => !h.isCompleted)
              .toList();

          // Group incomplete by deadline
          final groupedByDeadline = HomeworkGrouper.groupByDeadline(incomplete);

          final isWide = MediaQuery.of(context).size.width >= 1000;
          if (isWide) {
            return DesktopHomePane(
              greetingName: widget.user.displayName?.split(' ').first,
              firestoreService: _firestoreService,
              overdue: incomplete.where((h) => h.isOverdue).toList(),
              upcoming: incomplete.where((h) => !h.isOverdue).toList(),
              completed: completed,
              allHomework: allHomework,
              onAddHomework: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HomeworkDetailScreen(),
                  ),
                );
              },
              onOpenCalendar: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                );
              },
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${widget.user.displayName?.split(' ').first ?? 'there'}! 👋',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Because deadlines always sneak up. Here\'s your homework overview:',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatsCard(firestoreService: _firestoreService),
                    ],
                  ),
                ),
              ),
              // Subject Filter Chips
              if (allSubjects.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: _selectedSubjectFilter == null,
                            onSelected: (selected) {
                              setState(
                                () => _selectedSubjectFilter = selected
                                    ? null
                                    : _selectedSubjectFilter,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          ...allSubjects.map((subject) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(subject),
                                selected: _selectedSubjectFilter == subject,
                                onSelected: (selected) {
                                  setState(
                                    () => _selectedSubjectFilter = selected
                                        ? subject
                                        : null,
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              // Deadline Groups
              ...DeadlineGroup.values.map((group) {
                final homeworkInGroup = groupedByDeadline[group] ?? [];
                if (homeworkInGroup.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              _getIconForGroup(group),
                              color: _getColorForGroup(context, group),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${group.label} (${homeworkInGroup.length})',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getColorForGroup(context, group),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ...homeworkInGroup.map(
                        (hw) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HomeworkCard(homework: hw),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
              // Completed Section
              if (completed.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceVariant.withOpacity(0.7),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: _completedExpanded,
                          onExpansionChanged: (expanded) {
                            _completedExpanded = expanded;
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            'Completed (${completed.length})',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Tap to review what you have finished',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            16,
                          ),
                          children: [
                            ...completed.map(
                              (hw) => Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: HomeworkCard(homework: hw),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Empty State
              if (filteredHomework.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 80,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSubjectFilter != null
                              ? 'No homework for this subject'
                              : 'No homework yet!',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first homework',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForGroup(DeadlineGroup group) {
    switch (group) {
      case DeadlineGroup.under7days:
        return Icons.emergency_rounded;
      case DeadlineGroup.under14days:
        return Icons.warning_rounded;
      case DeadlineGroup.under30days:
        return Icons.schedule_rounded;
      case DeadlineGroup.above30days:
        return Icons.hourglass_bottom_rounded;
    }
  }

  Color _getColorForGroup(BuildContext context, DeadlineGroup group) {
    switch (group) {
      case DeadlineGroup.under7days:
        return Theme.of(context).colorScheme.error;
      case DeadlineGroup.under14days:
        return Theme.of(context).colorScheme.errorContainer;
      case DeadlineGroup.under30days:
        return Theme.of(context).colorScheme.tertiary;
      case DeadlineGroup.above30days:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    (widget.user.displayName?.trim().isNotEmpty ?? false)
                        ? widget.user.displayName![0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.user.displayName ?? 'User',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditNameDialog(),
                      tooltip: 'Edit name',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GithubCommitCard(githubService: widget.githubService),
        const SizedBox(height: 16),
        // Manage Subjects
        Card(
          child: ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Manage Subjects'),
            subtitle: const Text('Create and manage homework subjects'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubjectsScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Debug Mode: Test Notification Button
        if (kDebugMode)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.bug_report_outlined,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  title: Text(
                    'Debug Mode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Testing utilities for development',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onTertiaryContainer.withOpacity(0.8),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await NotificationService().showTestNotification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Send Test Notification'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About'),
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final info = snapshot.data!;
                      return Text(
                        'LastMinute ${info.version} (${info.buildNumber})',
                      );
                    }
                    return const Text('LastMinute');
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Because Deadlines Always Sneak Up'),
                subtitle: const Text('Stay organized with homework reminders'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Licenses'),
                subtitle: const Text('View open source licenses'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LicensesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.emergency,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(
                  'Emergency: Reset Launcher',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'If stuck in focus mode, use this to change launcher',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer.withOpacity(0.8),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () async {
                    const platform = MethodChannel('com.lastminute/launcher');
                    try {
                      await platform.invokeMethod('openLauncherSettings');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Launcher settings opened. Change your default launcher back to normal.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Launcher Settings'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  try {
                    await widget.authService.updateDisplayName(
                      displayName: nameController.text.trim(),
                    );
                    if (mounted) {
                      setState(() {
                        // Trigger rebuild to show new name
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Name updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update name: $e'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
