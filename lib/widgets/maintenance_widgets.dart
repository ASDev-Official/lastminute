import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/maintenance.dart';

/// Full-screen notice for scheduled maintenance - dismissible with OK button
class ScheduledMaintenanceScreen extends StatelessWidget {
  const ScheduledMaintenanceScreen({
    super.key,
    required this.maintenance,
    required this.onDismiss,
  });

  final Maintenance maintenance;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Maintenance'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 50,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Maintenance Scheduled',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  maintenance.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start Time',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDateTime(maintenance.startTime),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'End Time',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDateTime(maintenance.endTime),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Duration',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDuration(
                              maintenance.endTime.difference(
                                maintenance.startTime,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.tonal(
                  onPressed: onDismiss,
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    return formatter.format(dateTime.toLocal());
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    } else if (minutes == 0) {
      return '$hours hour${hours != 1 ? 's' : ''}';
    } else {
      return '$hours hour${hours != 1 ? 's' : ''} $minutes minute${minutes != 1 ? 's' : ''}';
    }
  }
}

/// Dialog shown for scheduled maintenance - dismissible with OK button
class ScheduledMaintenanceDialog extends StatelessWidget {
  const ScheduledMaintenanceDialog({super.key, required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Text('Scheduled Maintenance'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              maintenance.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _InfoRow(
              label: 'Start Time',
              value: _formatDateTime(maintenance.startTime),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'End Time',
              value: _formatDateTime(maintenance.endTime),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Duration',
              value: _formatDuration(
                maintenance.endTime.difference(maintenance.startTime),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    return formatter.format(dateTime.toLocal());
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    } else if (minutes == 0) {
      return '$hours hour${hours != 1 ? 's' : ''}';
    } else {
      return '$hours hour${hours != 1 ? 's' : ''} $minutes minute${minutes != 1 ? 's' : ''}';
    }
  }
}

/// Full-screen notice for ongoing maintenance
class OngoingMaintenanceScreen extends StatelessWidget {
  const OngoingMaintenanceScreen({super.key, required this.maintenance});

  final Maintenance maintenance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Maintenance'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.construction,
                    size: 50,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Maintenance in Progress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  maintenance.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Start Time',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDateTime(maintenance.startTime),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'End Time',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDateTime(maintenance.endTime),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Duration',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _formatDuration(
                              maintenance.endTime.difference(
                                maintenance.startTime,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'The app is in read-only mode during maintenance. Your data is safe.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM dd, yyyy • h:mm a');
    return formatter.format(dateTime.toLocal());
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    } else if (minutes == 0) {
      return '$hours hour${hours != 1 ? 's' : ''}';
    } else {
      return '$hours hour${hours != 1 ? 's' : ''} $minutes minute${minutes != 1 ? 's' : ''}';
    }
  }
}

/// Top banner for ongoing maintenance - clickable to open full notice
class MaintenanceBanner extends StatelessWidget {
  const MaintenanceBanner({
    super.key,
    required this.maintenance,
    required this.onTap,
  });

  final Maintenance maintenance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.construction,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Maintenance in Progress',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  Text(
                    'Tap to view details',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
