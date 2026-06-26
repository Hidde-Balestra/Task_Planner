import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/services/notification_service.dart';

void main() {
  group('NotificationService - notificationIdForTask', () {
    test('returns the same ID for the same task and date', () {
      const taskId = 'task_abc_1';
      final date = DateTime(2024, 6, 15);
      final id1 = NotificationService.notificationIdForTask(taskId, date);
      final id2 = NotificationService.notificationIdForTask(taskId, date);
      expect(id1, equals(id2));
    });

    test('returns different IDs for the same task on different dates', () {
      const taskId = 'task_abc_1';
      final id1 = NotificationService.notificationIdForTask(taskId, DateTime(2024, 6, 15));
      final id2 = NotificationService.notificationIdForTask(taskId, DateTime(2024, 6, 16));
      expect(id1, isNot(equals(id2)));
    });

    test('returns different IDs for different tasks on the same date', () {
      final date = DateTime(2024, 6, 15);
      final id1 = NotificationService.notificationIdForTask('task_1', date);
      final id2 = NotificationService.notificationIdForTask('task_2', date);
      expect(id1, isNot(equals(id2)));
    });

    test('returns a non-negative ID', () {
      final id = NotificationService.notificationIdForTask('task_xyz', DateTime(2024, 1, 1));
      expect(id, greaterThanOrEqualTo(0));
    });

    test('returns an ID within 31-bit int range', () {
      final id = NotificationService.notificationIdForTask('task_xyz', DateTime(2024, 1, 1));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('is deterministic across multiple calls with various IDs', () {
      final testCases = [
        ('1234567890_0', DateTime(2024, 3, 10)),
        ('9876543210_1', DateTime(2025, 12, 31)),
        ('abc_def', DateTime(2020, 1, 1)),
      ];
      for (final (taskId, date) in testCases) {
        final a = NotificationService.notificationIdForTask(taskId, date);
        final b = NotificationService.notificationIdForTask(taskId, date);
        expect(a, equals(b), reason: 'Mismatch for taskId=$taskId date=$date');
      }
    });
  });

  group('NotificationService - upcomingDatesForTask (one-time)', () {
    test('returns only the creation date when it falls in the window', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        creationDate: DateTime(2024, 6, 15),
      );
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 14),
        5,
      );
      expect(dates.length, 1);
      expect(dates.first, DateTime(2024, 6, 15));
    });

    test('returns empty when creation date is outside the window', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        creationDate: DateTime(2024, 6, 20),
      );
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 14),
        5,
      );
      expect(dates, isEmpty);
    });

    test('skips creation date when task is already completed', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        creationDate: DateTime(2024, 6, 15),
      );
      task.toggleCompletion(DateTime(2024, 6, 15));
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 14),
        5,
      );
      expect(dates, isEmpty);
    });
  });

  group('NotificationService - upcomingDatesForTask (weekly repeat)', () {
    test('returns all matching weekdays in the window', () {
      // Monday = weekday 1 in DateTime, which maps to index 1 (Mon) in the app
      // Sunday = weekday 7, maps to index 0
      // Task repeats on Mon (1) and Wed (3)
      final task = Task(
        title: 'T',
        repeatDays: [1, 3], // Mon and Wed
        creationDate: DateTime(2024, 6, 1),
      );
      // Window: Mon 2024-06-10 to Sun 2024-06-16 (7 days)
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10), // Monday
        7,
      );
      // Should include Mon Jun 10, Wed Jun 12, Mon Jun 17 is outside
      expect(dates.length, 2);
      expect(dates, contains(DateTime(2024, 6, 10))); // Mon
      expect(dates, contains(DateTime(2024, 6, 12))); // Wed
    });

    test('skips completed occurrences in a weekly repeat', () {
      final task = Task(
        title: 'T',
        repeatDays: [1], // Monday
        creationDate: DateTime(2024, 6, 1),
      );
      task.toggleCompletion(DateTime(2024, 6, 10)); // complete the Monday
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        7,
      );
      expect(dates, isNot(contains(DateTime(2024, 6, 10))));
    });
  });

  group('NotificationService - upcomingDatesForTask (interval repeat)', () {
    test('returns matching interval dates in the window', () {
      // Repeats every 3 days starting 2024-06-10
      final task = Task(
        title: 'T',
        repeatDays: [],
        repeatIntervalDays: 3,
        creationDate: DateTime(2024, 6, 10),
      );
      // Window: Jun 10..Jun 19 (10 days)
      // Matches: Jun 10, Jun 13, Jun 16, Jun 19
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        10,
      );
      expect(dates.length, 4);
      expect(dates, contains(DateTime(2024, 6, 10)));
      expect(dates, contains(DateTime(2024, 6, 13)));
      expect(dates, contains(DateTime(2024, 6, 16)));
      expect(dates, contains(DateTime(2024, 6, 19)));
    });

    test('does not include dates before creation date', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        repeatIntervalDays: 2,
        creationDate: DateTime(2024, 6, 12),
      );
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        5,
      );
      for (final d in dates) {
        expect(
          d.isBefore(DateTime(2024, 6, 12)),
          isFalse,
          reason: 'Date $d is before creation date',
        );
      }
    });

    test('skips completed interval occurrences', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        repeatIntervalDays: 3,
        creationDate: DateTime(2024, 6, 10),
      );
      task.toggleCompletion(DateTime(2024, 6, 13));
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        7,
      );
      expect(dates, isNot(contains(DateTime(2024, 6, 13))));
      expect(dates, contains(DateTime(2024, 6, 10)));
    });
  });

  group('NotificationService - upcomingDatesForTask (postponement)', () {
    test('excludes date that task was postponed away from', () {
      final task = Task(
        title: 'T',
        repeatDays: [],
        creationDate: DateTime(2024, 6, 15),
      );
      task.postponeTo(DateTime(2024, 6, 15), DateTime(2024, 6, 20));
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 14),
        7,
      );
      expect(dates, isNot(contains(DateTime(2024, 6, 15))));
      expect(dates, contains(DateTime(2024, 6, 20)));
    });
  });

  group('NotificationService - rescheduleAll guard', () {
    test('rescheduleAll returns immediately when not initialized', () async {
      // NotificationService._initialized is false in test environment
      // (initialize() is never called). rescheduleAll must not throw.
      final task = Task(title: 'T', repeatDays: [], dueTime: '10:00');
      await expectLater(
        NotificationService.rescheduleAll([task]),
        completes,
      );
    });
  });

  group('NotificationService - upcomingDatesForTask (edge cases)', () {
    test('returns empty for a task with no occurrences', () {
      // Weekly task that repeats only on Sunday (0), window starts on Monday
      final task = Task(
        title: 'T',
        repeatDays: [0], // Sunday
        creationDate: DateTime(2024, 6, 1),
      );
      // Jun 10 = Monday, 6 days window ends Saturday Jun 15
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        6,
      );
      expect(dates, isEmpty);
    });

    test('window of 0 days returns empty', () {
      final task = Task(
        title: 'T',
        repeatDays: [1],
        creationDate: DateTime(2024, 6, 1),
      );
      final dates = NotificationService.upcomingDatesForTask(
        task,
        DateTime(2024, 6, 10),
        0,
      );
      expect(dates, isEmpty);
    });
  });
}
