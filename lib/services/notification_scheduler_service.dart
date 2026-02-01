import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/homework.dart';
import 'notification_service.dart';

class NotificationSchedulerService {
  static final NotificationSchedulerService _instance =
      NotificationSchedulerService._internal();
  factory NotificationSchedulerService() => _instance;
  NotificationSchedulerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  bool _isListening = false;
  StreamSubscription? _homeworkListener;

  String get _userId => _auth.currentUser!.uid;

  /// Start listening to homework changes and automatically schedule reminders
  Future<void> startWatchingHomework() async {
    if (_isListening) {
      print('ℹ️ Already listening to homework changes');
      return;
    }

    try {
      print('🔔 Starting homework listener...');
      _isListening = true;

      _homeworkListener = _firestore
          .collection('homework')
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .listen(
            (snapshot) async {
              print(
                '📦 Homework snapshot received with ${snapshot.docs.length} items',
              );

              // Process each homework document
              for (var doc in snapshot.docs) {
                try {
                  final homework = Homework.fromFirestore(doc);

                  // Only schedule if there are reminders set
                  if (homework.reminderTimes.isNotEmpty) {
                    print(
                      '📅 Found homework with ${homework.reminderTimes.length} reminder(s): ${homework.title}',
                    );
                    await _notificationService.scheduleHomeworkReminder(
                      homework,
                    );
                  }
                } catch (e) {
                  print('⚠️ Error processing homework document: $e');
                }
              }
            },
            onError: (error) {
              print('❌ ERROR listening to homework changes: $error');
            },
          );

      print('✅ Homework listener started successfully');
    } catch (e, stackTrace) {
      print('❌ ERROR starting homework listener: $e');
      print('📋 Stack trace: $stackTrace');
      _isListening = false;
    }
  }

  /// Stop listening to homework changes
  Future<void> stopWatchingHomework() async {
    try {
      await _homeworkListener?.cancel();
      _isListening = false;
      print('✅ Homework listener stopped');
    } catch (e) {
      print('❌ ERROR stopping homework listener: $e');
    }
  }

  /// Check and schedule reminders for all homework (for background sync)
  /// This can be called periodically or on app launch
  Future<void> syncRemindersForAllHomework() async {
    try {
      print('🔄 Syncing reminders for all homework...');

      final snapshot = await _firestore
          .collection('homework')
          .where('userId', isEqualTo: _userId)
          .get();

      print('📦 Found ${snapshot.docs.length} homework items');

      int scheduledCount = 0;
      for (var doc in snapshot.docs) {
        try {
          final homework = Homework.fromFirestore(doc);

          if (homework.reminderTimes.isNotEmpty) {
            await _notificationService.scheduleHomeworkReminder(homework);
            scheduledCount++;
          }
        } catch (e) {
          print('⚠️ Error processing homework: $e');
        }
      }

      print('✅ Synced reminders for $scheduledCount homework items');
    } catch (e, stackTrace) {
      print('❌ ERROR syncing reminders: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  /// Check and schedule reminders for a specific homework
  Future<void> syncRemindersForHomework(Homework homework) async {
    try {
      if (homework.reminderTimes.isEmpty) {
        print('ℹ️ No reminders to schedule for ${homework.title}');
        return;
      }

      print('📅 Syncing reminders for: ${homework.title}');
      await _notificationService.scheduleHomeworkReminder(homework);
      print('✅ Reminders synced for ${homework.title}');
    } catch (e, stackTrace) {
      print('❌ ERROR syncing homework reminders: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  /// Check for any upcoming reminders and ensure they're scheduled (called periodically)
  /// This handles cases where the app was closed and reminders weren't scheduled
  Future<void> ensureUpcomingRemindersScheduled() async {
    try {
      print('🔍 Checking for upcoming reminders...');

      final now = DateTime.now();
      final nextDay = now.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('homework')
          .where('userId', isEqualTo: _userId)
          .where('isCompleted', isEqualTo: false)
          .get();

      int checkedCount = 0;
      for (var doc in snapshot.docs) {
        try {
          final homework = Homework.fromFirestore(doc);

          // Check if any reminders are in the near future
          final hasUpcomingReminders = homework.reminderTimes.any(
            (reminder) =>
                reminder.isAfter(now) &&
                reminder.isBefore(nextDay.add(const Duration(hours: 1))),
          );

          if (hasUpcomingReminders) {
            await _notificationService.scheduleHomeworkReminder(homework);
            checkedCount++;
          }
        } catch (e) {
          print('⚠️ Error checking homework: $e');
        }
      }

      print('✅ Ensured reminders for $checkedCount upcoming tasks');
    } catch (e, stackTrace) {
      print('❌ ERROR ensuring upcoming reminders: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }
}
