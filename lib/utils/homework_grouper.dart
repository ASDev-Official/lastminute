import '../models/homework.dart';

enum DeadlineGroup { under7days, under14days, under30days, above30days }

extension DeadlineGroupExtension on DeadlineGroup {
  String get label {
    switch (this) {
      case DeadlineGroup.under7days:
        return 'Due in 7 days or less';
      case DeadlineGroup.under14days:
        return 'Due in 7-14 days';
      case DeadlineGroup.under30days:
        return 'Due in 14-30 days';
      case DeadlineGroup.above30days:
        return 'Due in more than 30 days';
    }
  }

  String get iconName {
    switch (this) {
      case DeadlineGroup.under7days:
        return 'urgent';
      case DeadlineGroup.under14days:
        return 'soon';
      case DeadlineGroup.under30days:
        return 'upcoming';
      case DeadlineGroup.above30days:
        return 'later';
    }
  }
}

class HomeworkGrouper {
  static Map<DeadlineGroup, List<Homework>> groupByDeadline(
    List<Homework> homework,
  ) {
    final now = DateTime.now();
    final groups = <DeadlineGroup, List<Homework>>{
      DeadlineGroup.under7days: [],
      DeadlineGroup.under14days: [],
      DeadlineGroup.under30days: [],
      DeadlineGroup.above30days: [],
    };

    for (final hw in homework) {
      if (hw.isCompleted) continue;

      final daysUntilDue = hw.dueDate.difference(now).inDays;

      if (daysUntilDue < 7) {
        groups[DeadlineGroup.under7days]!.add(hw);
      } else if (daysUntilDue < 14) {
        groups[DeadlineGroup.under14days]!.add(hw);
      } else if (daysUntilDue < 30) {
        groups[DeadlineGroup.under30days]!.add(hw);
      } else {
        groups[DeadlineGroup.above30days]!.add(hw);
      }
    }

    // Sort each group by due date
    for (final group in groups.values) {
      group.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    }

    return groups;
  }

  static List<Homework> filterBySubject(
    List<Homework> homework,
    String? subject,
  ) {
    if (subject == null || subject.isEmpty) {
      return homework;
    }
    return homework.where((hw) => hw.subject == subject).toList();
  }

  static List<String> getUniqueSubjects(List<Homework> homework) {
    final subjects = <String>{};
    for (final hw in homework) {
      if (hw.subject != null && hw.subject!.isNotEmpty) {
        subjects.add(hw.subject!);
      }
    }
    return subjects.toList()..sort();
  }
}
