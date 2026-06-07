import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class WidgetService {
  static const _channel = MethodChannel('nl.hidde.taskplanner/widget');

  static Future<void> updateWidget(List<Task> tasks, DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('today_tasks', jsonEncode(buildTaskData(tasks, date)));
      await prefs.setString('date_label', _formatDate(date));
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  static List<Map<String, dynamic>> buildTaskData(List<Task> tasks, DateTime date) {
    return filterTasksForDate(tasks, date).map((t) => {
      'id': t.id,
      'title': t.title,
      'completed': t.isCompleted(date),
    }).toList();
  }

  static List<Task> filterTasksForDate(List<Task> tasks, DateTime date) {
    final weekday = date.weekday % 7; // Mon=1..Sun=7 → Mon=1..Sat=6, Sun=0
    return tasks.where((task) {
      if (task.repeatDays.isEmpty) {
        return task.creationDate.year == date.year &&
            task.creationDate.month == date.month &&
            task.creationDate.day == date.day;
      }
      return task.repeatDays.contains(weekday);
    }).toList();
  }

  static String _formatDate(DateTime date) =>
      DateFormat('E, MMM d').format(date);
}
