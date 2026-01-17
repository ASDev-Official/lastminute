import 'dart:async';
import 'dart:io';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'notification_service.dart';

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
  Map<String, String> _appDisplayNames = {}; // packageName -> displayName
  String? _lastForegroundApp;
  Function(String)? _onBlockedAppDetected;
  bool _usageAccessRequested = false;
  bool _hasUsageAccess = false;
  Timer? _persistTimer;

  // Persistence keys
  static const String _sessionActiveKey = 'study_session_active';
  static const String _sessionStartEpochKey = 'study_session_start_epoch_ms';
  static const String _sessionDurationMsKey = 'study_session_duration_ms';
  static const String _sessionRemainingMsKey = 'study_session_remaining_ms';

  bool get isStudyModeActive => _isStudyModeActive;
  bool get isSessionActive => _isSessionActive;
  Duration get studyDuration => _studyDuration;
  DateTime? get studyStartTime => _studyStartTime;
  List<String> get allowedApps => List.unmodifiable(_allowedApps);
  Map<String, String> get appDisplayNames => Map.unmodifiable(_appDisplayNames);

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

      // Fetch and store display names for these apps
      try {
        final installedApps = await InstalledApps.getInstalledApps(
          excludeSystemApps: false,
        );
        for (final app in installedApps) {
          if (apps.contains(app.packageName)) {
            _appDisplayNames[app.packageName] = app.name;
          }
        }
      } catch (e) {
        print('⚠️ Error fetching app display names: $e');
      }

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
        final packageName = app.packageName;
        final lowerPackageName = packageName.toLowerCase();

        // Exclude system apps
        final isSystemApp = _systemApps.any(
          (sys) => lowerPackageName.contains(sys.toLowerCase()),
        );
        if (isSystemApp) {
          return false;
        }

        // Exclude blocked social media apps
        final isBlockedApp = _blockedApps.any(
          (blocked) => packageName == blocked,
        );
        if (isBlockedApp) {
          print(
            '🚫 Excluding blocked app from selection: ${app.name} ($packageName)',
          );
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
    print('[isAppAllowed] Checking: $packageName');
    final lowerPackage = packageName.toLowerCase();

    // Always allow our app
    if (lowerPackage.contains('lastminute')) {
      print('[isAppAllowed] -> ALLOWED (LastMinute app)');
      return true;
    }

    // Always allow system apps (check if package starts with any system app prefix)
    if (_systemApps.any((sys) {
      final lowerSys = sys.toLowerCase();
      return lowerPackage.startsWith(lowerSys) ||
          lowerPackage.contains(lowerSys);
    })) {
      print('[isAppAllowed] -> ALLOWED (System app)');
      return true;
    }

    // Check if in allowed list (social media apps are already excluded from selection)
    print('[isAppAllowed] Checking against allowed list: $_allowedApps');
    final isInAllowedList = _allowedApps.contains(packageName);
    print(
      '[isAppAllowed] -> ${isInAllowedList ? "ALLOWED" : "BLOCKED"} (${isInAllowedList ? "in" : "not in"} allowed list)',
    );
    return isInAllowedList;
  }

  // Start study session with app monitoring
  Future<void> startStudySession({
    required Duration duration,
    required Function(String appName) onBlockedAppDetected,
    VoidCallback? onComplete,
    Function()? onUsageAccessDenied,
    Function()? onLauncherNotDefault,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      print('⚠️ Study session not supported on this platform');
      return;
    }

    try {
      print('🎯 Starting study session for ${duration.inMinutes} minutes');

      // Check usage access permission (only request once)
      if (!_usageAccessRequested) {
        _usageAccessRequested = true;

        // Try to check if we have access
        try {
          final now = DateTime.now();
          final oneSecondAgo = now.subtract(const Duration(seconds: 1));
          await AppUsage().getAppUsage(oneSecondAgo, now);
          _hasUsageAccess = true;
          print('✅ Usage access granted');
        } catch (e) {
          print('⚠️ No usage access, requesting...');

          // Request access using platform channel
          const platform = MethodChannel('com.lastminute/permissions');
          try {
            final granted = await platform.invokeMethod('requestUsageAccess');
            _hasUsageAccess = granted == true;

            if (!_hasUsageAccess) {
              print('❌ Usage access denied');
              onUsageAccessDenied?.call();
              _usageAccessRequested = false; // Allow retry next time
              return;
            }
          } catch (e) {
            print('❌ Error requesting usage access: $e');
            onUsageAccessDenied?.call();
            _usageAccessRequested = false;
            return;
          }
        }
      }

      if (!_hasUsageAccess) {
        print('❌ No usage access available');
        onUsageAccessDenied?.call();
        return;
      }

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

      // Check if app is default launcher and block if not
      const platform = MethodChannel('com.lastminute/launcher');
      try {
        final isDefault = await platform.invokeMethod('isDefaultLauncher');
        if (isDefault != true) {
          print('⚠️ App is not default launcher. Blocking session start.');
          onLauncherNotDefault?.call();
          return;
        }
      } catch (e) {
        print('⚠️ Could not verify launcher status: $e');
        onLauncherNotDefault?.call();
        return;
      }

      // Enable wakelock to keep screen on
      try {
        await WakelockPlus.enable();
        print('✅ Screen wakelock enabled');
      } catch (e) {
        print('⚠️ Could not enable wakelock: $e');
      }

      _isStudyModeActive = true;
      _isSessionActive = true;
      _studyStartTime = DateTime.now();
      _studyDuration = duration;
      _onBlockedAppDetected = onBlockedAppDetected;

      // Persist initial session state
      await _persistSessionState();

      // Start persistence + notification updater
      _startPersistenceTicker();
      await NotificationService().showStudyOngoing(
        remaining: getRemainingTime(),
      );

      // Start completion timer
      _studyTimer?.cancel();
      _studyTimer = Timer(duration, () {
        stopStudySession();
        onComplete?.call();
        print('✅ Study session completed!');
      });

      // Start foreground service to keep monitoring active
      await _startForegroundService();

      // Start monitoring for blocked apps
      _startAppMonitoring();

      print('✅ Study session started successfully');
    } catch (e) {
      print('❌ ERROR starting study session: $e');
      _isStudyModeActive = false;
      _isSessionActive = false;

      // Clean up on error
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      // Stop notification if shown
      await NotificationService().stopStudyOngoing().catchError((_) {});
    }
  }

  // Monitor foreground apps
  void _startAppMonitoring() {
    print(
      '👀 [APP_MONITORING] Starting app monitoring with 500ms check interval...',
    );

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_isSessionActive) {
        print('⏹️ [APP_MONITORING] Session inactive, stopping monitor');
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
            '[CHECK] Current foreground app: $packageName (last: $_lastForegroundApp)',
          );

          // Skip if it's the same app as before
          if (packageName == _lastForegroundApp) {
            print('[SKIP] Same app as before');
            return;
          }

          _lastForegroundApp = packageName;

          // Check if app is allowed
          if (!isAppAllowed(packageName)) {
            print('🚫 [BLOCKED_APP] Detected: $packageName');

            // Use display name if available, otherwise package name
            final appName =
                _appDisplayNames[packageName] ?? packageName.split('.').last;

            print('🚫 [BLOCKED_APP] Display name: $appName');

            // Show blocking overlay
            await _showBlockingOverlay(appName);

            // Notify about blocked app
            _onBlockedAppDetected?.call(appName);
          } else {
            print('✅ [ALLOWED_APP] App allowed: $packageName');
          }
        } else {
          print('[NO_USAGE] No app usage data found');
        }
      } catch (e) {
        print('❌ [ERROR] monitoring apps: $e');
      }
    });
  }

  // Show blocking overlay and bring app to foreground
  Future<void> _showBlockingOverlay(String blockedAppName) async {
    try {
      print('[PLATFORM] Calling bringToForeground for $blockedAppName...');
      // Bring app to foreground using platform channel
      const platform = MethodChannel('com.lastminute/app_blocker');
      await platform.invokeMethod('bringToForeground');

      print(
        '🔒 [SUCCESS] Brought LastMinute to foreground, blocked $blockedAppName',
      );
    } catch (e) {
      print('❌ [PLATFORM_ERROR] showing blocking overlay: $e');
    }
  }

  // Start foreground service to keep monitoring active
  Future<void> _startForegroundService() async {
    try {
      print('[FOREGROUND_SERVICE] Starting foreground service...');
      const platform = MethodChannel('com.lastminute/app_blocker');
      await platform.invokeMethod('startForegroundService');
      print('✅ [FOREGROUND_SERVICE] Foreground service started successfully');
    } catch (e) {
      print('⚠️ [FOREGROUND_SERVICE] Could not start foreground service: $e');
    }
  }

  // Stop foreground service
  Future<void> _stopForegroundService() async {
    try {
      print('[FOREGROUND_SERVICE] Stopping foreground service...');
      const platform = MethodChannel('com.lastminute/app_blocker');
      await platform.invokeMethod('stopForegroundService');
      print('✅ [FOREGROUND_SERVICE] Foreground service stopped');
    } catch (e) {
      print('⚠️ [FOREGROUND_SERVICE] Could not stop foreground service: $e');
    }
  }

  // Stop study session
  Future<void> stopStudySession() async {
    print('🛑 [SESSION] Stopping study session');

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

    // Stop foreground service
    await _stopForegroundService();

    // Disable wakelock
    WakelockPlus.disable().catchError((e) {
      print('⚠️ [WAKELOCK] Error disabling wakelock: $e');
    });

    // Reset usage access flag to allow requesting again in future sessions
    _usageAccessRequested = false;
    _hasUsageAccess = false;

    // Stop persistence + notification
    _persistTimer?.cancel();
    _persistTimer = null;
    await _clearSessionState();
    await NotificationService().stopStudyOngoing().catchError((_) {});

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

  // Load session state from storage (for launcher or app restarts)
  Future<void> loadSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool(_sessionActiveKey) ?? false;
      if (!active) return;

      final startMs = prefs.getInt(_sessionStartEpochKey);
      final durationMs = prefs.getInt(_sessionDurationMsKey);
      if (startMs == null || durationMs == null) return;

      _studyStartTime = DateTime.fromMillisecondsSinceEpoch(startMs);
      _studyDuration = Duration(milliseconds: durationMs);
      _isStudyModeActive = true;
      _isSessionActive = true;
    } catch (e) {
      print('❌ ERROR loading session from storage: $e');
    }
  }

  // Persist current session state
  Future<void> _persistSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionActiveKey, _isSessionActive);
      await prefs.setInt(
        _sessionStartEpochKey,
        _studyStartTime?.millisecondsSinceEpoch ?? 0,
      );
      await prefs.setInt(_sessionDurationMsKey, _studyDuration.inMilliseconds);
      await prefs.setInt(
        _sessionRemainingMsKey,
        getRemainingTime().inMilliseconds,
      );
    } catch (e) {
      print('❌ ERROR persisting session state: $e');
    }
  }

  Future<void> _clearSessionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionActiveKey);
      await prefs.remove(_sessionStartEpochKey);
      await prefs.remove(_sessionDurationMsKey);
      await prefs.remove(_sessionRemainingMsKey);
    } catch (e) {
      print('❌ ERROR clearing session state: $e');
    }
  }

  void _startPersistenceTicker() {
    _persistTimer?.cancel();
    _persistTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isSessionActive) {
        timer.cancel();
        return;
      }
      await _persistSessionState();
      await NotificationService().updateStudyOngoing(
        remaining: getRemainingTime(),
      );
    });
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
