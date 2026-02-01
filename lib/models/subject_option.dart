import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectOption {
  final String id;
  final String userId;
  final String name;
  final String? color;
  final DateTime createdAt;

  const SubjectOption({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
    required this.createdAt,
  });

  factory SubjectOption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectOption(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      color: data['color'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SubjectOption copyWith({
    String? id,
    String? userId,
    String? name,
    String? color,
    DateTime? createdAt,
  }) {
    return SubjectOption(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
