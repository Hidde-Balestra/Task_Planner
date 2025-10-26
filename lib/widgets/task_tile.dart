import 'package:flutter/material.dart';
import '../models/task.dart';

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
      key: Key(task.title + task.hashCode.toString()),
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
