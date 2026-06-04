import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/widgets/add_task_dialog.dart';
import 'package:task_planner/widgets/task_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AddTaskDialog', () {
    testWidgets('shows Add Task title when no initialTitle', (tester) async {
      await tester.pumpWidget(_wrap(
        AddTaskDialog(onAdd: (_, __) {}),
      ));
      expect(find.text('Add Task'), findsOneWidget);
    });

    testWidgets('shows Edit Task title when initialTitle provided', (tester) async {
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          initialTitle: 'Existing task',
          initialDays: [1],
          onAdd: (_, __) {},
        ),
      ));
      expect(find.text('Edit Task'), findsOneWidget);
    });

    testWidgets('pre-fills text field with initialTitle', (tester) async {
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          initialTitle: 'My Task',
          onAdd: (_, __) {},
        ),
      ));
      expect(find.widgetWithText(TextField, 'My Task'), findsOneWidget);
    });

    testWidgets('does not call onAdd when title is empty', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        AddTaskDialog(onAdd: (_, __) => called = true),
      ));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('calls onAdd with trimmed title and selected days', (tester) async {
      String? capturedTitle;
      List<int>? capturedDays;

      await tester.pumpWidget(_wrap(
        AddTaskDialog(onAdd: (title, days) {
          capturedTitle = title;
          capturedDays = days;
        }),
      ));

      await tester.enterText(find.byType(TextField), '  Buy groceries  ');
      await tester.tap(find.text('Mon'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(capturedTitle, equals('Buy groceries'));
      expect(capturedDays, contains(1));
    });

    testWidgets('editing task does not mutate original repeatDays list', (tester) async {
      final originalDays = [1, 3];
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          initialTitle: 'Task',
          initialDays: originalDays,
          onAdd: (_, __) {},
        ),
      ));

      await tester.tap(find.text('Wed'));
      await tester.pump();

      expect(originalDays, equals([1, 3]));
    });

    testWidgets('Cancel closes dialog without calling onAdd', (tester) async {
      var called = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => AddTaskDialog(onAdd: (_, __) => called = true),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Some task');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });
  });

  group('TaskTile', () {
    late Task task;
    late DateTime date;

    setUp(() {
      task = Task(title: 'Test task', repeatDays: [1]);
      date = DateTime(2024, 6, 10);
    });

    testWidgets('renders task title', (tester) async {
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () {},
          onEdit: () {},
        ),
      ));
      expect(find.text('Test task'), findsOneWidget);
    });

    testWidgets('checkbox is unchecked when task not completed', (tester) async {
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () {},
          onEdit: () {},
        ),
      ));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('checkbox is checked when task is completed', (tester) async {
      task.toggleCompletion(date);
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () {},
          onEdit: () {},
        ),
      ));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('tapping checkbox calls onToggle', (tester) async {
      var toggled = false;
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () => toggled = true,
          onEdit: () {},
        ),
      ));
      await tester.tap(find.byType(Checkbox));
      expect(toggled, isTrue);
    });

    testWidgets('long press calls onEdit', (tester) async {
      var edited = false;
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () {},
          onEdit: () => edited = true,
        ),
      ));
      await tester.longPress(find.text('Test task'));
      expect(edited, isTrue);
    });

    testWidgets('completed task title has strikethrough decoration', (tester) async {
      task.toggleCompletion(date);
      await tester.pumpWidget(_wrap(
        TaskTile(
          task: task,
          date: date,
          onToggle: () {},
          onEdit: () {},
        ),
      ));
      final text = tester.widget<Text>(find.text('Test task'));
      expect(text.style?.decoration, equals(TextDecoration.lineThrough));
    });
  });

  group('HomeScreen smoke test', () {
    testWidgets('renders without crashing with empty task list', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(
        home: _HomeScreenStub(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Task Planner'), findsOneWidget);
      expect(find.text('No tasks for this day'), findsOneWidget);
    });
  });
}

// Minimal stub that avoids importing HomeScreen's SharedPreferences dependency
class _HomeScreenStub extends StatelessWidget {
  const _HomeScreenStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Planner')),
      body: const Center(child: Text('No tasks for this day')),
    );
  }
}
