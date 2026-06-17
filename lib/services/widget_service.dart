import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';

class WidgetService {
  static const String _androidName = 'TaskWidgetProvider';

  static List<Task> filterTasksForDate(List<Task> tasks, DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final weekday = date.weekday % 7;

    return tasks.where((task) {
      // Postponed away from this date — never show here
      if (task.postponedDates.containsKey(dateKey)) return false;

      bool naturallyAppears;
      if (task.repeatIntervalDays > 0) {
        final start = DateTime(
          task.creationDate.year,
          task.creationDate.month,
          task.creationDate.day,
        );
        final diff = targetDay.difference(start).inDays;
        naturallyAppears = diff >= 0 && diff % task.repeatIntervalDays == 0;
      } else if (task.repeatDays.isNotEmpty) {
        naturallyAppears = task.repeatDays.contains(weekday);
      } else {
        naturallyAppears = task.creationDate.year == date.year &&
            task.creationDate.month == date.month &&
            task.creationDate.day == date.day;
      }

      if (naturallyAppears) return true;

      // Postponed to this date from another date
      return task.postponedDates.containsValue(dateKey);
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
            'priority': t.priority.name,
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
