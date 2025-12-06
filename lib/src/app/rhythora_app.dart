import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/home/domain/services/listening_stats_service.dart';
import '../features/splash/presentation/smooth_wave_splash_screen.dart';

final listeningStatsService = ListeningStatsService();

class RhythoraApp extends StatelessWidget {
  const RhythoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Rhythora',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          // start on animated splash instead of RootShell
          home: const SmoothWaveSplashScreen(),
        );
      },
    );
  }
}
