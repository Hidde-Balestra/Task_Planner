import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'widget_service.dart';

class NotificationService {
  static final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const int _lookaheadDays = 14;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      const android = fln.AndroidInitializationSettings('ic_notification');
      await _plugin.initialize(const fln.InitializationSettings(android: android));
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: initialize failed: $e');
    }
  }

  static Future<void> requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
  }

  /// Cancels all scheduled task notifications, then reschedules for all tasks
  /// with a dueTime, covering the next [_lookaheadDays] days from [from].
  static Future<void> rescheduleAll(
    List<Task> tasks, {
    DateTime? from,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      final start = from ?? DateTime.now();
      for (final task in tasks) {
        if (task.dueTime == null) continue;
        for (final date in upcomingDatesForTask(task, start, _lookaheadDays)) {
          await _scheduleOne(task, date);
        }
      }
    } catch (e) {
      debugPrint('Failed to reschedule notifications: $e');
    }
  }

  static Future<void> _scheduleOne(Task task, DateTime date) async {
    final dueTime = task.dueTime!;
    final parts = dueTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      notificationIdForTask(task.id, date),
      task.title,
      'Deadline: $dueTime',
      scheduled,
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'task_deadlines',
          'Task Deadlines',
          channelDescription: 'Herinneringen voor taak-deadlines',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Returns a deterministic, positive 31-bit notification ID for a
  /// (taskId, date) pair. Made public so it can be tested.
  static int notificationIdForTask(String taskId, DateTime date) {
    final dayNum = date.difference(DateTime.utc(2020)).inDays;
    var h = 5381;
    for (var i = 0; i < taskId.length; i++) {
      h = ((h << 5) + h + taskId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return ((h * 31 + dayNum) & 0x7FFFFFFF);
  }

  /// Returns the dates in [from, from + days) on which [task] appears
  /// and has not yet been completed. Made public so it can be tested.
  static List<DateTime> upcomingDatesForTask(
    Task task,
    DateTime from,
    int days,
  ) {
    final result = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final raw = from.add(Duration(days: i));
      final date = DateTime(raw.year, raw.month, raw.day);
      final appears = WidgetService.filterTasksForDate([task], date).isNotEmpty;
      if (appears && !task.isCompleted(date)) {
        result.add(date);
      }
    }
    return result;
  }
}
