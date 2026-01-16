import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/homework.dart' as hw;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const int _studyNotificationId = 1001;

  Future<void> initialize() async {
    if (kIsWeb) {
      print('ℹ️ Notifications not supported on web');
      return;
    }

    try {
      print('🔔 Initializing notification service...');
      tz.initializeTimeZones();
      print('✅ Timezone initialized');

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(settings);
      print('✅ Notification plugin initialized: $initialized');

      // Request permissions
      if (defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        print('🔔 Android notification permission granted: $granted');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final granted = await _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        print('🔔 iOS notification permission granted: $granted');
      }

      print('✅ Notification service initialized successfully');
    } catch (e, stackTrace) {
      print('❌ ERROR initializing notification service: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  Future<void> scheduleHomeworkReminder(hw.Homework homework) async {
    if (kIsWeb) return;

    try {
      print(
        '🔔 Scheduling ${homework.reminderTimes.length} reminder(s) for "${homework.title}"',
      );

      if (homework.reminderTimes.isEmpty) {
        print('ℹ️ No reminder times set for this homework');
        return;
      }

      int scheduled = 0;
      for (int i = 0; i < homework.reminderTimes.length; i++) {
        final reminderTime = homework.reminderTimes[i];
        if (reminderTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: homework.id.hashCode + i,
            title: 'Homework Reminder: ${homework.title}',
            body:
                homework.description ?? 'Due: ${_formatDate(homework.dueDate)}',
            scheduledDate: reminderTime,
          );
          scheduled++;
          print(
            '✅ Scheduled reminder #${i + 1} for ${_formatDate(reminderTime)}',
          );
        } else {
          print('⏭️ Skipping past reminder time: ${_formatDate(reminderTime)}');
        }
      }

      print(
        '✅ Successfully scheduled $scheduled out of ${homework.reminderTimes.length} reminders',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR scheduling homework reminder: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      print('📅 Scheduling notification ID $id for $tzScheduledDate');

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'homework_reminders',
            'Homework Reminders',
            channelDescription: 'Notifications for homework deadlines',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Notification scheduled successfully (ID: $id)');
    } catch (e, stackTrace) {
      print('❌ ERROR scheduling notification (ID: $id): $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> cancelHomeworkReminders(String homeworkId) async {
    if (kIsWeb) return;

    // Cancel all notifications for this homework (up to 10 possible reminders)
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(homeworkId.hashCode + i);
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notifications',
          'Instant Notifications',
          channelDescription: 'Quick notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // Study session ongoing notification (Android)
  Future<void> showStudyOngoing({required Duration remaining}) async {
    if (kIsWeb) return;
    try {
      await _notifications.show(
        _studyNotificationId,
        'Focus Session',
        _formatRemaining(remaining),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_session',
            'Study Session',
            channelDescription: 'Ongoing focus session status',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            category: AndroidNotificationCategory.progress,
            showWhen: false,
          ),
        ),
      );
    } catch (e) {
      print('❌ ERROR showing study ongoing notification: $e');
    }
  }

  Future<void> updateStudyOngoing({required Duration remaining}) async {
    if (kIsWeb) return;
    try {
      await _notifications.show(
        _studyNotificationId,
        'Focus Session',
        _formatRemaining(remaining),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_session',
            'Study Session',
            channelDescription: 'Ongoing focus session status',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            category: AndroidNotificationCategory.progress,
            showWhen: false,
          ),
        ),
      );
    } catch (e) {
      print('❌ ERROR updating study ongoing notification: $e');
    }
  }

  Future<void> stopStudyOngoing() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancel(_studyNotificationId);
    } catch (e) {
      print('❌ ERROR stopping study ongoing notification: $e');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final timeStr = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return 'Remaining: $timeStr';
  }
}
