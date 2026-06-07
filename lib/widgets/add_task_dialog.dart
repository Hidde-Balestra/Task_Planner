import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

enum _RepeatType { none, weekly, interval }

Color priorityColor(Priority p) => switch (p) {
      Priority.low => const Color(0xFF4CAF50),
      Priority.medium => const Color(0xFFFF9800),
      Priority.high => const Color(0xFFF44336),
    };

String priorityLabel(Priority p) => switch (p) {
      Priority.low => 'Low',
      Priority.medium => 'Medium',
      Priority.high => 'High',
    };

class AddTaskDialog extends StatefulWidget {
  final void Function(
    String title,
    List<int> repeatDays,
    Priority priority,
    int repeatIntervalDays,
    DateTime creationDate,
  ) onAdd;
  final String? initialTitle;
  final List<int>? initialDays;
  final Priority? initialPriority;
  final int? initialIntervalDays;
  final DateTime? initialDate;

  const AddTaskDialog({
    super.key,
    required this.onAdd,
    this.initialTitle,
    this.initialDays,
    this.initialPriority,
    this.initialIntervalDays,
    this.initialDate,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _intervalController;
  late Priority _priority;
  late _RepeatType _repeatType;
  late List<int> _selectedDays;
  late DateTime _date;

  static const _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _intervalPresets = [
    (7, '1 week'),
    (14, '2 weeks'),
    (30, '1 month'),
    (182, '6 months'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _priority = widget.initialPriority ?? Priority.low;
    _date = widget.initialDate ?? DateTime.now();

    final intervalDays = widget.initialIntervalDays ?? 0;
    if (intervalDays > 0) {
      _repeatType = _RepeatType.interval;
      _intervalController = TextEditingController(text: intervalDays.toString());
      _selectedDays = [];
    } else if ((widget.initialDays ?? []).isNotEmpty) {
      _repeatType = _RepeatType.weekly;
      _selectedDays = List<int>.from(widget.initialDays!);
      _intervalController = TextEditingController(text: '14');
    } else {
      _repeatType = _RepeatType.none;
      _selectedDays = [];
      _intervalController = TextEditingController(text: '14');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    final title = _titleController.text.trim();
    final repeatDays =
        _repeatType == _RepeatType.weekly ? _selectedDays : <int>[];
    final intervalDays = _repeatType == _RepeatType.interval
        ? (int.tryParse(_intervalController.text) ?? 0)
        : 0;
    widget.onAdd(title, repeatDays, _priority, intervalDays, _date);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialTitle != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
              autofocus: !isEdit,
            ),
            const SizedBox(height: 16),
            const Text('Priority', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: Priority.values.map((p) {
                final selected = _priority == p;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(priorityLabel(p)),
                    selected: selected,
                    selectedColor: priorityColor(p).withValues(alpha: 0.25),
                    avatar: CircleAvatar(
                      backgroundColor: priorityColor(p),
                      radius: 8,
                    ),
                    onSelected: (_) => setState(() => _priority = p),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Repeat', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            SegmentedButton<_RepeatType>(
              segments: const [
                ButtonSegment(
                  value: _RepeatType.none,
                  label: Text('Once'),
                ),
                ButtonSegment(
                  value: _RepeatType.weekly,
                  label: Text('Days'),
                ),
                ButtonSegment(
                  value: _RepeatType.interval,
                  label: Text('Interval'),
                ),
              ],
              selected: {_repeatType},
              onSelectionChanged: (val) =>
                  setState(() => _repeatType = val.first),
            ),
            const SizedBox(height: 12),
            if (_repeatType == _RepeatType.none) ...[
              Row(
                children: [
                  const Text('On date:'),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('EEE, MMM d').format(_date)),
                  ),
                ],
              ),
            ] else if (_repeatType == _RepeatType.weekly) ...[
              Wrap(
                spacing: 5,
                children: List.generate(7, (i) {
                  final sel = _selectedDays.contains(i);
                  return ChoiceChip(
                    label: Text(_weekDays[i]),
                    selected: sel,
                    onSelected: (val) => setState(() {
                      if (val) {
                        _selectedDays.add(i);
                      } else {
                        _selectedDays.remove(i);
                      }
                    }),
                  );
                }),
              ),
            ] else ...[
              Row(
                children: [
                  const Text('Every'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _intervalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('days'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: _intervalPresets.map((preset) {
                  final (days, label) = preset;
                  return ActionChip(
                    label: Text(label),
                    onPressed: () => setState(
                      () => _intervalController.text = days.toString(),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Starting:'),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('EEE, MMM d').format(_date)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
