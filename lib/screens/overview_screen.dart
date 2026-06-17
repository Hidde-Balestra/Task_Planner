import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../services/widget_service.dart';

class _TaskOccurrence {
  final Task task;
  final DateTime date;
  const _TaskOccurrence({required this.task, required this.date});
}

Color _priorityColor(Priority p) => switch (p) {
      Priority.low => const Color(0xFF4CAF50),
      Priority.medium => const Color(0xFFFF9800),
      Priority.high => const Color(0xFFF44336),
    };

class OverviewScreen extends StatelessWidget {
  final List<Task> tasks;

  const OverviewScreen({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final pending = _buildPending();
    final completed = _buildCompleted();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overzicht'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Openstaand (${pending.length})'),
              Tab(text: 'Voltooid (${completed.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PendingTab(occurrences: pending),
            _CompletedTab(occurrences: completed),
          ],
        ),
      ),
    );
  }

  List<_TaskOccurrence> _buildPending() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final result = <_TaskOccurrence>[];
    final addedOneTime = <String>{};

    // Overdue one-time tasks: scan past 90 days
    for (int i = 1; i <= 90; i++) {
      final pastDate = todayDate.subtract(Duration(days: i));
      final dayTasks = WidgetService.filterTasksForDate(tasks, pastDate)
          .where((t) => t.repeatDays.isEmpty && t.repeatIntervalDays == 0);
      for (final t in dayTasks) {
        if (!t.isCompleted(pastDate) && !addedOneTime.contains(t.id)) {
          addedOneTime.add(t.id);
          result.add(_TaskOccurrence(task: t, date: pastDate));
        }
      }
    }

    // Today's pending tasks
    final todayTasks = WidgetService.filterTasksForDate(tasks, todayDate)
        .where((t) => !t.isCompleted(todayDate));
    for (final t in todayTasks) {
      if (!addedOneTime.contains(t.id)) {
        result.add(_TaskOccurrence(task: t, date: todayDate));
      }
    }

    // Upcoming 14 days
    for (int i = 1; i <= 14; i++) {
      final futureDate = todayDate.add(Duration(days: i));
      final dayTasks = WidgetService.filterTasksForDate(tasks, futureDate);
      for (final t in dayTasks) {
        result.add(_TaskOccurrence(task: t, date: futureDate));
      }
    }

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<_TaskOccurrence> _buildCompleted() {
    final result = <_TaskOccurrence>[];
    for (final task in tasks) {
      task.completedByDate.forEach((key, done) {
        if (!done) return;
        // Parse date key "YYYY-M-D"
        final parts = key.split('-');
        if (parts.length != 3) return;
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year == null || month == null || day == null) return;
        result.add(_TaskOccurrence(
          task: task,
          date: DateTime(year, month, day),
        ));
      });
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }
}

class _PendingTab extends StatelessWidget {
  final List<_TaskOccurrence> occurrences;

  const _PendingTab({required this.occurrences});

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return const Center(child: Text('Geen openstaande taken'));
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    String groupLabel(_TaskOccurrence o) {
      if (o.date.isBefore(todayDate)) return 'Verlopen';
      if (o.date.isAtSameMomentAs(todayDate)) return 'Vandaag';
      return 'Aankomend';
    }

    final grouped = <String, List<_TaskOccurrence>>{};
    for (final o in occurrences) {
      final label = groupLabel(o);
      grouped.putIfAbsent(label, () => []).add(o);
    }

    final sectionOrder = ['Verlopen', 'Vandaag', 'Aankomend'];

    return ListView(
      children: [
        for (final section in sectionOrder)
          if (grouped.containsKey(section)) ...[
            _SectionHeader(title: section),
            for (final o in grouped[section]!)
              _OccurrenceTile(occurrence: o, showDate: section != 'Vandaag'),
          ],
      ],
    );
  }
}

class _CompletedTab extends StatelessWidget {
  final List<_TaskOccurrence> occurrences;

  const _CompletedTab({required this.occurrences});

  @override
  Widget build(BuildContext context) {
    if (occurrences.isEmpty) {
      return const Center(child: Text('Nog geen voltooide taken'));
    }

    // Group by date
    final grouped = <String, List<_TaskOccurrence>>{};
    for (final o in occurrences) {
      final key = DateFormat('E, MMM d y').format(o.date);
      grouped.putIfAbsent(key, () => []).add(o);
    }

    return ListView(
      children: [
        for (final entry in grouped.entries) ...[
          _SectionHeader(title: entry.key),
          for (final o in entry.value) _OccurrenceTile(occurrence: o, showDate: false),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  final _TaskOccurrence occurrence;
  final bool showDate;

  const _OccurrenceTile({required this.occurrence, required this.showDate});

  @override
  Widget build(BuildContext context) {
    final task = occurrence.task;
    final completed = task.isCompleted(occurrence.date);

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _priorityColor(task.priority),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: completed ? TextDecoration.lineThrough : null,
          decorationThickness: 2.0,
          color: completed
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: showDate
          ? Text(DateFormat('E, MMM d').format(occurrence.date))
          : null,
      trailing: completed
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : null,
    );
  }
}
