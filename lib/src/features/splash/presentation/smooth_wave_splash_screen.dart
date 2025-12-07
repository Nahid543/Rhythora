import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/root_shell.dart';

class SmoothWaveSplashScreen extends StatefulWidget {
  const SmoothWaveSplashScreen({super.key});

  @override
  State<SmoothWaveSplashScreen> createState() => _SmoothWaveSplashScreenState();
}

class _SmoothWaveSplashScreenState extends State<SmoothWaveSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _waveformController;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;

  Timer? _navigationTimer;

  static const _bgDark = Color(0xFF0A0A0F);
  static const _accentCyan = Color(0xFF00D1FF);
  static const _accentViolet = Color(0xFF7C5CFF);

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _initAnimations();
    _scheduleNavigation();
  }

  void _setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bgDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initAnimations() {
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _iconScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _ringScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _ringFade = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();
  }

  void _scheduleNavigation() {
    _navigationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RootShell(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final iconSize = size.width * 0.28;

    return Scaffold(
      backgroundColor: _bgDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _mainController,
          _pulseController,
          _waveformController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _accentViolet.withOpacity(0.08 * _iconFade.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconWithRings(iconSize),

                    SizedBox(height: size.height * 0.04),

                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Text(
                          'Rhythora',
                          style: TextStyle(
                            fontSize: size.width * 0.075,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeTransition(
                      opacity: _textFade,
                      child: _buildAudioWaveform(),
                    ),

                    const SizedBox(height: 16),

                    FadeTransition(
                      opacity: _textFade,
                      child: Text(
                        'Your music, your vibe',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIconWithRings(double iconSize) {
    return SizedBox(
      width: iconSize * 1.8,
      height: iconSize * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(2, (index) {
            final delay = index * 0.5;
            final adjustedScale = 1.0 + ((_ringScale.value - 1.0) * (1 - delay));
            final adjustedFade = _ringFade.value * (1 - delay * 0.5);

            return Transform.scale(
              scale: adjustedScale,
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accentCyan.withOpacity(adjustedFade * _iconFade.value),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),

          FadeTransition(
            opacity: _iconFade,
            child: ScaleTransition(
              scale: _iconScale,
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _accentCyan.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/app_icon.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Minimal audio waveform bars
  Widget _buildAudioWaveform() {
    const int barCount = 9;
    const double barWidth = 3.0;
    const double barSpacing = 4.0;
    const double minHeight = 4.0;
    const double maxHeight = 18.0;

    final List<double> pattern = [0.4, 0.7, 0.5, 0.9, 1.0, 0.9, 0.5, 0.7, 0.4];

    return SizedBox(
      height: maxHeight + 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (index) {
          final phaseOffset = index * 0.4;
          final waveValue = sin(
            (_waveformController.value * 2 * pi) + phaseOffset,
          );

          final heightMultiplier = pattern[index];
          final animatedHeight = minHeight +
              ((maxHeight - minHeight) * heightMultiplier * (0.5 + waveValue * 0.5));

          return Container(
            margin: EdgeInsets.symmetric(horizontal: barSpacing / 2),
            width: barWidth,
            height: animatedHeight.clamp(minHeight, maxHeight),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barWidth / 2),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  _accentCyan.withOpacity(0.9),
                  _accentViolet.withOpacity(0.9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentCyan.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
