import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/rhythora_app.dart' show listeningStatsService;
import '../../../../core/theme/theme_controller.dart' show themeController;
import '../../../../core/services/battery_saver_service.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import '../widgets/sleep_timer_dialog.dart';
import '../widgets/stats_detail_screen.dart';
import '../widgets/export_dialog.dart';

enum DefaultScreen { home, library }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  bool _privacyMode = false;
  bool _isDarkMode = true;
  Duration? _sleepTimerDuration;
  DefaultScreen _defaultScreen = DefaultScreen.home;
  
  bool _batterySaverEnabled = false;
  bool _batterySaverAuto = true;
  int _batteryLevel = 100;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    BatterySaverService.instance.addListener(_onBatterySaverChanged);
  }

  @override
  void dispose() {
    BatterySaverService.instance.removeListener(_onBatterySaverChanged);
    super.dispose();
  }

  void _onBatterySaverChanged() {
    if (mounted) {
      setState(() {
        _batterySaverEnabled = BatterySaverService.instance.isEnabled;
        _batteryLevel = BatterySaverService.instance.batteryLevel;
      });
    }
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    final batterySaver = BatterySaverService.instance;

    setState(() {
      _privacyMode = _prefs.getBool('privacy_mode') ?? false;
      _isDarkMode = themeController.themeMode != ThemeMode.light;
      
      final defaultScreenValue = _prefs.getString('default_screen') ?? 'home';
      _defaultScreen = defaultScreenValue == 'library' 
          ? DefaultScreen.library 
          : DefaultScreen.home;
      
      _batterySaverEnabled = batterySaver.isEnabled;
      _batterySaverAuto = batterySaver.autoEnableOnLowBattery;
      _batteryLevel = batterySaver.batteryLevel;
      
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

    if (!mounted) return;

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

  Future<void> _toggleBatterySaver(bool value) async {
    HapticFeedback.lightImpact();
    await BatterySaverService.instance.toggle(value);
    
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              value ? Icons.battery_saver : Icons.battery_full_rounded,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(value ? 'Battery Saver enabled' : 'Battery Saver disabled'),
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

  Future<void> _toggleBatterySaverAuto(bool value) async {
    HapticFeedback.lightImpact();
    await BatterySaverService.instance.setAutoEnable(value);
    
    setState(() => _batterySaverAuto = value);
    
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_mode, size: 20),
            const SizedBox(width: 12),
            Text(value 
                ? 'Auto Battery Saver enabled' 
                : 'Auto Battery Saver disabled'),
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

  Future<void> _showDefaultScreenSelector() async {
    HapticFeedback.lightImpact();

    final result = await showModalBottomSheet<DefaultScreen>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Default screen',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<DefaultScreen>(
                    title: const Text('Home'),
                    subtitle: const Text('Start on Home screen (recommended)'),
                    secondary: Icon(
                      Icons.home_rounded,
                      color: _defaultScreen == DefaultScreen.home
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                    value: DefaultScreen.home,
                    groupValue: _defaultScreen,
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => _defaultScreen = value);
                      }
                    },
                  ),
                  RadioListTile<DefaultScreen>(
                    title: const Text('Library'),
                    subtitle: const Text('Start on Library screen'),
                    secondary: Icon(
                      Icons.library_music_rounded,
                      color: _defaultScreen == DefaultScreen.library
                          ? colorScheme.primary
                          : colorScheme.onSurface.withOpacity(0.6),
                    ),
                    value: DefaultScreen.library,
                    groupValue: _defaultScreen,
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => _defaultScreen = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, _defaultScreen),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await _updateDefaultScreen(result);
    }
  }

  Future<void> _updateDefaultScreen(DefaultScreen screen) async {
    HapticFeedback.mediumImpact();
    
    setState(() => _defaultScreen = screen);
    await _prefs.setString('default_screen', screen.name);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              screen == DefaultScreen.home
                  ? Icons.home_rounded
                  : Icons.library_music_rounded,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              screen == DefaultScreen.home
                  ? 'App will open on Home screen'
                  : 'App will open on Library screen',
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
      if (!mounted) return;

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
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

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

  String _defaultScreenSubtitle() {
    return _defaultScreen == DefaultScreen.home
        ? 'App opens on Home screen'
        : 'App opens on Library screen';
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
          SettingsSection(
            title: 'General',
            icon: Icons.tune_rounded,
            children: [
              SettingsTile(
                title: 'Default screen',
                subtitle: _defaultScreenSubtitle(),
                icon: _defaultScreen == DefaultScreen.home
                    ? Icons.home_rounded
                    : Icons.library_music_rounded,
                onTap: _showDefaultScreenSelector,
              ),
            ],
          ),

          const SizedBox(height: 8),

          SettingsSection(
            title: 'Appearance',
            icon: Icons.palette_rounded,
            children: [
              SettingsTile.switchTile(
                title: _isDarkMode ? 'Dark mode' : 'Light mode',
                subtitle:
                    _isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                icon: _isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                value: _isDarkMode,
                onChanged: _toggleDarkMode,
              ),
            ],
          ),

          const SizedBox(height: 8),

          SettingsSection(
            title: 'Playback',
            icon: Icons.play_circle_rounded,
            children: [
              SettingsTile(
                title: 'Sleep timer',
                subtitle: _sleepTimerDuration != null &&
                        _sleepTimerDuration!.inSeconds > 0
                    ? '${_sleepTimerDuration!.inMinutes} minutes remaining'
                    : 'Off',
                icon: Icons.bedtime_rounded,
                onTap: _showSleepTimerDialog,
              ),
            ],
          ),

          const SizedBox(height: 8),

          SettingsSection(
            title: 'Battery & Performance',
            icon: Icons.battery_saver,
            children: [
              SettingsTile.switchTile(
                title: 'Battery Saver',
                subtitle: _batterySaverEnabled
                    ? 'Reduces animations and background tasks'
                    : 'Normal performance mode',
                icon: _batterySaverEnabled 
                    ? Icons.battery_saver 
                    : Icons.battery_full_rounded,
                value: _batterySaverEnabled,
                onChanged: _toggleBatterySaver,
              ),
              SettingsTile.switchTile(
                title: 'Auto-enable on low battery',
                subtitle: _batterySaverAuto
                    ? 'Activates below 20% battery'
                    : 'Manual control only',
                icon: Icons.auto_mode,
                value: _batterySaverAuto,
                onChanged: _toggleBatterySaverAuto,
              ),
              SettingsTile(
                title: 'Current battery level',
                subtitle: '$_batteryLevel% ${BatterySaverService.instance.isCharging ? '(Charging)' : ''}',
                icon: _batteryLevel <= 20 
                    ? Icons.battery_alert_rounded 
                    : _batteryLevel <= 50 
                        ? Icons.battery_3_bar_rounded 
                        : Icons.battery_full_rounded,
                iconColor: _batteryLevel <= 20 ? colorScheme.error : null,
              ),
            ],
          ),

          const SizedBox(height: 8),

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
                icon:
                    _privacyMode ? Icons.lock_rounded : Icons.lock_open_rounded,
                value: _privacyMode,
                onChanged: _togglePrivacyMode,
              ),
            ],
          ),

          const SizedBox(height: 8),

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
