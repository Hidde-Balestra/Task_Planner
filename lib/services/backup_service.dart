import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import 'task_storage.dart';

class BackupService {
  static Future<String> backup(List<Task> tasks) async {
    final directory = await getApplicationDocumentsDirectory();
    final backupFile = File('${directory.path}/tasks_backup.json');
    final data = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await backupFile.writeAsString(data);
    return backupFile.path;
  }

  static Future<List<Task>?> restore() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/tasks_backup.json');
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      final tasks = jsonList.map((e) => Task.fromMap(e)).toList();

      await TaskStorage.saveTasks(tasks);
      return tasks;
    } catch (e) {
      if (kDebugMode) {
        print('Restore failed: $e');
      }
      return null;
    }
  }

}
