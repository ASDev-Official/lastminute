import 'package:flutter/material.dart';

import '../models/homework.dart';
import '../services/firestore_service.dart';
import '../widgets/homework_card.dart';
import '../widgets/stats_card.dart';

class DesktopHomePane extends StatelessWidget {
  const DesktopHomePane({
    super.key,
    required this.greetingName,
    required this.firestoreService,
    required this.overdue,
    required this.upcoming,
    required this.completed,
    required this.allHomework,
    required this.onAddHomework,
    required this.onOpenCalendar,
  });

  final String? greetingName;
  final FirestoreService firestoreService;
  final List<Homework> overdue;
  final List<Homework> upcoming;
  final List<Homework> completed;
  final List<Homework> allHomework;
  final VoidCallback onAddHomework;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Overview pane
        SizedBox(
          width: 380,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hello, ${greetingName ?? 'there'}! 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Because deadlines always sneak up. Here\'s your homework overview:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              StatsCard(firestoreService: firestoreService),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: onAddHomework,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Homework'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onOpenCalendar,
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: const Text('Open Calendar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: Tasks pane
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overdue (${overdue.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...overdue.map((hw) => HomeworkCard(homework: hw)),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                Text(
                  'Upcoming (${upcoming.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...upcoming.map((hw) => HomeworkCard(homework: hw)),
                const SizedBox(height: 16),
              ],
              if (completed.isNotEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.7),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        'Completed (${completed.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: [
                        ...completed.map(
                          (hw) => Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: HomeworkCard(homework: hw),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (allHomework.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt_rounded,
                        size: 80,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No homework yet!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the Add Homework button to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
