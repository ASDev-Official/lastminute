import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceStatus { upcoming, ongoing }

class Maintenance {
  final String id;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final MaintenanceStatus status;

  Maintenance({
    required this.id,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool get isScheduled {
    return DateTime.now().isBefore(startTime);
  }

  factory Maintenance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final startTime = (data['startTime'] as Timestamp).toDate();
    final endTime = (data['endTime'] as Timestamp).toDate();

    // Determine status based on current time
    final now = DateTime.now();
    late MaintenanceStatus status;

    if (now.isAfter(endTime)) {
      // Maintenance already ended, don't show it
      status = MaintenanceStatus.upcoming;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      status = MaintenanceStatus.ongoing;
    } else {
      status = MaintenanceStatus.upcoming;
    }

    return Maintenance(
      id: doc.id,
      description: data['description'] ?? '',
      startTime: startTime,
      endTime: endTime,
      status: status,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
    };
  }
}
