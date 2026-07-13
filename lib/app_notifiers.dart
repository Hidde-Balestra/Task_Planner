import 'package:flutter/material.dart';

/// Reactive theme mode — updated by SettingsScreen, consumed by TaskPlannerApp.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
