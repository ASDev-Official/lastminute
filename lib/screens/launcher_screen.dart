import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../services/auth_service.dart';
import '../services/github_service.dart';
import '../services/study_mode_service.dart';
import 'home_screen.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  final StudyModeService _studyModeService = StudyModeService();
  Timer? _refreshTimer;
  Timer? _launcherCheckTimer;
  int _selectedMinutes = 25;
  int? _customMinutes;
  List<String> _allowedApps = [];

  @override
  void initState() {
    super.initState();
    _initLauncher();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        _studyModeService.loadSessionFromStorage().then((_) {
          setState(() {});
        });
      }
    });
    _launcherCheckTimer?.cancel();
    _launcherCheckTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      _checkLauncherStatus();
    });
  }

  Future<void> _checkLauncherStatus() async {
    if (!mounted) return;
    const platform = MethodChannel('com.lastminute/launcher');
    try {
      final isDefault = await platform.invokeMethod('isDefaultLauncher');
      if (isDefault != true && _studyModeService.isSessionActive) {
        await _studyModeService.stopStudySession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔔 Launcher changed. Focus session stopped.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      print('Error checking launcher status: $e');
    }
  }

  Future<void> _initLauncher() async {
    await _studyModeService.loadSessionFromStorage();
    await _studyModeService.loadAllowedApps();
    setState(() {
      _allowedApps = _studyModeService.allowedApps;
    });
  }

  Future<void> _openLauncherSettings() async {
    const platform = MethodChannel('com.lastminute/launcher');
    try {
      await platform.invokeMethod('openLauncherSettings');
    } catch (e) {
      print('Error opening launcher settings: $e');
    }
  }

  Future<void> _openLastMinuteApp() async {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in first'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Navigate to HomeScreen with launcher button enabled
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: user,
            authService: AuthService(),
            githubService: GithubService(),
            showLauncherButton: true,
          ),
        ),
      );
    }
  }

  Future<void> _selectAllowedApps() async {
    final apps = await _studyModeService.getInstalledApps();

    if (!mounted) return;

    if (apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No apps available. Make sure app permissions are granted.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AllowedAppsSelector(
        installedApps: apps,
        currentlyAllowed: _allowedApps,
      ),
    );

    if (selected != null) {
      try {
        await _studyModeService.saveAllowedApps(selected);
        setState(() => _allowedApps = selected);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${selected.length} apps allowed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _startStudySession() async {
    print('[LAUNCHER] Starting study session setup...');
    if (_allowedApps.isEmpty) {
      print('[LAUNCHER] ERROR: No allowed apps selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one allowed app first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final minutes = _customMinutes ?? _selectedMinutes;
    print(
      '[LAUNCHER] Starting session for $minutes minutes with ${_allowedApps.length} allowed apps',
    );

    await _studyModeService.startStudySession(
      duration: Duration(minutes: minutes),
      onBlockedAppDetected: (appName) {
        print('[LAUNCHER] Blocked app callback: $appName');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚫 $appName is not allowed during study session'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onComplete: () {
        print('[LAUNCHER] Session completed callback');
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('🎉 Session Complete!'),
              content: Text('You studied for $minutes minutes. Great job!'),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          );
        }
      },
      onUsageAccessDenied: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Usage access is required. Please grant permission and try again.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      onLauncherNotDefault: () {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Set LastMinute as Default Launcher'),
              content: const Text(
                'To start a focus session, you must set LastMinute as your default launcher. Open Home settings and select LastMinute as your launcher.',
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _openLauncherSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      },
    );

    if (_studyModeService.isSessionActive) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _launcherCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSessionActive = _studyModeService.isSessionActive;

    if (isSessionActive) {
      return _LauncherSessionScreen(
        studyModeService: _studyModeService,
        onOpenLastMinute: _openLastMinuteApp,
        onChangeLauncher: _openLauncherSettings,
        onStop: () async {
          await _studyModeService.stopStudySession();
          setState(() {});
        },
      );
    }

    return _LauncherHomeScreen(
      selectedMinutes: _selectedMinutes,
      onSelectMinutes: (minutes) => setState(() => _selectedMinutes = minutes),
      customMinutes: _customMinutes,
      onCustomMinutesChanged: (minutes) {
        setState(() => _customMinutes = minutes);
      },
      allowedApps: _allowedApps,
      onSelectAllowedApps: _selectAllowedApps,
      onStartSession: _startStudySession,
      onOpenLastMinute: _openLastMinuteApp,
      onChangeLauncher: _openLauncherSettings,
    );
  }
}

// Home launcher screen (no session active)
class _LauncherHomeScreen extends StatefulWidget {
  final int selectedMinutes;
  final ValueChanged<int> onSelectMinutes;
  final int? customMinutes;
  final ValueChanged<int?> onCustomMinutesChanged;
  final List<String> allowedApps;
  final VoidCallback onSelectAllowedApps;
  final VoidCallback onStartSession;
  final VoidCallback onOpenLastMinute;
  final VoidCallback onChangeLauncher;

  const _LauncherHomeScreen({
    required this.selectedMinutes,
    required this.onSelectMinutes,
    required this.customMinutes,
    required this.onCustomMinutesChanged,
    required this.allowedApps,
    required this.onSelectAllowedApps,
    required this.onStartSession,
    required this.onOpenLastMinute,
    required this.onChangeLauncher,
  });

  @override
  State<_LauncherHomeScreen> createState() => _LauncherHomeScreenState();
}

class _LauncherHomeScreenState extends State<_LauncherHomeScreen> {
  late PageController _pageController;
  final StudyModeService _studyModeService = StudyModeService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LastMinute Study Session'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: widget.onChangeLauncher,
              icon: const Icon(Icons.home_filled),
              tooltip: 'Change Launcher',
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          children: [_buildWelcomePage(context), _buildSetupPage(context)],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 32),
            const Text(
              'LastMinute Launcher',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Start a focus session to block distracting apps and stay on task.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            FilledButton.icon(
              onPressed: () => _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              icon: const Icon(Icons.psychology_rounded),
              label: const Text('Start Study Mode'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.onOpenLastMinute,
              icon: const Icon(Icons.app_shortcut),
              label: const Text('Open LastMinute'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.grey.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupPage(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.grey.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Duration Presets',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDurationChip(25, 'Pomodoro'),
                  _buildDurationChip(50, 'Extended'),
                  _buildDurationChip(90, 'Deep Work'),
                  _buildDurationChip(120, 'Marathon'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Duration (minutes)',
                  hintText: 'Enter minutes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.edit_calendar),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final minutes = int.tryParse(value);
                  if (minutes != null && minutes > 0) {
                    widget.onCustomMinutesChanged(minutes);
                    widget.onSelectMinutes(0);
                  } else {
                    widget.onCustomMinutesChanged(null);
                  }
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Allowed Apps',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (widget.allowedApps.isEmpty)
                const Text(
                  'No apps selected. Only system apps will be accessible.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.allowedApps.map((packageName) {
                    final displayName =
                        _studyModeService.appDisplayNames[packageName] ??
                        packageName.split('.').last;
                    return Chip(
                      avatar: const Icon(Icons.app_shortcut, size: 16),
                      label: Text(displayName),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onSelectAllowedApps,
                icon: const Icon(Icons.edit),
                label: const Text('Select Apps'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: widget.onStartSession,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Start Session',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected =
        widget.selectedMinutes == minutes && widget.customMinutes == null;
    return FilterChip(
      selected: isSelected,
      label: Text('$minutes min\n$label'),
      onSelected: (selected) {
        if (selected) {
          widget.onSelectMinutes(minutes);
          widget.onCustomMinutesChanged(null);
        }
      },
    );
  }
}

// Session screen (session active)
class _LauncherSessionScreen extends StatefulWidget {
  final StudyModeService studyModeService;
  final VoidCallback onOpenLastMinute;
  final VoidCallback onChangeLauncher;
  final VoidCallback onStop;

  const _LauncherSessionScreen({
    required this.studyModeService,
    required this.onOpenLastMinute,
    required this.onChangeLauncher,
    required this.onStop,
  });

  @override
  State<_LauncherSessionScreen> createState() => _LauncherSessionScreenState();
}

class _LauncherSessionScreenState extends State<_LauncherSessionScreen> {
  List<AppInfo> _launchableApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllowedApps();
  }

  Future<void> _loadAllowedApps() async {
    final allApps = await widget.studyModeService.getInstalledApps();
    final allowedPackages = widget.studyModeService.allowedApps.toSet();

    setState(() {
      _launchableApps = allApps
          .where((app) => allowedPackages.contains(app.packageName))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _launchApp(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch app: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = widget.studyModeService.getRemainingTime();

    return WillPopScope(
      onWillPop: () async => false,
      child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Focus Session'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: widget.onChangeLauncher,
                icon: const Icon(Icons.home_filled),
                tooltip: 'Change Launcher',
              ),
            ],
            backgroundColor: Colors.black,
          ),
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.timer,
                          color: Colors.white70,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'FOCUS SESSION',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(remainingTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'remaining',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'ALLOWED APPS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : _launchableApps.isEmpty
                        ? const Center(
                            child: Text(
                              'No apps available',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: _launchableApps.length,
                            itemBuilder: (context, index) {
                              final app = _launchableApps[index];
                              return InkWell(
                                onTap: () => _launchApp(app.packageName),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: app.icon != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                app.icon!,
                                                width: 60,
                                                height: 60,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.app_shortcut,
                                              color: Colors.white70,
                                              size: 30,
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      app.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.onOpenLastMinute,
                          icon: const Icon(Icons.app_shortcut),
                          label: const Text('Open LastMinute'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: widget.onStop,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Stop Session'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// Apps selector widget
class _AllowedAppsSelector extends StatefulWidget {
  const _AllowedAppsSelector({
    required this.installedApps,
    required this.currentlyAllowed,
  });

  final List<AppInfo> installedApps;
  final List<String> currentlyAllowed;

  @override
  State<_AllowedAppsSelector> createState() => _AllowedAppsSelectorState();
}

class _AllowedAppsSelectorState extends State<_AllowedAppsSelector> {
  late Set<String> _selectedApps;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedApps = Set.from(widget.currentlyAllowed);
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.installedApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Allowed Apps',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedApps.length}/10 selected',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _selectedApps.toList()),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredApps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apps_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.installedApps.isEmpty
                                  ? 'No apps available'
                                  : 'No apps match your search',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        final isSelected = _selectedApps.contains(
                          app.packageName,
                        );
                        final canSelect =
                            _selectedApps.length < 10 || isSelected;

                        return CheckboxListTile(
                          value: isSelected,
                          enabled: canSelect,
                          onChanged: canSelect
                              ? (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedApps.add(app.packageName);
                                    } else {
                                      _selectedApps.remove(app.packageName);
                                    }
                                  });
                                }
                              : null,
                          title: Text(app.name),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          secondary: app.icon != null
                              ? Image.memory(app.icon!, width: 40, height: 40)
                              : const Icon(Icons.app_shortcut),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
