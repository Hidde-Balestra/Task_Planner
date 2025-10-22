import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../widgets/add_task_dialog.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList('tasks');
    if (stored != null) {
      setState(() {
        tasks = stored.map((e) => Task.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tasks', tasks.map((t) => t.toJson()).toList());
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
    _saveTasks();
  }

  void _toggleTask(Task task) {
    setState(() {
      task.toggleCompletion(selectedDate);
    });
    _saveTasks();
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
      if (task.repeatDays.isEmpty) {
        return task.creationDate.day == selectedDate.day &&
            task.creationDate.month == selectedDate.month &&
            task.creationDate.year == selectedDate.year;
      }
      return task.repeatDays.contains(today);
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('EEEE, MMM d').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Task Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDay(-1),
          ),
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(formattedDate, style: const TextStyle(fontSize: 16)),
          )),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDay(1),
          ),
        ],
      ),
      body: _filteredTasks.isEmpty
          ? const Center(child: Text('No tasks for this day'))
          : ListView.builder(
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          final completed = task.isCompleted(selectedDate);

          return Dismissible(
            key: Key(task.title + task.hashCode.toString()),
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
            confirmDismiss: (direction) async {
              bool confirm = await showDialog(
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
              ) ?? false;

              return confirm;
            },
            onDismissed: (direction) {
              setState(() {
                tasks.remove(task);
              });
              _saveTasks();
            },
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
                onChanged: (_) => _toggleTask(task),
              ),
              onLongPress: () {
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
              },
            ),
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
