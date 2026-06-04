import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/home_screen.dart';

@pragma('vm:entry-point')
void widgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Toggles are handled natively by TaskToggleReceiver.
  // This callback exists so home_widget can invoke Flutter for future use.
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);
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
