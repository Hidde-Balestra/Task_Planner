import 'package:flutter/material.dart';

import '../models/task.dart';

Color _priorityColor(Priority p) => switch (p) {
      Priority.low => const Color(0xFF4CAF50),
      Priority.medium => const Color(0xFFFF9800),
      Priority.high => const Color(0xFFF44336),
    };

class TaskTile extends StatelessWidget {
  final Task task;
  final DateTime date;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final Future<bool?> Function()? onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.date,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = task.isCompleted(date);

    return Dismissible(
      key: Key(task.id),
      confirmDismiss: (direction) async => onDelete?.call(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
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
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Checkbox(
          value: completed,
          onChanged: (_) => onToggle(),
        ),
        onLongPress: onEdit,
      ),
    );
  }
}
