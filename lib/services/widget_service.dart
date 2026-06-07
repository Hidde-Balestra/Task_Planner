import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

class WidgetService {
  static const String _androidName = 'TaskWidgetProvider';

  static List<Task> filterTasksForDate(List<Task> tasks, DateTime date) {
    final weekday = date.weekday % 7;
    return tasks.where((task) {
      if (task.repeatDays.isEmpty) {
        return task.creationDate.year == date.year &&
            task.creationDate.month == date.month &&
            task.creationDate.day == date.day;
      }
      return task.repeatDays.contains(weekday);
    }).toList();
  }

  static List<Map<String, dynamic>> buildWidgetData(
    List<Task> tasks,
    DateTime date,
  ) {
    return filterTasksForDate(tasks, date)
        .map(
          (t) => {
            'id': t.id,
            'title': t.title,
            'done': t.isCompleted(date),
          },
        )
        .toList();
  }

  static Future<void> updateWidget(List<Task> allTasks, DateTime date) async {
    final data = buildWidgetData(allTasks, date);
    await HomeWidget.saveWidgetData<String>('tasks_json', jsonEncode(data));
    await HomeWidget.saveWidgetData<String>(
      'date_label',
      DateFormat('EEE, MMM d').format(date),
    );
    await HomeWidget.updateWidget(androidName: _androidName);
  }
}
