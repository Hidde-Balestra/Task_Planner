import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/services/widget_service.dart';

void main() {
  // Dates used across tests
  final monday = DateTime(2024, 6, 10);   // weekday=1 (Mon)
  final tuesday = DateTime(2024, 6, 11);  // weekday=2 (Tue)
  final sunday = DateTime(2024, 6, 16);   // weekday=7 → 0 (Sun)

  group('WidgetService.filterTasksForDate', () {
    test('shows one-time task on its creation date', () {
      final task = Task(title: 'One-time', repeatDays: [], creationDate: monday);
      expect(WidgetService.filterTasksForDate([task], monday), contains(task));
    });

    test('hides one-time task on a different date', () {
      final task = Task(title: 'One-time', repeatDays: [], creationDate: monday);
      expect(WidgetService.filterTasksForDate([task], tuesday), isEmpty);
    });

    test('shows repeating task on a matching weekday', () {
      final task = Task(title: 'Every Monday', repeatDays: [1]);
      expect(WidgetService.filterTasksForDate([task], monday), contains(task));
    });

    test('hides repeating task on a non-matching weekday', () {
      final task = Task(title: 'Every Monday', repeatDays: [1]);
      expect(WidgetService.filterTasksForDate([task], tuesday), isEmpty);
    });

    test('shows Sunday repeating task on Sunday', () {
      final task = Task(title: 'Every Sunday', repeatDays: [0]);
      expect(WidgetService.filterTasksForDate([task], sunday), contains(task));
    });

    test('hides Sunday task on Monday', () {
      final task = Task(title: 'Every Sunday', repeatDays: [0]);
      expect(WidgetService.filterTasksForDate([task], monday), isEmpty);
    });

    test('returns multiple matching tasks', () {
      final t1 = Task(title: 'A', repeatDays: [1]);
      final t2 = Task(title: 'B', repeatDays: [1]);
      final t3 = Task(title: 'C', repeatDays: [2]);
      final result = WidgetService.filterTasksForDate([t1, t2, t3], monday);
      expect(result, containsAll([t1, t2]));
      expect(result, isNot(contains(t3)));
    });

    test('returns empty list when no tasks match', () {
      final task = Task(title: 'Saturday only', repeatDays: [6]);
      expect(WidgetService.filterTasksForDate([task], monday), isEmpty);
    });
  });

  group('WidgetService.buildTaskData', () {
    test('includes id, title, and completed fields', () {
      final task = Task(title: 'My Task', repeatDays: [1], creationDate: monday);
      final data = WidgetService.buildTaskData([task], monday);

      expect(data, hasLength(1));
      expect(data.first['id'], equals(task.id));
      expect(data.first['title'], equals('My Task'));
      expect(data.first['completed'], isFalse);
    });

    test('reflects completed status correctly', () {
      final task = Task(title: 'Done Task', repeatDays: [1], creationDate: monday);
      task.toggleCompletion(monday);
      final data = WidgetService.buildTaskData([task], monday);
      expect(data.first['completed'], isTrue);
    });

    test('returns only tasks matching the given date', () {
      final monTask = Task(title: 'Mon', repeatDays: [1]);
      final tueTask = Task(title: 'Tue', repeatDays: [2]);
      final data = WidgetService.buildTaskData([monTask, tueTask], monday);
      expect(data, hasLength(1));
      expect(data.first['title'], equals('Mon'));
    });

    test('returns empty list when no tasks match', () {
      final task = Task(title: 'Weekend', repeatDays: [0, 6]);
      final data = WidgetService.buildTaskData([task], monday);
      expect(data, isEmpty);
    });

    test('completed status is date-specific', () {
      final task = Task(title: 'Task', repeatDays: [1, 2], creationDate: monday);
      task.toggleCompletion(monday);

      final mondayData = WidgetService.buildTaskData([task], monday);
      final tuesdayData = WidgetService.buildTaskData([task], tuesday);

      expect(mondayData.first['completed'], isTrue);
      expect(tuesdayData.first['completed'], isFalse);
    });
  });
}
