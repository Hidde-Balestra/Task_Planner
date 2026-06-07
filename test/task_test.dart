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

  group('Task - priority', () {
    test('default priority is low', () {
      final task = Task(title: 'Test', repeatDays: []);
      expect(task.priority, equals(Priority.low));
    });

    test('priority can be set to medium', () {
      final task =
          Task(title: 'Test', repeatDays: [], priority: Priority.medium);
      expect(task.priority, equals(Priority.medium));
    });

    test('priority can be set to high', () {
      final task = Task(title: 'Test', repeatDays: [], priority: Priority.high);
      expect(task.priority, equals(Priority.high));
    });

    test('priority serializes to name string', () {
      final task = Task(title: 'T', repeatDays: [], priority: Priority.high);
      expect(task.toMap()['priority'], equals('high'));
    });

    test('priority deserializes from name string', () {
      final task = Task.fromMap({'title': 'T', 'repeatDays': <int>[], 'priority': 'medium'});
      expect(task.priority, equals(Priority.medium));
    });

    test('missing priority defaults to low', () {
      final task = Task.fromMap({'title': 'T', 'repeatDays': <int>[]});
      expect(task.priority, equals(Priority.low));
    });

    test('unknown priority string defaults to low', () {
      final task = Task.fromMap(
          {'title': 'T', 'repeatDays': <int>[], 'priority': 'urgent'});
      expect(task.priority, equals(Priority.low));
    });

    test('all priority values round-trip through map', () {
      for (final p in Priority.values) {
        final task = Task(title: 'T', repeatDays: [], priority: p);
        final restored = Task.fromMap(task.toMap());
        expect(restored.priority, equals(p));
      }
    });
  });

  group('Task - repeatIntervalDays', () {
    test('default repeatIntervalDays is 0', () {
      final task = Task(title: 'Test', repeatDays: []);
      expect(task.repeatIntervalDays, equals(0));
    });

    test('repeatIntervalDays persists through serialization', () {
      final task = Task(title: 'Test', repeatDays: [], repeatIntervalDays: 14);
      final restored = Task.fromMap(task.toMap());
      expect(restored.repeatIntervalDays, equals(14));
    });

    test('missing repeatIntervalDays defaults to 0', () {
      final task = Task.fromMap({'title': 'T', 'repeatDays': <int>[]});
      expect(task.repeatIntervalDays, equals(0));
    });
  });

  group('Task - serialization', () {
    test('toMap and fromMap round-trip preserves all fields', () {
      final original = Task(
        title: 'Test Task',
        repeatDays: [1, 3, 5],
        priority: Priority.high,
        repeatIntervalDays: 7,
        creationDate: DateTime(2024, 6, 15),
      );
      final date = DateTime(2024, 6, 15);
      original.toggleCompletion(date);

      final restored = Task.fromMap(original.toMap());

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.repeatDays, equals(original.repeatDays));
      expect(restored.creationDate, equals(original.creationDate));
      expect(restored.priority, equals(Priority.high));
      expect(restored.repeatIntervalDays, equals(7));
      expect(restored.isCompleted(date), isTrue);
    });

    test('toJson and fromJson round-trip preserves all fields', () {
      final original =
          Task(title: 'JSON Task', repeatDays: [0, 6], priority: Priority.medium);
      final restored = Task.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.repeatDays, equals(original.repeatDays));
      expect(restored.priority, equals(Priority.medium));
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
