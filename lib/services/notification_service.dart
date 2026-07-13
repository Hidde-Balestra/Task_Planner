import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'settings_service.dart';
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
      // Timezone detection is best-effort: UTC fallback keeps the service
      // working even if flutter_timezone has issues on this device.
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      } catch (e) {
        debugPrint('NotificationService: timezone detection failed, using UTC: $e');
      }
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

  static Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService: cancelAll failed: $e');
    }
  }

  /// Cancels all scheduled task notifications, then reschedules for all tasks
  /// with a dueTime, covering the next [_lookaheadDays] days from [from].
  /// No-ops if vacation mode is enabled.
  static Future<void> rescheduleAll(
    List<Task> tasks, {
    DateTime? from,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
      if (await SettingsService.loadVacationMode()) return;
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

    const details = fln.NotificationDetails(
      android: fln.AndroidNotificationDetails(
        'task_deadlines',
        'Task Deadlines',
        channelDescription: 'Herinneringen voor taak-deadlines',
        importance: fln.Importance.high,
        priority: fln.Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        notificationIdForTask(task.id, date),
        task.title,
        'Deadline verstreken: $dueTime',
        scheduled,
        details,
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            fln.UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Fall back to inexact when exact-alarm permission is unavailable.
      try {
        await _plugin.zonedSchedule(
          notificationIdForTask(task.id, date),
          task.title,
          'Deadline verstreken: $dueTime',
          scheduled,
          details,
          androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              fln.UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('NotificationService: schedule failed for ${task.id}: $e');
      }
    }
  }

  /// Returns tasks from [tasks] that have a dueTime in the past at [now],
  /// appear on today's date, and are not yet completed.
  /// Used by HomeScreen for the in-app overdue alert.
  static List<Task> overdueTasksForToday(List<Task> tasks, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return tasks.where((task) {
      if (task.dueTime == null) return false;
      if (task.isCompleted(today)) return false;
      final appears =
          WidgetService.filterTasksForDate([task], today).isNotEmpty;
      if (!appears) return false;
      final parts = task.dueTime!.split(':');
      if (parts.length != 2) return false;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return false;
      final deadline = DateTime(now.year, now.month, now.day, h, m);
      return now.isAfter(deadline);
    }).toList();
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
