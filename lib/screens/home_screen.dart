import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
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
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _loadLastDate();
    _widgetClickSub = HomeWidget.widgetClicked.listen(_onWidgetClicked);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadFromDisk();
    }
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

  Future<void> _onWidgetClicked(Uri? uri) async {
    // Widget toggles are handled by Kotlin's TaskToggleReceiver.
    // Reload tasks so the app reflects any changes made via the widget.
    await _reloadFromDisk();
  }

  Future<void> _loadTasks() async {
    try {
      final loadedTasks = await TaskStorage.loadTasks();
      if (mounted) {
        setState(() => tasks = loadedTasks);
        await WidgetService.updateWidget(tasks, selectedDate);
      }
    } catch (e) {
      debugPrint('Failed to load tasks: $e');
    }
  }

  Future<void> _saveTasks() async {
    await TaskStorage.saveTasks(tasks);
    await WidgetService.updateWidget(tasks, selectedDate);
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

  Future<void> _addTask(String title, List<int> repeatDays) async {
    setState(() {
      tasks.add(Task(title: title, repeatDays: repeatDays));
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
    WidgetService.updateWidget(tasks, selectedDate);
  }

  List<Task> get _filteredTasks {
    return WidgetService.filterTasksForDate(tasks, selectedDate);
  }

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
          await WidgetService.updateWidget(tasks, selectedDate);
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
          builder: (ctx) => AddTaskDialog(onAdd: _addTask),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
