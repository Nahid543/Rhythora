import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'src/app/rhythora_app.dart' show RhythoraApp, listeningStatsService;
import 'src/core/theme/theme_controller.dart' show themeController;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize JustAudio Background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.rhythora.player.audio.v2',
    androidNotificationChannelName: 'Rhythora Music',
    androidNotificationChannelDescription: 'Music playback controls',
    // Keep the notification ongoing so the service isn't killed while playing.
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    androidStopForegroundOnPause: false,
    preloadArtwork: true,
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
  );

  // Initialize listening stats service
  try {
    await listeningStatsService.initialize();
    debugPrint('✅ Listening stats service initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize listening stats: $e');
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Set preferred orientations (portrait only for better UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await themeController.loadThemeMode();

  runApp(const RhythoraApp());
}
