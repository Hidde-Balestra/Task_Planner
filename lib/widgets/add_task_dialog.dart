import 'package:flutter/material.dart';

class AddTaskDialog extends StatefulWidget {
  final Function(String title, List<int> repeatDays) onAdd;
  final String? initialTitle;
  final List<int>? initialDays;

  const AddTaskDialog({
    super.key,
    required this.onAdd,
    this.initialTitle,
    this.initialDays,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late TextEditingController _controller;
  List<int> selectedDays = [];

  final List<String> weekDays = [ 'Sun','Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle ?? '');
    selectedDays = widget.initialDays ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTitle == null ? 'Add Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 10),
            const Text('Repeat on:'),
            Wrap(
              spacing: 5,
              children: List.generate(7, (index) {
                bool selected = selectedDays.contains(index);
                return ChoiceChip(
                  label: Text(weekDays[index]),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedDays.add(index);
                      } else {
                        selectedDays.remove(index);
                      }
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isEmpty) return;
            widget.onAdd(_controller.text.trim(), selectedDays);
            Navigator.pop(context);
          },
          child: Text(widget.initialTitle == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
