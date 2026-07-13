import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_notifiers.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/task_storage.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vacationMode = false;
  bool _loading = true;

  // Update state
  bool _checkingUpdate = false;
  String? _latestVersion;
  bool _updateError = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkForUpdate();
  }

  Future<void> _load() async {
    final vacation = await SettingsService.loadVacationMode();
    if (mounted) {
      setState(() {
        _vacationMode = vacation;
        _loading = false;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = false;
    });
    final latest = await UpdateService.fetchLatestVersion();
    if (mounted) {
      setState(() {
        _checkingUpdate = false;
        _latestVersion = latest;
        _updateError = latest == null;
      });
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    await SettingsService.saveThemeMode(mode);
  }

  Future<void> _setVacationMode(bool enabled) async {
    setState(() => _vacationMode = enabled);
    await SettingsService.saveVacationMode(enabled);
    if (enabled) {
      await NotificationService.cancelAll();
    } else {
      final tasks = await TaskStorage.loadTasks();
      await NotificationService.rescheduleAll(tasks);
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.sendTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test melding verstuurd — controleer de notificatiebalk'),
      ),
    );
  }

  Future<void> _backup() async {
    try {
      final tasks = await TaskStorage.loadTasks();
      final path = await BackupService.backup(tasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup opgeslagen: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup mislukt')),
      );
    }
  }

  Future<void> _restore() async {
    try {
      final restored = await BackupService.restore();
      if (!mounted) return;
      if (restored != null) {
        await TaskStorage.saveTasks(restored);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup hersteld')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen backupbestand gevonden')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Herstellen mislukt')),
      );
    }
  }

  Widget _buildUpdateTile() {
    if (_checkingUpdate) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Controleren op updates…'),
      );
    }

    if (_updateError || _latestVersion == null) {
      return ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: const Text('Kan updates niet controleren'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Opnieuw proberen',
          onPressed: _checkForUpdate,
        ),
      );
    }

    final hasUpdate = UpdateService.isNewerVersion(
      _latestVersion!,
      UpdateService.currentVersion,
    );

    if (hasUpdate) {
      return ListTile(
        leading: Icon(
          Icons.system_update,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text('Versie $_latestVersion beschikbaar'),
        subtitle: const Text('Tik om te downloaden'),
        onTap: () => launchUrl(
          Uri.parse(UpdateService.releasesUrl),
          mode: LaunchMode.externalApplication,
        ),
      );
    }

    return ListTile(
      leading: Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: const Text('Je hebt de nieuwste versie'),
      trailing: IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Opnieuw controleren',
        onPressed: _checkForUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: ListView(
        children: [
          // --- Uiterlijk ---
          _SectionHeader('Uiterlijk'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeMode,
              builder: (_, mode, __) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Systeem'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Licht'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Donker'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (val) => _setTheme(val.first),
              ),
            ),
          ),

          // --- Meldingen ---
          _SectionHeader('Meldingen'),
          SwitchListTile(
            title: const Text('Vakantie-modus'),
            subtitle: Text(
              _vacationMode
                  ? 'Alle meldingen zijn uitgeschakeld'
                  : 'Meldingen zijn ingeschakeld',
            ),
            secondary: Icon(
              _vacationMode ? Icons.beach_access : Icons.notifications_active,
            ),
            value: _vacationMode,
            onChanged: _setVacationMode,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Test melding'),
            subtitle: const Text('Controleer of meldingen werken'),
            trailing: FilledButton.tonal(
              onPressed: _sendTestNotification,
              child: const Text('Verstuur'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Android kan meldingen automatisch stoppen',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Als je de app langere tijd niet opent, '
                            'pauzeert Android meldingen automatisch. '
                            'Ga naar Instellingen > Apps > Task Planner > '
                            'Ongebruikte app-instellingen en zet '
                            '"App pauzeren bij inactiviteit" uit.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Over ---
          _SectionHeader('Over'),
          ListTile(
            leading: const Icon(Icons.tag),
            title: const Text('Huidige versie'),
            trailing: Text(
              UpdateService.currentVersion,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _buildUpdateTile(),

          // --- Gegevens ---
          _SectionHeader('Gegevens'),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Exporteer taken'),
            subtitle: const Text('Sla een backup op'),
            onTap: _backup,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Importeer taken'),
            subtitle: const Text('Herstel vanuit backup'),
            onTap: _restore,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
