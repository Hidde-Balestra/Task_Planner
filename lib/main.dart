import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/task_storage.dart';
import 'services/widget_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (uri?.host != 'toggle') return;

  final taskId = uri!.queryParameters['id'];
  final dateStr = uri.queryParameters['date'];
  if (taskId == null || dateStr == null) return;

  final date = DateTime.tryParse(dateStr);
  if (date == null) return;

  final tasks = await TaskStorage.loadTasks();
  final idx = tasks.indexWhere((t) => t.id == taskId);
  if (idx == -1) return;

  tasks[idx].toggleCompletion(date);
  await TaskStorage.saveTasks(tasks);
  await WidgetService.updateWidget(tasks, date);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.registerInteractivityCallback(backgroundCallback);
  await NotificationService.initialize();
  runApp(const TaskPlannerApp());
}

class TaskPlannerApp extends StatelessWidget {
  const TaskPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Planner',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
