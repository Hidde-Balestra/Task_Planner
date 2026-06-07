import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/services/widget_service.dart';

void main() {
  group('WidgetService.filterTasksForDate', () {
    test('returns one-time task only on its creation date', () {
      final date = DateTime(2024, 6, 10);
      final task = Task(title: 'One-time', repeatDays: [], creationDate: date);
      expect(WidgetService.filterTasksForDate([task], date), contains(task));
      expect(
        WidgetService.filterTasksForDate([task], DateTime(2024, 6, 11)),
        isEmpty,
      );
    });

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

    test('returns empty list for empty task list', () {
      expect(WidgetService.filterTasksForDate([], DateTime(2024, 6, 10)), isEmpty);
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
