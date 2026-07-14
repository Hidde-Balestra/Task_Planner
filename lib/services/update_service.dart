import 'dart:convert';
import 'dart:io';

class UpdateService {
  static const currentVersion = '1.5.3';
  static const releasesUrl =
      'https://github.com/Hidde-Balestra/Task_Planner/releases';

  /// Fetches the latest release tag from GitHub. Returns null on network error.
  static Future<String?> fetchLatestVersion() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(
        Uri.parse(
          'https://api.github.com/repos/Hidde-Balestra/Task_Planner/releases/latest',
        ),
      );
      request.headers.set('User-Agent', 'Task-Planner-App');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      // Strip leading 'v': "v1.6.0" → "1.6.0"
      return tag?.replaceFirst(RegExp(r'^v'), '');
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [latest] is strictly newer than [current] (semver compare).
  static bool isNewerVersion(String latest, String current) {
    List<int> parse(String v) =>
        v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
