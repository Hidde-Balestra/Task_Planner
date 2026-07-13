import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_planner/services/settings_service.dart';

void main() {
  group('SettingsService - themeMode', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('loadThemeMode returns system by default', () async {
      expect(await SettingsService.loadThemeMode(), ThemeMode.system);
    });

    test('saveThemeMode light round-trips to light', () async {
      await SettingsService.saveThemeMode(ThemeMode.light);
      expect(await SettingsService.loadThemeMode(), ThemeMode.light);
    });

    test('saveThemeMode dark round-trips to dark', () async {
      await SettingsService.saveThemeMode(ThemeMode.dark);
      expect(await SettingsService.loadThemeMode(), ThemeMode.dark);
    });

    test('saveThemeMode system round-trips to system', () async {
      await SettingsService.saveThemeMode(ThemeMode.system);
      expect(await SettingsService.loadThemeMode(), ThemeMode.system);
    });

    test('unknown stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'invalid'});
      expect(await SettingsService.loadThemeMode(), ThemeMode.system);
    });

    test('switching from dark to light is persisted', () async {
      await SettingsService.saveThemeMode(ThemeMode.dark);
      await SettingsService.saveThemeMode(ThemeMode.light);
      expect(await SettingsService.loadThemeMode(), ThemeMode.light);
    });
  });

  group('SettingsService - vacationMode', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('loadVacationMode returns false by default', () async {
      expect(await SettingsService.loadVacationMode(), isFalse);
    });

    test('saveVacationMode true round-trips to true', () async {
      await SettingsService.saveVacationMode(true);
      expect(await SettingsService.loadVacationMode(), isTrue);
    });

    test('saveVacationMode false round-trips to false', () async {
      await SettingsService.saveVacationMode(true);
      await SettingsService.saveVacationMode(false);
      expect(await SettingsService.loadVacationMode(), isFalse);
    });

    test('initial value true is respected', () async {
      SharedPreferences.setMockInitialValues({'vacation_mode': true});
      expect(await SettingsService.loadVacationMode(), isTrue);
    });

    test('initial value false is respected', () async {
      SharedPreferences.setMockInitialValues({'vacation_mode': false});
      expect(await SettingsService.loadVacationMode(), isFalse);
    });
  });
}
