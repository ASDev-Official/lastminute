import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/homework.dart';
import '../models/subject_option.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'subjects_screen.dart';

class HomeworkDetailScreen extends StatefulWidget {
  const HomeworkDetailScreen({super.key, this.homework});

  final Homework? homework;

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedSubject;

  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  Priority _priority = Priority.medium;
  final List<DateTime> _reminders = [];

  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.homework != null) {
      _titleController.text = widget.homework!.title;
      _descriptionController.text = widget.homework!.description ?? '';
      _selectedSubject = widget.homework!.subject;
      _dueDate = widget.homework!.dueDate;
      _dueTime = TimeOfDay.fromDateTime(widget.homework!.dueDate);
      _priority = widget.homework!.priority;
      _reminders.addAll(widget.homework!.reminderTimes);
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 1));
      _dueTime = const TimeOfDay(hour: 23, minute: 59);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final combinedDueDate = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );

    var homework = Homework(
      id: widget.homework?.id ?? '',
      userId: FirebaseAuth.instance.currentUser!.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      subject: _selectedSubject?.trim().isEmpty == true
          ? null
          : _selectedSubject?.trim(),
      dueDate: combinedDueDate,
      priority: _priority,
      isCompleted: widget.homework?.isCompleted ?? false,
      createdAt: widget.homework?.createdAt ?? DateTime.now(),
      completedAt: widget.homework?.completedAt,
      reminderTimes: _reminders,
    );

    try {
      String homeworkId;
      if (widget.homework == null) {
        // Create new homework and get the ID
        homeworkId = await _firestoreService.createHomework(homework);
        // Update homework with the real ID from Firestore
        homework = Homework(
          id: homeworkId,
          userId: homework.userId,
          title: homework.title,
          description: homework.description,
          subject: homework.subject,
          dueDate: homework.dueDate,
          priority: homework.priority,
          isCompleted: homework.isCompleted,
          createdAt: homework.createdAt,
          completedAt: homework.completedAt,
          reminderTimes: homework.reminderTimes,
        );
      } else {
        await _firestoreService.updateHomework(homework);
        await _notificationService.cancelHomeworkReminders(homework.id);
      }

      // Schedule notifications with the correct homework ID
      await _notificationService.scheduleHomeworkReminder(homework);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.homework == null
                  ? 'Homework added successfully'
                  : 'Homework updated successfully',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ ERROR saving homework: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.homework != null) {
      await _firestoreService.deleteHomework(widget.homework!.id);
      await _notificationService.cancelHomeworkReminders(widget.homework!.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Homework deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.homework == null ? 'Add Homework' : 'Edit Homework'),
        actions: [
          if (widget.homework != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
              color: colorScheme.error,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Math homework, Chapter 5',
                prefixIcon: const Icon(Icons.title_rounded),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            // Subject Dropdown
            StreamBuilder<List<SubjectOption>>(
              stream: _firestoreService.getSubjectOptionsStream(),
              builder: (context, snapshot) {
                final subjects = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      decoration: InputDecoration(
                        labelText: 'Subject (optional)',
                        hintText: 'Select or create a subject',
                        prefixIcon: const Icon(Icons.book_outlined),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                      ),
                      items: [
                        ...subjects.map((subject) {
                          return DropdownMenuItem(
                            value: subject.name,
                            child: Text(subject.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSubject = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubjectsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Manage Subjects'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Additional details about this homework',
                prefixIcon: const Icon(Icons.description_outlined),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            // Due Date and Time
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Due Date & Time',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() => _dueDate = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(DateFormat.yMMMd().format(_dueDate)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _dueTime,
                              );
                              if (time != null) {
                                setState(() => _dueTime = time);
                              }
                            },
                            icon: const Icon(Icons.access_time_rounded),
                            label: Text(_dueTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Priority
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag_rounded, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Priority',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<Priority>(
                        selected: {_priority},
                        onSelectionChanged: (Set<Priority> newSelection) {
                          setState(() => _priority = newSelection.first);
                        },
                        segments: const [
                          ButtonSegment(
                            value: Priority.low,
                            label: Text('Low'),
                            icon: Icon(Icons.flag_outlined),
                          ),
                          ButtonSegment(
                            value: Priority.medium,
                            label: Text('Medium'),
                          ),
                          ButtonSegment(
                            value: Priority.high,
                            label: Text('High'),
                          ),
                          ButtonSegment(
                            value: Priority.urgent,
                            label: Text('Urgent'),
                            icon: Icon(Icons.priority_high_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reminders
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reminders',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addReminder,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_reminders.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'No reminders set',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else
                      ..._reminders.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reminder = entry.value;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.alarm_rounded),
                          title: Text(
                            DateFormat.yMMMd().add_jm().format(reminder),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() => _reminders.removeAt(index));
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.homework == null ? 'Add Homework' : 'Save Changes',
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addReminder() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate.subtract(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: _dueDate,
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(date),
      );

      if (time != null) {
        final reminderTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        if (reminderTime.isAfter(DateTime.now())) {
          setState(() => _reminders.add(reminderTime));
        }
      }
    }
  }
}
