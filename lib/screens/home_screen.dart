import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/task_storage.dart';
import '../services/backup_service.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/task_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> tasks = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadLastDate();
  }

  Future<void> _loadTasks() async {
    final loadedTasks = await TaskStorage.loadTasks();
    setState(() => tasks = loadedTasks);
  }

  Future<void> _saveTasks() async {
    await TaskStorage.saveTasks(tasks);
  }

  Future<void> _loadLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateString = prefs.getString('lastDate');
    if (lastDateString != null) {
      setState(() {
        selectedDate = DateTime.parse(lastDateString);
      });
    }
  }

  Future<void> _saveLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastDate', selectedDate.toIso8601String());
  }

  void _addTask(String title, List<int> repeatDays) {
    setState(() {
      tasks.add(Task(title: title, repeatDays: repeatDays));
    });
    TaskStorage.saveTasks(tasks);
  }


  void _toggleTask(Task task) {
    setState(() {
      task.toggleCompletion(selectedDate);
    });
    _saveTasks();
  }

  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AddTaskDialog(
        initialTitle: task.title,
        initialDays: task.repeatDays,
        onAdd: (title, repeatDays) {
          setState(() {
            task.title = title;
            task.repeatDays = repeatDays;
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

  List<Task> get _filteredTasks {
    int today = selectedDate.weekday % 7;

    return tasks.where((task) {
      final creation = task.creationDate;

      if (task.repeatDays.isEmpty) {
        return creation.year == selectedDate.year &&
            creation.month == selectedDate.month &&
            creation.day == selectedDate.day;
      }

      return task.repeatDays.contains(today);
    }).toList();
  }


  Future<void> _handleMenuAction(String value) async {
    if (value == 'backup') {
      final path = await BackupService.backup(tasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved: $path')),
      );
    } else if (value == 'restore') {
      final restored = await BackupService.restore();
      if (restored != null) {
        setState(() => tasks = restored);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
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
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDay(-1),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(formattedDate, style: const TextStyle(fontSize: 16)),
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
                _saveTasks();
              }
              return confirm;
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AddTaskDialog(onAdd: _addTask),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
