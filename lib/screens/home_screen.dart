import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/homework.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/github_service.dart';
import '../widgets/github_commit_card.dart';
import '../widgets/homework_card.dart';
import '../widgets/stats_card.dart';
import 'calendar_screen.dart';
import 'homework_detail_screen.dart';
import 'launcher_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.githubService,
    this.showLauncherButton = false,
  });

  final User user;
  final AuthService authService;
  final GithubService githubService;
  final bool showLauncherButton;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  void dispose() {
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
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
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
                        Icon(
                          Icons.schedule,
                          color: colorScheme.primary,
                          size: 28,
                        ),
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
                            MaterialPageRoute(
                              builder: (_) => const CalendarScreen(),
                            ),
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
        floatingActionButton: _selectedIndex == 0
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
              Icon(Icons.schedule, color: colorScheme.primary, size: 28),
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
        floatingActionButton: _selectedIndex == 0
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
        stream: _firestoreService.getIncompleteHomework(),
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

          final homework = snapshot.data ?? [];
          final overdue = homework.where((h) => h.isOverdue).toList();
          final upcoming = homework.where((h) => !h.isOverdue).toList();

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
                        'Stay on top of your homework',
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
              if (overdue.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Overdue (${overdue.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          HomeworkCard(homework: overdue[index]),
                      childCount: overdue.length,
                    ),
                  ),
                ),
              ],
              if (upcoming.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Upcoming (${upcoming.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          HomeworkCard(homework: upcoming[index]),
                      childCount: upcoming.length,
                    ),
                  ),
                ),
              ],
              if (homework.isEmpty)
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
                          'No homework yet!',
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
                Text(
                  widget.user.displayName ?? 'User',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About'),
                subtitle: const Text('LastMinute v1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Because Deadlines Always Sneak Up'),
                subtitle: const Text('Stay organized with homework reminders'),
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
}
