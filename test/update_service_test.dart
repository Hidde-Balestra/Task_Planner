import 'package:flutter_test/flutter_test.dart';
import 'package:task_planner/services/update_service.dart';

void main() {
  group('UpdateService - isNewerVersion', () {
    test('returns true when latest minor is higher', () {
      expect(UpdateService.isNewerVersion('1.6.0', '1.5.0'), isTrue);
    });

    test('returns true when latest patch is higher', () {
      expect(UpdateService.isNewerVersion('1.5.1', '1.5.0'), isTrue);
    });

    test('returns true when latest major is higher', () {
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('returns false when versions are equal', () {
      expect(UpdateService.isNewerVersion('1.5.0', '1.5.0'), isFalse);
    });

    test('returns false when latest is older minor', () {
      expect(UpdateService.isNewerVersion('1.4.0', '1.5.0'), isFalse);
    });

    test('returns false when latest is older patch', () {
      expect(UpdateService.isNewerVersion('1.5.0', '1.5.1'), isFalse);
    });

    test('returns false when latest is older major', () {
      expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isFalse);
    });

    test('handles missing patch segment', () {
      // "1.6" treated as "1.6.0"
      expect(UpdateService.isNewerVersion('1.6', '1.5.0'), isTrue);
    });

    test('handles non-numeric segment gracefully (treated as 0)', () {
      expect(UpdateService.isNewerVersion('1.5.x', '1.5.0'), isFalse);
    });
  });

  group('UpdateService - constants', () {
    test('currentVersion is a valid semver string', () {
      final parts = UpdateService.currentVersion.split('.');
      expect(parts.length, 3);
      for (final p in parts) {
        expect(int.tryParse(p), isNotNull, reason: 'Part "$p" is not numeric');
      }
    });

    test('releasesUrl points to the correct GitHub repo', () {
      expect(
        UpdateService.releasesUrl,
        contains('Hidde-Balestra/Task_Planner'),
      );
    });
  });
}
