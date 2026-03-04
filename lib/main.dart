import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'src/app/rhythora_app.dart' show RhythoraApp, listeningStatsService;
import 'src/core/theme/theme_controller.dart' show themeController;
import 'src/core/services/battery_saver_service.dart';
import 'src/features/library/data/local_music_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Critical: Audio background service must init before runApp
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.rhythora.player.audio.v2',
    androidNotificationChannelName: 'Rhythora Music',
    androidNotificationChannelDescription: 'Music playback controls',
    androidNotificationOngoing: false,
    androidShowNotificationBadge: false,
    androidStopForegroundOnPause: true,
    preloadArtwork: true,
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
  );

  // Set UI overlays (non-blocking)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Theme must load before first frame for correct colors
  await themeController.loadThemeMode();

  // Launch app ASAP — gives Android a focused window, prevents ANR
  runApp(const RhythoraApp());

  // Defer non-critical services to after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Run these in parallel since they're independent
    await Future.wait([
      _initListeningStats(),
      _initBatterySaver(),
      _initArtworkCache(),
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    ]);
  });
}

Future<void> _initListeningStats() async {
  try {
    await listeningStatsService.initialize();
    debugPrint('✅ Listening stats service initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize listening stats: $e');
  }
}

Future<void> _initBatterySaver() async {
  try {
    await BatterySaverService.instance.initialize();
    debugPrint('✅ Battery Saver service initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize Battery Saver: $e');
  }
}

Future<void> _initArtworkCache() async {
  try {
    await LocalMusicLoader.instance.warmUpCacheDir();
    debugPrint('✅ Artwork cache directory warmed up');
  } catch (e) {
    debugPrint('⚠️ Failed to warm up artwork cache: $e');
  }
}
