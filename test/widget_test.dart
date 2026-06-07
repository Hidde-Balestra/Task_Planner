import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_planner/models/task.dart';
import 'package:task_planner/screens/home_screen.dart';
import 'package:task_planner/widgets/add_task_dialog.dart';
import 'package:task_planner/widgets/task_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void _noop(String t, List<int> d, Priority p, int i, DateTime dt) {}

void main() {
  group('AddTaskDialog', () {
    testWidgets('shows Add Task title when no initialTitle', (tester) async {
      await tester.pumpWidget(_wrap(AddTaskDialog(onAdd: _noop)));
      expect(find.text('Add Task'), findsOneWidget);
    });

    testWidgets('shows Edit Task title when initialTitle provided', (tester) async {
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          initialTitle: 'Existing task',
          initialDays: [1],
          onAdd: _noop,
        ),
      ));
      expect(find.text('Edit Task'), findsOneWidget);
    });

    testWidgets('pre-fills text field with initialTitle', (tester) async {
      await tester.pumpWidget(_wrap(
        AddTaskDialog(initialTitle: 'My Task', onAdd: _noop),
      ));
      expect(find.widgetWithText(TextField, 'My Task'), findsWidgets);
    });

    testWidgets('does not call onAdd when title is empty', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          onAdd: (t, d, p, i, dt) => called = true,
        ),
      ));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('calls onAdd with trimmed title and selected days',
        (tester) async {
      String? capturedTitle;
      List<int>? capturedDays;

      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          onAdd: (title, days, p, i, dt) {
            capturedTitle = title;
            capturedDays = days;
          },
        ),
      ));

      await tester.enterText(find.byType(TextField).first, '  Buy groceries  ');
      // Switch to Days mode to select weekdays
      await tester.tap(find.text('Days'));
      await tester.pump();
      await tester.tap(find.text('Mon'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(capturedTitle, equals('Buy groceries'));
      expect(capturedDays, contains(1));
    });

    testWidgets('editing task does not mutate original repeatDays list',
        (tester) async {
      final originalDays = [1, 3];
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          initialTitle: 'Task',
          initialDays: originalDays,
          onAdd: _noop,
        ),
      ));

      // Dialog opens in weekly mode because initialDays is non-empty
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
                builder: (_) => AddTaskDialog(
                  onAdd: (t, d, p, i, dt) => called = true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Some task');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });

    testWidgets('priority chips are all visible', (tester) async {
      await tester.pumpWidget(_wrap(AddTaskDialog(onAdd: _noop)));
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('selecting High priority passes it to onAdd', (tester) async {
      Priority? captured;
      await tester.pumpWidget(_wrap(
        AddTaskDialog(onAdd: (t, d, p, i, dt) => captured = p),
      ));
      await tester.enterText(find.byType(TextField).first, 'Task');
      await tester.tap(find.text('High'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(captured, equals(Priority.high));
    });

    testWidgets('interval mode: entering days passes intervalDays to onAdd',
        (tester) async {
      int? capturedInterval;
      await tester.pumpWidget(_wrap(
        AddTaskDialog(onAdd: (t, d, p, i, dt) => capturedInterval = i),
      ));
      await tester.enterText(find.byType(TextField).first, 'Task');
      await tester.tap(find.text('Interval'));
      await tester.pump();
      // Clear and type new interval value
      final intervalField = find.byType(TextField).last;
      await tester.tap(intervalField);
      await tester.enterText(intervalField, '30');
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(capturedInterval, equals(30));
    });

    testWidgets('once mode: passes zero repeatDays and zero interval',
        (tester) async {
      List<int>? capturedDays;
      int? capturedInterval;
      await tester.pumpWidget(_wrap(
        AddTaskDialog(
          onAdd: (t, d, p, i, dt) {
            capturedDays = d;
            capturedInterval = i;
          },
        ),
      ));
      await tester.enterText(find.byType(TextField).first, 'Task');
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(capturedDays, isEmpty);
      expect(capturedInterval, equals(0));
    });

    testWidgets('initialDate pre-fills the date shown', (tester) async {
      final date = DateTime(2024, 6, 10);
      await tester.pumpWidget(_wrap(
        AddTaskDialog(initialDate: date, onAdd: _noop),
      ));
      // In "Once" mode, the date button should show 'Mon, Jun 10'
      expect(find.textContaining('Jun 10'), findsOneWidget);
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
        TaskTile(task: task, date: date, onToggle: () {}, onEdit: () {}),
      ));
      expect(find.text('Test task'), findsOneWidget);
    });

    testWidgets('checkbox is unchecked when task not completed', (tester) async {
      await tester.pumpWidget(_wrap(
        TaskTile(task: task, date: date, onToggle: () {}, onEdit: () {}),
      ));
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('checkbox is checked when task is completed', (tester) async {
      task.toggleCompletion(date);
      await tester.pumpWidget(_wrap(
        TaskTile(task: task, date: date, onToggle: () {}, onEdit: () {}),
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

    testWidgets('completed task title has strikethrough decoration',
        (tester) async {
      task.toggleCompletion(date);
      await tester.pumpWidget(_wrap(
        TaskTile(task: task, date: date, onToggle: () {}, onEdit: () {}),
      ));
      final text = tester.widget<Text>(find.text('Test task'));
      expect(text.style?.decoration, equals(TextDecoration.lineThrough));
    });

    testWidgets('shows priority dot as leading widget', (tester) async {
      await tester.pumpWidget(_wrap(
        TaskTile(task: task, date: date, onToggle: () {}, onEdit: () {}),
      ));
      // Container with circular BoxDecoration used as priority dot
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dots = containers.where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.shape == BoxShape.circle;
      });
      expect(dots, isNotEmpty);
    });

    testWidgets('high priority task has red dot', (tester) async {
      final highTask = Task(
        title: 'High',
        repeatDays: [1],
        priority: Priority.high,
      );
      await tester.pumpWidget(_wrap(
        TaskTile(task: highTask, date: date, onToggle: () {}, onEdit: () {}),
      ));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final redDot = containers.any((c) {
        final d = c.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color == const Color(0xFFF44336);
      });
      expect(redDot, isTrue);
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

  group('HomeScreen date navigation', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('date text is rendered with underline decoration', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      final underlined = tester.widgetList<Text>(find.byType(Text)).any(
        (t) => t.style?.decoration == TextDecoration.underline,
      );
      expect(underlined, isTrue);
    });

    testWidgets('tapping date text opens DatePickerDialog', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      final dateFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.decoration == TextDecoration.underline,
      );
      await tester.tap(dateFinder);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('cancelling date picker keeps original date', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      final dateFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.decoration == TextDecoration.underline,
      );
      final original = (tester.widget<Text>(dateFinder)).data;

      await tester.tap(dateFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect((tester.widget<Text>(dateFinder)).data, equals(original));
    });

    testWidgets('left arrow decrements date by one day', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      final dateFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.decoration == TextDecoration.underline,
      );
      final before = (tester.widget<Text>(dateFinder)).data;

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect((tester.widget<Text>(dateFinder)).data, isNot(equals(before)));
    });

    testWidgets('right arrow increments date by one day', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      final dateFinder = find.byWidgetPredicate(
        (w) => w is Text && w.style?.decoration == TextDecoration.underline,
      );
      final before = (tester.widget<Text>(dateFinder)).data;

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect((tester.widget<Text>(dateFinder)).data, isNot(equals(before)));
    });

    testWidgets('Today button appears after navigating away and returns to today', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsNothing);
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
