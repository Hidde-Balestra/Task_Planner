import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/models/task.dart';

void main() {
  group('Task - completion', () {
    test('isCompleted returns false by default', () {
      final task = Task(title: 'Test', repeatDays: []);
      expect(task.isCompleted(DateTime(2024, 6, 15)), isFalse);
    });

    test('toggleCompletion marks task as completed', () {
      final task = Task(title: 'Test', repeatDays: []);
      final date = DateTime(2024, 6, 15);
      task.toggleCompletion(date);
      expect(task.isCompleted(date), isTrue);
    });

    test('toggleCompletion twice returns to incomplete', () {
      final task = Task(title: 'Test', repeatDays: []);
      final date = DateTime(2024, 6, 15);
      task.toggleCompletion(date);
      task.toggleCompletion(date);
      expect(task.isCompleted(date), isFalse);
    });

    test('completion is independent per date', () {
      final task = Task(title: 'Test', repeatDays: [1, 2, 3, 4, 5]);
      final monday = DateTime(2024, 6, 10);
      final tuesday = DateTime(2024, 6, 11);
      task.toggleCompletion(monday);
      expect(task.isCompleted(monday), isTrue);
      expect(task.isCompleted(tuesday), isFalse);
    });
  });

  group('Task - serialization', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final original = Task(
        title: 'Test Task',
        repeatDays: [1, 3, 5],
        creationDate: DateTime(2024, 6, 15),
      );
      final date = DateTime(2024, 6, 15);
      original.toggleCompletion(date);

      final restored = Task.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.repeatDays, equals(original.repeatDays));
      expect(restored.creationDate, equals(original.creationDate));
      expect(restored.isCompleted(date), isTrue);
    });

    test('toJson and fromJson round-trip preserves all fields', () {
      final original = Task(title: 'JSON Task', repeatDays: [0, 6]);
      final restored = Task.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.repeatDays, equals(original.repeatDays));
    });

    test('fromMap with missing title falls back to Untitled Task', () {
      final task = Task.fromMap({});
      expect(task.title, equals('Untitled Task'));
    });

    test('fromMap with null completedByDate creates empty map', () {
      final task = Task.fromMap({
        'title': 'Test',
        'repeatDays': <int>[],
        'completedByDate': null,
      });
      expect(task.completedByDate, isEmpty);
    });

    test('fromMap with non-bool completedByDate value defaults to false', () {
      final task = Task.fromMap({
        'title': 'Test',
        'repeatDays': <int>[],
        'completedByDate': {'2024-6-5': null},
      });
      expect(task.completedByDate['2024-6-5'], isFalse);
    });

    test('fromMap with invalid creationDate falls back to now', () {
      final before = DateTime.now();
      final task = Task.fromMap({
        'title': 'Test',
        'repeatDays': <int>[],
        'creationDate': 'not-a-date',
      });
      expect(task.creationDate.isAfter(before) ||
          task.creationDate.isAtSameMomentAs(before), isTrue);
    });

    test('fromMap with missing id generates a new id', () {
      final task = Task.fromMap({'title': 'Test', 'repeatDays': <int>[]});
      expect(task.id, isNotEmpty);
    });

    test('fromMap preserves existing id', () {
      const existingId = '12345';
      final task = Task.fromMap({
        'id': existingId,
        'title': 'Test',
        'repeatDays': <int>[],
      });
      expect(task.id, equals(existingId));
    });
  });

  group('Task - unique IDs', () {
    test('multiple tasks created in rapid succession have different IDs', () {
      final ids = List.generate(10, (_) => Task(title: 'T', repeatDays: []).id);
      expect(ids.toSet().length, equals(ids.length));
    });
  });
}
