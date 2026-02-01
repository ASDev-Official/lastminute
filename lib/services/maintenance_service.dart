import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/maintenance.dart';

class MaintenanceService {
  static final MaintenanceService _instance = MaintenanceService._internal();
  factory MaintenanceService() => _instance;
  MaintenanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current active maintenance (either scheduled or ongoing)
  /// Returns null if there's no active maintenance
  Future<Maintenance?> getActiveMaintenance() async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('maintenance')
          .where('endTime', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('endTime')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return Maintenance.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('Error fetching maintenance: $e');
      return null;
    }
  }

  /// Stream of active maintenance status
  Stream<Maintenance?> getMaintenanceStream() {
    return _firestore
        .collection('maintenance')
        .where('endTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('endTime')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return Maintenance.fromFirestore(snapshot.docs.first);
        });
  }

  /// Create a new maintenance record (admin only)
  Future<void> createMaintenance({
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _firestore.collection('maintenance').add({
        'description': description,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
      });
    } catch (e) {
      print('Error creating maintenance: $e');
      rethrow;
    }
  }
}
