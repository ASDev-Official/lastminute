import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/homework.dart';
import '../models/subject_option.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  CollectionReference get _homeworkCollection =>
      _firestore.collection('homework');

  CollectionReference get _subjectOptionsCollection =>
      _firestore.collection('subjectOptions');

  // Create
  Future<String> createHomework(Homework homework) async {
    try {
      final doc = await _homeworkCollection.add(homework.toFirestore());
      return doc.id;
    } catch (e, stackTrace) {
      print('❌ ERROR creating homework: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Read - stream all homework for current user
  Stream<List<Homework>> getHomeworkStream() {
    return _homeworkCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Homework.fromFirestore(doc)).toList(),
        );
  }

  // Read - get homework by date range
  Stream<List<Homework>> getHomeworkByDateRange(DateTime start, DateTime end) {
    return _homeworkCollection
        .where('userId', isEqualTo: _userId)
        .where('dueDate', isGreaterThanOrEqualTo: start)
        .where('dueDate', isLessThanOrEqualTo: end)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Homework.fromFirestore(doc)).toList(),
        );
  }

  // Read - get incomplete homework
  Stream<List<Homework>> getIncompleteHomework() {
    return _homeworkCollection
        .where('userId', isEqualTo: _userId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Homework.fromFirestore(doc)).toList(),
        );
  }

  // Update
  Future<void> updateHomework(Homework homework) async {
    try {
      await _homeworkCollection.doc(homework.id).update(homework.toFirestore());
    } catch (e, stackTrace) {
      print('❌ ERROR updating homework: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Delete
  Future<void> deleteHomework(String homeworkId) async {
    try {
      await _homeworkCollection.doc(homeworkId).delete();
    } catch (e, stackTrace) {
      print('❌ ERROR deleting homework: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Toggle completion
  Future<void> toggleCompletion(String homeworkId, bool isCompleted) async {
    try {
      await _homeworkCollection.doc(homeworkId).update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? Timestamp.now() : null,
      });
    } catch (e, stackTrace) {
      print('❌ ERROR toggling homework completion: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get stats
  Future<Map<String, int>> getStats() async {
    final snapshot = await _homeworkCollection
        .where('userId', isEqualTo: _userId)
        .get();

    int total = snapshot.docs.length;
    int completed = 0;
    int overdue = 0;
    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      final homework = Homework.fromFirestore(doc);
      if (homework.isCompleted) {
        completed++;
      } else if (homework.dueDate.isBefore(now)) {
        overdue++;
      }
    }

    return {
      'total': total,
      'completed': completed,
      'overdue': overdue,
      'pending': total - completed - overdue,
    };
  }

  // Subject Options Methods

  // Create subject option
  Future<String> createSubjectOption(SubjectOption option) async {
    try {
      // Update the option with current user's ID before saving
      final updatedOption = option.copyWith(userId: _userId);
      final doc = await _subjectOptionsCollection.add(
        updatedOption.toFirestore(),
      );
      return doc.id;
    } catch (e, stackTrace) {
      print('❌ ERROR creating subject option: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get subject options stream
  Stream<List<SubjectOption>> getSubjectOptionsStream() {
    return _subjectOptionsCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SubjectOption.fromFirestore(doc))
              .toList(),
        );
  }

  // Get all subject options (one-time fetch)
  Future<List<SubjectOption>> getSubjectOptions() async {
    try {
      final snapshot = await _subjectOptionsCollection
          .where('userId', isEqualTo: _userId)
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) => SubjectOption.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      print('❌ ERROR fetching subject options: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Update subject option
  Future<void> updateSubjectOption(SubjectOption option) async {
    try {
      await _subjectOptionsCollection
          .doc(option.id)
          .update(option.toFirestore());
    } catch (e, stackTrace) {
      print('❌ ERROR updating subject option: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Delete subject option
  Future<void> deleteSubjectOption(String optionId) async {
    try {
      await _subjectOptionsCollection.doc(optionId).delete();
    } catch (e, stackTrace) {
      print('❌ ERROR deleting subject option: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Migration: Get all unique subjects from homework
  Future<Set<String>> getAllUniqueSubjects() async {
    try {
      final snapshot = await _homeworkCollection
          .where('userId', isEqualTo: _userId)
          .get();
      final subjects = <String>{};
      for (var doc in snapshot.docs) {
        final homework = Homework.fromFirestore(doc);
        if (homework.subject != null && homework.subject!.isNotEmpty) {
          subjects.add(homework.subject!);
        }
      }
      return subjects;
    } catch (e, stackTrace) {
      print('❌ ERROR getting unique subjects: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Migration: Convert existing subjects to subject options
  Future<void> migrateSubjectsToOptions() async {
    try {
      print('🔄 Starting subject migration...');

      // Check if migration has already been done
      final existingOptions = await getSubjectOptions();
      if (existingOptions.isNotEmpty) {
        print('✅ Subject options already exist, skipping migration');
        return;
      }

      // Get all unique subjects
      final uniqueSubjects = await getAllUniqueSubjects();
      if (uniqueSubjects.isEmpty) {
        print('✅ No subjects to migrate');
        return;
      }

      print('📦 Found ${uniqueSubjects.length} unique subjects to migrate');

      // Create subject options for each unique subject
      for (var subject in uniqueSubjects) {
        final option = SubjectOption(
          id: '', // Will be set by Firestore
          userId: _userId,
          name: subject,
          color: null,
          createdAt: DateTime.now(),
        );
        await createSubjectOption(option);
        print('✅ Migrated subject: $subject');
      }

      print('✅ Subject migration completed');
    } catch (e, stackTrace) {
      print('❌ ERROR migrating subjects: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }
}
