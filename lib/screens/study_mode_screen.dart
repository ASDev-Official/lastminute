import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';

import '../services/study_mode_service.dart';

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key});

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen> {
  final StudyModeService _studyModeService = StudyModeService();
  Timer? _timer;
  Timer? _burnInTimer;
  Duration _remainingTime = Duration.zero;
  int _selectedMinutes = 25; // Pomodoro default
  int? _customMinutes;
  List<String> _allowedApps = [];
  bool _isLoading = false;
  double _elementOffsetX = 0;
  double _elementOffsetY = 0;

  @override
  void initState() {
    super.initState();
    _loadAllowedApps();
    if (_studyModeService.isSessionActive) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _burnInTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllowedApps() async {
    setState(() => _isLoading = true);
    await _studyModeService.loadAllowedApps();
    setState(() {
      _allowedApps = _studyModeService.allowedApps;
      _isLoading = false;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingTime = _studyModeService.getRemainingTime();
          if (_remainingTime == Duration.zero) {
            timer.cancel();
          }
        });
      }
    });
  }

  void _startStudySession() async {
    if (kIsWeb || !_studyModeService.isStudyModeActive) {
      if (_allowedApps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one allowed app first'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final minutes = _customMinutes ?? _selectedMinutes;

      await _studyModeService.startStudySession(
        duration: Duration(minutes: minutes),
        onBlockedAppDetected: (appName) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🚫 $appName is not allowed during study session',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onComplete: () {
          if (mounted) {
            _stopBurnInProtection();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('🎉 Session Complete!'),
                content: Text('You studied for $minutes minutes. Great job!'),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Awesome!'),
                  ),
                ],
              ),
            );
            setState(() {});
          }
        },
        onUsageAccessDenied: () {
          if (mounted) {
            _stopStudySession();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Usage access is required for focus sessions. Please grant permission and try again.',
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
                      final platform = MethodChannel('com.lastminute/launcher');
                      try {
                        await platform.invokeMethod('openLauncherSettings');
                      } catch (e) {
                        print('Error: $e');
                      }
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
        },
      );
      // Only start timer and UI updates if session actually started
      if (_studyModeService.isSessionActive) {
        _startTimer();
        _startBurnInProtection();
        setState(() {});
      }
    }
  }

  void _startBurnInProtection() {
    _burnInTimer?.cancel();
    _burnInTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _studyModeService.isSessionActive) {
        setState(() {
          // Move elements randomly within a small range to prevent burn-in
          _elementOffsetX = (DateTime.now().millisecond % 20 - 10).toDouble();
          _elementOffsetY = (DateTime.now().millisecond % 20 - 10).toDouble();
        });
      }
    });
  }

  void _stopBurnInProtection() {
    _burnInTimer?.cancel();
    _burnInTimer = null;
    setState(() {
      _elementOffsetX = 0;
      _elementOffsetY = 0;
    });
  }

  void _stopStudySession() async {
    await _studyModeService.stopStudySession();
    _timer?.cancel();
    _stopBurnInProtection();
    setState(() {});
  }

  Future<void> _selectAllowedApps() async {
    setState(() => _isLoading = true);

    final apps = await _studyModeService.getInstalledApps();

    setState(() => _isLoading = false);

    if (!mounted) return;

    print('📱 Retrieved ${apps.length} apps for selection');

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _studyModeService.isSessionActive;

    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Mode')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Study mode with app blocking is only available on Android',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Dark theme with burn-in protection during active session
    if (isActive) {
      return PopScope(
        canPop: false, // Prevent back navigation
        child: Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false, // Remove back button
              title: const Text('Focus Session'),
              actions: [
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text(
                          'Stop Session?',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Are you sure you want to stop your study session?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _stopStudySession();
                            },
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              ],
            ),
            body: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Transform.translate(
                        offset: Offset(_elementOffsetX, _elementOffsetY),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 80,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              _formatDuration(_remainingTime),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'remaining',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 48),
                            Text(
                              'FOCUS MODE',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.3),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    // Normal theme when not active
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Session')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timer Display
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            isActive ? Icons.timer : Icons.timer_outlined,
                            size: 64,
                            color: isActive ? colorScheme.primary : Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isActive
                                ? _formatDuration(_remainingTime)
                                : _formatDuration(
                                    Duration(minutes: _selectedMinutes),
                                  ),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isActive ? 'Time Remaining' : 'Session Duration',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Allowed Apps Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.apps_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Allowed Apps',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                '${_allowedApps.length}/10',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_allowedApps.isEmpty)
                            const Text(
                              'No apps selected. Only system apps will be accessible.',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allowedApps.map((packageName) {
                                return Chip(
                                  avatar: const Icon(
                                    Icons.app_shortcut,
                                    size: 16,
                                  ),
                                  label: Text(
                                    packageName.split('.').last,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: isActive ? null : _selectAllowedApps,
                            icon: const Icon(Icons.edit),
                            label: const Text('Select Apps'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Duration Presets (only when not active)
                  if (!isActive) ...[
                    Text(
                      'Duration Presets',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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

                    // Custom Duration Input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
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
                              setState(() {
                                if (minutes != null && minutes > 0) {
                                  _customMinutes = minutes;
                                  _selectedMinutes = 0; // Deselect presets
                                } else {
                                  _customMinutes = null;
                                  if (_selectedMinutes == 0) {
                                    _selectedMinutes =
                                        25; // Fallback to default
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Start/Stop Button
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: isActive
                          ? _stopStudySession
                          : _startStudySession,
                      icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        isActive ? 'Stop Session' : 'Start Session',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Card
                  Card(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'During the session, only selected apps and system apps can be opened. Social media apps are blocked.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _selectedMinutes == minutes && _customMinutes == null;
    return FilterChip(
      selected: isSelected,
      label: Text('$minutes min\n$label'),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedMinutes = minutes;
            _customMinutes = null;
          });
        }
      },
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
            // Header
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

            // Search bar
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

            // Apps list
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
                            const SizedBox(height: 8),
                            Text(
                              widget.installedApps.isEmpty
                                  ? 'Make sure the app has permission to access installed apps'
                                  : 'Try a different search term',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
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
