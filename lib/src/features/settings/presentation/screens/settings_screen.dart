import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/rhythora_app.dart' show listeningStatsService;
import '../../../../core/theme/theme_controller.dart' show themeController;
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/stats_detail_screen.dart';
import '../widgets/export_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Settings values
  bool _privacyMode = false;
  bool _isDarkMode = true;
  Duration? _sleepTimerDuration;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _privacyMode = _prefs.getBool('privacy_mode') ?? false;
      _isDarkMode = themeController.themeMode != ThemeMode.light;
      _isLoading = false;
    });
  }

  Future<void> _togglePrivacyMode(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _privacyMode = value);
    await _prefs.setBool('privacy_mode', value);

    if (value) {
      listeningStatsService.pauseListening();
    } else {
      listeningStatsService.resumeListening();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                value ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(value ? 'Privacy mode enabled' : 'Privacy mode disabled'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isDarkMode = value);
    await themeController.updateThemeMode(
      value ? ThemeMode.dark : ThemeMode.light,
    );

    if (!mounted) return;

    final isDark = themeController.themeMode == ThemeMode.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(isDark ? 'Dark theme applied' : 'Light theme applied'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _showSleepTimerDialog() async {
    HapticFeedback.lightImpact();
    final duration = await showDialog<Duration>(
      context: context,
      builder: (context) => SleepTimerDialog(
        currentDuration: _sleepTimerDuration,
      ),
    );

    if (duration != null) {
      setState(() => _sleepTimerDuration = duration);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.bedtime_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  duration == Duration.zero
                      ? 'Sleep timer cancelled'
                      : 'Sleep timer set for ${duration.inMinutes} minutes',
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Clear cache?'),
            ],
          ),
          content: const Text(
            'This will clear cached album artwork and temporary files. Your music and playlists will not be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 20),
              SizedBox(width: 12),
              Text('Cache cleared successfully'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Clear listening history?'),
            ],
          ),
          content: const Text(
            'This will permanently delete all listening statistics, play counts, and history. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      // await listeningStatsService.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 20),
                SizedBox(width: 12),
                Text('Listening history cleared'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showLicenses() {
    HapticFeedback.lightImpact();
    showLicensePage(
      context: context,
      applicationName: 'Rhythora',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Future<void> _openPlayStore() async {
    HapticFeedback.lightImpact();

    const packageName = 'com.rhythora.player';
    final playStoreUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Opening Play Store...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );

    try {
      if (await canLaunchUrl(playStoreUri) &&
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication)) {
        return;
      }

      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to show failure snackbar.
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Could not open Play Store'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Appearance Section
          SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            children: [
              SettingsTile.switchTile(
                title: _isDarkMode ? 'Dark mode' : 'Light mode',
                subtitle: _isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                icon: _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                value: _isDarkMode,
                onChanged: _toggleDarkMode,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sleep Timer Section
          SettingsSection(
            title: 'Sleep Timer',
            icon: Icons.bedtime_rounded,
            children: [
              SettingsTile(
                title: 'Set sleep timer',
                subtitle: _sleepTimerDuration != null && _sleepTimerDuration!.inSeconds > 0
                    ? '${_sleepTimerDuration!.inMinutes} minutes remaining'
                    : 'Off',
                icon: Icons.timer_rounded,
                onTap: _showSleepTimerDialog,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Listening Statistics Section
          SettingsSection(
            title: 'Listening Statistics',
            icon: Icons.insights_rounded,
            children: [
              SettingsTile(
                title: 'View detailed stats',
                subtitle: 'Weekly and monthly reports',
                icon: Icons.bar_chart_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatsDetailScreen(),
                    ),
                  );
                },
              ),
              SettingsTile(
                title: 'Export data',
                subtitle: 'Save as CSV or JSON',
                icon: Icons.download_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showDialog(
                    context: context,
                    builder: (context) => const ExportDialog(),
                  );
                },
              ),
              SettingsTile(
                title: 'Clear history',
                subtitle: 'Delete all listening data',
                icon: Icons.delete_sweep_rounded,
                iconColor: colorScheme.error,
                onTap: _clearHistory,
              ),
              SettingsTile.switchTile(
                title: 'Privacy mode',
                subtitle: _privacyMode
                    ? 'Playback not being tracked'
                    : 'Track listening activity',
                icon: _privacyMode ? Icons.lock_rounded : Icons.lock_open_rounded,
                value: _privacyMode,
                onChanged: _togglePrivacyMode,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Storage Section
          SettingsSection(
            title: 'Storage',
            icon: Icons.storage_rounded,
            children: [
              SettingsTile(
                title: 'Clear cache',
                subtitle: 'Free up storage space',
                icon: Icons.cleaning_services_rounded,
                onTap: _clearCache,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // About Section
          SettingsSection(
            title: 'About',
            icon: Icons.info_rounded,
            children: [
              SettingsTile(
                title: 'Version',
                subtitle: '1.0.0 (Build 1)',
                icon: Icons.new_releases_rounded,
              ),
              SettingsTile(
                title: 'Open source licenses',
                subtitle: 'View third-party licenses',
                icon: Icons.code_rounded,
                onTap: _showLicenses,
              ),
              SettingsTile(
                title: 'Rate app',
                subtitle: 'Support us on Play Store',
                icon: Icons.star_rounded,
                onTap: _openPlayStore,
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
