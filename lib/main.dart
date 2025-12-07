import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'src/app/rhythora_app.dart' show RhythoraApp, listeningStatsService;
import 'src/core/theme/theme_controller.dart' show themeController;
import 'src/core/services/battery_saver_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  try {
    await listeningStatsService.initialize();
    debugPrint('✅ Listening stats service initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize listening stats: $e');
  }

  try {
    await BatterySaverService.instance.initialize();
    debugPrint('✅ Battery Saver service initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize Battery Saver: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await themeController.loadThemeMode();

  runApp(const RhythoraApp());
}
