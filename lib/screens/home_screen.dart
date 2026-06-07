import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../services/backup_service.dart';
import '../services/task_storage.dart';
import '../services/widget_service.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Task> tasks = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _loadLastDate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadFromDisk();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  Future<void> _reloadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      await _loadTasks();
    } catch (e) {
      debugPrint('Reload from disk failed: $e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final loadedTasks = await TaskStorage.loadTasks();
      if (mounted) {
        setState(() => tasks = loadedTasks);
      }
      await WidgetService.updateWidget(loadedTasks, DateTime.now());
    } catch (e) {
      debugPrint('Failed to load tasks: $e');
    }
  }

  Future<void> _saveTasks() async {
    await TaskStorage.saveTasks(tasks);
    await WidgetService.updateWidget(tasks, DateTime.now());
  }

  Future<void> _loadLastDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDateString = prefs.getString('lastDate');
      if (lastDateString != null) {
        final parsed = DateTime.tryParse(lastDateString);
        if (parsed != null && mounted) {
          setState(() => selectedDate = parsed);
        }
      }
    } catch (e) {
      debugPrint('Failed to load last date: $e');
    }
  }

  Future<void> _saveLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDate', selectedDate.toIso8601String());
  }

  Future<void> _addTask(
    String title,
    List<int> repeatDays,
    Priority priority,
    int repeatIntervalDays,
    DateTime creationDate,
  ) async {
    setState(() {
      tasks.add(Task(
        title: title,
        repeatDays: repeatDays,
        priority: priority,
        repeatIntervalDays: repeatIntervalDays,
        creationDate: creationDate,
      ));
    });
    await _saveTasks();
  }

  Future<void> _toggleTask(Task task) async {
    setState(() {
      task.toggleCompletion(selectedDate);
    });
    await _saveTasks();
  }

  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AddTaskDialog(
        initialTitle: task.title,
        initialDays: task.repeatDays,
        initialPriority: task.priority,
        initialIntervalDays: task.repeatIntervalDays,
        initialDate: task.creationDate,
        onAdd: (title, repeatDays, priority, intervalDays, creationDate) {
          setState(() {
            task.title = title;
            task.repeatDays = repeatDays;
            task.priority = priority;
            task.repeatIntervalDays = intervalDays;
            task.creationDate = creationDate;
          });
          _saveTasks();
        },
      ),
    );
  }

  Future<bool?> _confirmDelete() async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _changeDay(int offset) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: offset));
    });
    _saveLastDate();
  }

  void _goToToday() {
    setState(() => selectedDate = DateTime.now());
    _saveLastDate();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _saveLastDate();
    }
  }

  List<Task> get _filteredTasks =>
      WidgetService.filterTasksForDate(tasks, selectedDate);

  Future<void> _handleMenuAction(String value) async {
    if (value == 'backup') {
      try {
        final path = await BackupService.backup(tasks);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup opgeslagen: $path')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup mislukt')),
        );
      }
    } else if (value == 'restore') {
      try {
        final restored = await BackupService.restore();
        if (!mounted) return;
        if (restored != null) {
          setState(() => tasks = restored);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup hersteld')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geen backupbestand gevonden')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Herstellen mislukt')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('E, MMM d').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Planner'),
        actions: [
          if (!_isToday)
            TextButton(
              onPressed: _goToToday,
              child: const Text('Today'),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDay(-1),
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                formattedDate,
                style: const TextStyle(fontSize: 16, decoration: TextDecoration.underline),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDay(1),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'backup', child: Text('Backup Tasks')),
              PopupMenuItem(value: 'restore', child: Text('Restore Tasks')),
            ],
          ),
        ],
      ),
      body: _filteredTasks.isEmpty
          ? const Center(child: Text('No tasks for this day'))
          : ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return TaskTile(
                  task: task,
                  date: selectedDate,
                  onToggle: () => _toggleTask(task),
                  onEdit: () => _editTask(task),
                  onDelete: () async {
                    final confirm = await _confirmDelete();
                    if (confirm == true) {
                      setState(() {
                        tasks.remove(task);
                      });
                      await _saveTasks();
                    }
                    return confirm;
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AddTaskDialog(
            initialDate: selectedDate,
            onAdd: _addTask,
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
