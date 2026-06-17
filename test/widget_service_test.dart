import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/services/widget_service.dart';

void main() {
  group('WidgetService.filterTasksForDate - one-time tasks', () {
    test('returns one-time task only on its creation date', () {
      final date = DateTime(2024, 6, 10);
      final task = Task(title: 'One-time', repeatDays: [], creationDate: date);
      expect(WidgetService.filterTasksForDate([task], date), contains(task));
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 11)),
        isEmpty,
      );
    });
  });

  group('WidgetService.filterTasksForDate - weekly tasks', () {
    test('returns repeating task on matching weekday', () {
      // Monday = DateTime.weekday 1; 1 % 7 = 1
      final monday = DateTime(2024, 6, 10);
      final tuesday = DateTime(2024, 6, 11);
      final task = Task(title: 'Mon/Wed', repeatDays: [1, 3]);
      expect(WidgetService.filterTasksForDate([task], monday), contains(task));
      expect(WidgetService.filterTasksForDate([task], tuesday), isEmpty);
    });

    test('sunday uses weekday 0 (7 % 7 == 0)', () {
      final sunday = DateTime(2024, 6, 9); // weekday == 7
      final task = Task(title: 'Sunday task', repeatDays: [0]);
      expect(WidgetService.filterTasksForDate([task], sunday), contains(task));
    });

    test('saturday uses weekday 6 (6 % 7 == 6)', () {
      final saturday = DateTime(2024, 6, 8); // weekday == 6
      final task = Task(title: 'Saturday task', repeatDays: [6]);
      expect(WidgetService.filterTasksForDate([task], saturday), contains(task));
    });

    test('returns empty list when no tasks match date', () {
      final date = DateTime(2024, 6, 10); // Monday
      final task = Task(title: 'Tue/Thu', repeatDays: [2, 4]);
      expect(WidgetService.filterTasksForDate([task], date), isEmpty);
    });

    test('filters multiple tasks independently', () {
      final date = DateTime(2024, 6, 10); // Monday
      final matching = Task(title: 'Monday', repeatDays: [1]);
      final notMatching = Task(title: 'Wednesday', repeatDays: [3]);
      final result = WidgetService.filterTasksForDate(
        [matching, notMatching],
        date,
      );
      expect(result, contains(matching));
      expect(result, isNot(contains(notMatching)));
    });
  });

  group('WidgetService.filterTasksForDate - interval tasks', () {
    test('shows on start date (diff == 0)', () {
      final start = DateTime(2024, 6, 10);
      final task = Task(
        title: 'Bi-weekly',
        repeatDays: [],
        repeatIntervalDays: 14,
        creationDate: start,
      );
      expect(WidgetService.filterTasksForDate([task], start), contains(task));
    });

    test('shows exactly N days after start', () {
      final start = DateTime(2024, 6, 10);
      final task = Task(
        title: 'Every 14 days',
        repeatDays: [],
        repeatIntervalDays: 14,
        creationDate: start,
      );
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 24)),
        contains(task),
      );
    });

    test('does not show between interval days', () {
      final start = DateTime(2024, 6, 10);
      final task = Task(
        title: 'Every 14 days',
        repeatDays: [],
        repeatIntervalDays: 14,
        creationDate: start,
      );
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 17)),
        isEmpty,
      );
    });

    test('does not show before start date', () {
      final start = DateTime(2024, 6, 10);
      final task = Task(
        title: 'Future task',
        repeatDays: [],
        repeatIntervalDays: 7,
        creationDate: start,
      );
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 3)),
        isEmpty,
      );
    });

    test('every 7 days shows on multiples of 7', () {
      final start = DateTime(2024, 1, 1);
      final task = Task(
        title: 'Weekly interval',
        repeatDays: [],
        repeatIntervalDays: 7,
        creationDate: start,
      );
      for (final offset in [0, 7, 14, 21, 28]) {
        final date = start.add(Duration(days: offset));
        expect(
          WidgetService.filterTasksForDate([task], date),
          contains(task),
          reason: '+$offset days should match',
        );
      }
      for (final offset in [1, 6, 8, 13]) {
        final date = start.add(Duration(days: offset));
        expect(
          WidgetService.filterTasksForDate([task], date),
          isEmpty,
          reason: '+$offset days should not match',
        );
      }
    });

    test('interval task takes priority over repeatDays when intervalDays > 0', () {
      // A task with both repeatDays and repeatIntervalDays should use interval logic
      final start = DateTime(2024, 6, 10); // Monday
      final task = Task(
        title: 'Interval wins',
        repeatDays: [1], // would match every Monday
        repeatIntervalDays: 14,
        creationDate: start,
      );
      // Next Monday (June 17) is NOT 14 days away → should NOT match
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 17)),
        isEmpty,
      );
      // 14 days away (June 24) → should match
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 24)),
        contains(task),
      );
    });
  });

  group('WidgetService.filterTasksForDate - general', () {
    test('returns empty list for empty task list', () {
      expect(WidgetService.filterTasksForDate([], DateTime(2024, 6, 10)), isEmpty);
    });
  });

  group('WidgetService.filterTasksForDate - postponed tasks', () {
    test('one-time task does not appear on original date after postpone', () {
      final date = DateTime(2024, 6, 10);
      final task = Task(title: 'One-time', repeatDays: [], creationDate: date);
      task.postponeTo(date, DateTime(2024, 6, 11));
      expect(WidgetService.filterTasksForDate([task], date), isEmpty);
    });

    test('one-time task appears on postponed-to date', () {
      final original = DateTime(2024, 6, 10);
      final newDate = DateTime(2024, 6, 11);
      final task = Task(title: 'One-time', repeatDays: [], creationDate: original);
      task.postponeTo(original, newDate);
      expect(WidgetService.filterTasksForDate([task], newDate), contains(task));
    });

    test('weekly task does not appear on the postponed occurrence date', () {
      final monday = DateTime(2024, 6, 10); // Monday weekday=1
      final task = Task(title: 'Weekly', repeatDays: [1]);
      task.postponeTo(monday, DateTime(2024, 6, 11));
      expect(WidgetService.filterTasksForDate([task], monday), isEmpty);
    });

    test('weekly task still appears on other (non-postponed) occurrences', () {
      final monday1 = DateTime(2024, 6, 10);
      final monday2 = DateTime(2024, 6, 17);
      final task = Task(title: 'Weekly', repeatDays: [1]);
      task.postponeTo(monday1, DateTime(2024, 6, 11));
      // Next Monday should still appear
      expect(WidgetService.filterTasksForDate([task], monday2), contains(task));
    });

    test('weekly task postponed to a non-occurrence date appears there', () {
      final monday = DateTime(2024, 6, 10);
      final wednesday = DateTime(2024, 6, 12);
      final task = Task(title: 'Weekly', repeatDays: [1]);
      task.postponeTo(monday, wednesday);
      expect(WidgetService.filterTasksForDate([task], wednesday), contains(task));
    });

    test('interval task does not appear on postponed date', () {
      final start = DateTime(2024, 6, 10);
      final task = Task(
        title: 'Interval',
        repeatDays: [],
        repeatIntervalDays: 7,
        creationDate: start,
      );
      task.postponeTo(start, DateTime(2024, 6, 11));
      expect(WidgetService.filterTasksForDate([task], start), isEmpty);
    });

    test('interval task appears on postponed-to date', () {
      final start = DateTime(2024, 6, 10);
      final newDate = DateTime(2024, 6, 13);
      final task = Task(
        title: 'Interval',
        repeatDays: [],
        repeatIntervalDays: 7,
        creationDate: start,
      );
      task.postponeTo(start, newDate);
      expect(WidgetService.filterTasksForDate([task], newDate), contains(task));
    });
  });

  group('WidgetService.buildWidgetData', () {
    test('returns correct structure for a task', () {
      final date = DateTime(2024, 6, 10); // Monday
      final task = Task(title: 'Test task', repeatDays: [1]);
      final data = WidgetService.buildWidgetData([task], date);
      expect(data.length, equals(1));
      expect(data[0]['id'], equals(task.id));
      expect(data[0]['title'], equals('Test task'));
      expect(data[0]['done'], isFalse);
    });

    test('reflects completed state as true', () {
      final date = DateTime(2024, 6, 10);
      final task = Task(title: 'Done task', repeatDays: [1]);
      task.toggleCompletion(date);
      final data = WidgetService.buildWidgetData([task], date);
      expect(data[0]['done'], isTrue);
    });

    test('excludes tasks not matching the date', () {
      final monday = DateTime(2024, 6, 10);
      final task = Task(title: 'Not today', repeatDays: [3]); // Wednesday
      expect(WidgetService.buildWidgetData([task], monday), isEmpty);
    });

    test('returns empty list when no tasks', () {
      expect(WidgetService.buildWidgetData([], DateTime(2024, 6, 10)), isEmpty);
    });

    test('includes multiple matching tasks in order', () {
      final date = DateTime(2024, 6, 10); // Monday
      final t1 = Task(title: 'First', repeatDays: [1]);
      final t2 = Task(title: 'Second', repeatDays: [1]);
      final data = WidgetService.buildWidgetData([t1, t2], date);
      expect(data.length, equals(2));
      expect(data[0]['title'], equals('First'));
      expect(data[1]['title'], equals('Second'));
    });

    test('one-time task included on creation date', () {
      final date = DateTime(2024, 6, 10);
      final task = Task(title: 'One-time', repeatDays: [], creationDate: date);
      final data = WidgetService.buildWidgetData([task], date);
      expect(data.length, equals(1));
      expect(data[0]['title'], equals('One-time'));
    });
  });
}
