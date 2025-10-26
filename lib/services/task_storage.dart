import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskStorage {
  static const _tasksKey = 'tasks';

  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_tasksKey);
    if (stored == null) return [];
    return stored.map((e) => Task.fromJson(e)).toList();
  }

  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = tasks.map((t) => t.toJson()).toList();
    await prefs.setStringList(_tasksKey, jsonList);
  }

  static Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }

  static Future<String> exportBackup() async {
    final tasks = await loadTasks();
    return tasks.map((t) => t.toMap()).toList().toString();
  }

  static Future<void> importBackup(List<Task> tasks) async {
    await saveTasks(tasks);
  }
}
