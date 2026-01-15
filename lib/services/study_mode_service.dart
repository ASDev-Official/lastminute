import 'dart:async';
import 'dart:io';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyModeService {
  static final StudyModeService _instance = StudyModeService._internal();
  factory StudyModeService() => _instance;
  StudyModeService._internal();

  bool _isStudyModeActive = false;
  bool _isSessionActive = false;
  Timer? _studyTimer;
  Timer? _monitorTimer;
  DateTime? _studyStartTime;
  Duration _studyDuration = Duration.zero;
  List<String> _allowedApps = [];
  String? _lastForegroundApp;
  Function(String)? _onBlockedAppDetected;

  bool get isStudyModeActive => _isStudyModeActive;
  bool get isSessionActive => _isSessionActive;
  Duration get studyDuration => _studyDuration;
  DateTime? get studyStartTime => _studyStartTime;
  List<String> get allowedApps => List.unmodifiable(_allowedApps);

  static const String _allowedAppsKey = 'study_mode_allowed_apps';
  static const List<String> _systemApps = [
    'com.android.systemui',
    'com.android.launcher',
    'com.android.settings',
    'com.google.android.apps.nexuslauncher',
    'com.android.phone',
    'com.android.contacts',
    'com.android.dialer',
    'com.android.mms',
    'com.android.vending', // Play Store
    'com.google.android.gms',
    'com.google.android.googlequicksearchbox', // Google Search
    'com.android.chrome',
    'android',
    'com.sec.', // Samsung system apps prefix
    'com.samsung.', // Samsung apps prefix
    'com.google.android.inputmethod', // Keyboard
    'com.android.inputmethod', // Keyboard
    'com.android.documentsui', // File manager
    'com.android.providers',
    'com.android.server',
    'com.android.keychain',
    'com.google.android.packageinstaller',
  ];

  // Social media & distracting apps that cannot be allowed
  static const List<String> _blockedApps = [
    'com.instagram.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.twitter.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.reddit.frontpage',
    'com.discord',
    'com.whatsapp',
    'com.telegram.messenger',
  ];

  // Load allowed apps from storage
  Future<void> loadAllowedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowedApps = prefs.getStringList(_allowedAppsKey) ?? [];
      print('📚 Loaded ${_allowedApps.length} allowed apps');
    } catch (e) {
      print('❌ ERROR loading allowed apps: $e');
      _allowedApps = [];
    }
  }

  // Save allowed apps to storage
  Future<void> saveAllowedApps(List<String> apps) async {
    try {
      if (apps.length > 10) {
        throw Exception('Maximum 10 apps allowed');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_allowedAppsKey, apps);
      _allowedApps = List.from(apps);
      print('✅ Saved ${apps.length} allowed apps');
    } catch (e) {
      print('❌ ERROR saving allowed apps: $e');
      rethrow;
    }
  }

  // Get all installed non-system apps
  Future<List<AppInfo>> getInstalledApps() async {
    if (kIsWeb || !Platform.isAndroid) {
      print('⚠️ Not on Android platform');
      return [];
    }

    try {
      print('📱 Fetching installed apps...');
      final apps = await InstalledApps.getInstalledApps();

      print('📦 Total apps fetched: ${apps.length}');

      // Filter out system apps and blocked social media apps
      final filtered = apps.where((app) {
        final packageName = app.packageName.toLowerCase();

        // Exclude system apps
        final isSystemApp = _systemApps.any(
          (sys) => packageName.contains(sys.toLowerCase()),
        );
        if (isSystemApp) {
          return false;
        }

        // Exclude blocked social media apps
        final isBlockedApp = _blockedApps.any(
          (blocked) => packageName == blocked,
        );
        if (isBlockedApp) {
          return false;
        }

        return true;
      }).toList();

      filtered.sort((a, b) => a.name.compareTo(b.name));
      print(
        '✅ Found ${filtered.length} selectable apps (filtered from ${apps.length})',
      );

      // Print first few apps for debugging
      if (filtered.isNotEmpty) {
        print(
          '📱 Sample apps: ${filtered.take(3).map((a) => a.name).join(", ")}',
        );
      }

      return filtered;
    } catch (e, stackTrace) {
      print('❌ ERROR getting installed apps: $e');
      print('📋 Stack trace: $stackTrace');
      return [];
    }
  }

  // Check if an app is allowed
  bool isAppAllowed(String packageName) {
    final lowerPackage = packageName.toLowerCase();

    // Always allow our app
    if (lowerPackage.contains('lastminute')) return true;

    // Always allow system apps (check if package starts with any system app prefix)
    if (_systemApps.any((sys) {
      final lowerSys = sys.toLowerCase();
      return lowerPackage.startsWith(lowerSys) ||
          lowerPackage.contains(lowerSys);
    })) {
      return true;
    }

    // Check if in allowed list
    return _allowedApps.contains(packageName);
  }

  // Start study session with app monitoring
  Future<void> startStudySession({
    required Duration duration,
    required Function(String appName) onBlockedAppDetected,
    VoidCallback? onComplete,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      print('⚠️ Study session not supported on this platform');
      return;
    }

    try {
      print('🎯 Starting study session for ${duration.inMinutes} minutes');

      // Request overlay permission
      final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission != true) {
        print('⚠️ Requesting overlay permission...');
        final granted = await FlutterOverlayWindow.requestPermission();
        if (granted != true) {
          print('❌ Overlay permission denied');
          throw Exception('Overlay permission required for study sessions');
        }
      }

      _isStudyModeActive = true;
      _isSessionActive = true;
      _studyStartTime = DateTime.now();
      _studyDuration = duration;
      _onBlockedAppDetected = onBlockedAppDetected;

      // Start completion timer
      _studyTimer?.cancel();
      _studyTimer = Timer(duration, () {
        stopStudySession();
        onComplete?.call();
        print('✅ Study session completed!');
      });

      // Start monitoring for blocked apps
      _startAppMonitoring();

      print('✅ Study session started successfully');
    } catch (e) {
      print('❌ ERROR starting study session: $e');
      _isStudyModeActive = false;
      _isSessionActive = false;
    }
  }

  // Monitor foreground apps
  void _startAppMonitoring() {
    print('👀 Starting app monitoring...');

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }

      try {
        final now = DateTime.now();
        final oneSecondAgo = now.subtract(const Duration(seconds: 2));

        final usage = await AppUsage().getAppUsage(oneSecondAgo, now);

        if (usage.isNotEmpty) {
          // Get the most recently used app
          final recentApp = usage.reduce(
            (a, b) => a.endDate.isAfter(b.endDate) ? a : b,
          );

          final packageName = recentApp.packageName;

          // Skip if it's the same app as before
          if (packageName == _lastForegroundApp) return;

          _lastForegroundApp = packageName;

          // Check if app is allowed
          if (!isAppAllowed(packageName)) {
            print('🚫 Blocked app detected: $packageName');

            // Use package name for display (simple name from package)
            final appName = packageName.split('.').last;

            // Show blocking overlay
            await _showBlockingOverlay(appName);

            // Notify about blocked app
            _onBlockedAppDetected?.call(appName);
          }
        }
      } catch (e) {
        print('❌ ERROR monitoring apps: $e');
      }
    });
  }

  // Show blocking overlay and bring app to foreground
  Future<void> _showBlockingOverlay(String blockedAppName) async {
    try {
      // Bring app to foreground using platform channel
      const platform = MethodChannel('com.lastminute/app_blocker');
      await platform.invokeMethod('bringToForeground');

      print('🔒 Brought LastMinute to foreground, blocking $blockedAppName');
    } catch (e) {
      print('❌ ERROR showing blocking overlay: $e');
    }
  }

  // Stop study session
  void stopStudySession() {
    print('🛑 Stopping study session');

    _isStudyModeActive = false;
    _isSessionActive = false;
    _studyTimer?.cancel();
    _monitorTimer?.cancel();
    _studyTimer = null;
    _monitorTimer = null;
    _studyStartTime = null;
    _studyDuration = Duration.zero;
    _lastForegroundApp = null;
    _onBlockedAppDetected = null;

    print('✅ Study session stopped');
  }

  // Legacy method for backward compatibility
  void startStudyMode(Duration duration, {VoidCallback? onComplete}) {
    if (kIsWeb) return; // Not supported on web

    _isStudyModeActive = true;
    _studyStartTime = DateTime.now();
    _studyDuration = duration;

    _studyTimer?.cancel();
    _studyTimer = Timer(duration, () {
      stopStudyMode();
      onComplete?.call();
    });
  }

  void stopStudyMode() {
    _isStudyModeActive = false;
    _studyTimer?.cancel();
    _studyTimer = null;
    _studyStartTime = null;
    _studyDuration = Duration.zero;
  }

  Duration getRemainingTime() {
    if (!_isStudyModeActive || _studyStartTime == null) {
      return Duration.zero;
    }

    final elapsed = DateTime.now().difference(_studyStartTime!);
    final remaining = _studyDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Get app usage stats (Android only)
  Future<List<AppUsageInfo>> getAppUsageStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return [];

    try {
      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 1));
      final end = endDate ?? now;

      final List<AppUsageInfo> infos = await AppUsage().getAppUsage(start, end);
      return infos;
    } catch (e) {
      return [];
    }
  }

  // Get today's study time based on app usage
  Future<Duration> getTodayStudyTime() async {
    if (kIsWeb || !Platform.isAndroid) return Duration.zero;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final infos = await getAppUsageStats(startDate: startOfDay, endDate: now);

      // Filter for study-related apps or this app
      int totalMinutes = 0;
      for (var info in infos) {
        if (info.packageName.contains('lastminute')) {
          totalMinutes += info.usage.inMinutes;
        }
      }

      return Duration(minutes: totalMinutes);
    } catch (e) {
      return Duration.zero;
    }
  }

  void dispose() {
    _studyTimer?.cancel();
    _monitorTimer?.cancel();
  }
}
