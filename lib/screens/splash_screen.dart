import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import 'how_it_works_onboarding_screen.dart';
import 'main_shell.dart';

/// Premium açılış ekranı (Material 3):
/// • Ana ekran ile aynı arka plan (kBgPrimary)
/// • Logo: 0.92 → 1.00 ölçek + fade-in (700 ms)
/// • Arkadaki parıltı yumuşakça "nefes alır" (breathing)
/// • Spinner yerine altta üç animasyonlu nokta
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  late final AnimationController _textCtrl;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _subFade;
  late final Animation<double> _subSlide;

  late final AnimationController _breatheCtrl;
  late final AnimationController _dotsCtrl;

  bool _navigated = false;

  static const Color _glowBlue = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _titleFade = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );
    _subFade = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _subSlide = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    );

    _entranceCtrl.forward();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _textCtrl.forward();
    });
    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _navigated) return;
    _navigated = true;

    _breatheCtrl.stop();
    _dotsCtrl.stop();

    final showGuide = await OnboardingService.shouldShowHowItWorks();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => showGuide
            ? const HowItWorksOnboardingScreen()
            : const MainShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _textCtrl.dispose();
    _breatheCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgPrimary,
      body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_entranceCtrl, _breatheCtrl]),
                    builder: (context, _) {
                      final breathe = _breatheCtrl.value;
                      return SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: _fade.value,
                              child: Transform.scale(
                                scale: 0.94 + 0.10 * breathe,
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        _glowBlue.withValues(
                                          alpha: 0.20 + 0.14 * breathe,
                                        ),
                                        _glowBlue.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.72],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: _fade.value,
                              child: Transform.scale(
                                scale: _scale.value,
                                child: Image.asset(
                                  'assets/branding/logo_mark.png',
                                  width: 124,
                                  height: 124,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _titleFade.value,
                            child: Transform.translate(
                              offset:
                                  Offset(0, -18 * (1 - _titleSlide.value)),
                              child: const Text(
                                'AeroTest',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _subFade.value,
                            child: Transform.translate(
                              offset: Offset(0, -18 * (1 - _subSlide.value)),
                              child: Text(
                                'SHGM Sınav Hazırlık Uygulaması',
                                style: TextStyle(
                                  color: kAccent.withValues(alpha: 0.9),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_entranceCtrl, _dotsCtrl]),
                  builder: (context, _) {
                    return Opacity(
                      opacity: _fade.value,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final phase = _dotsCtrl.value * 2 * math.pi -
                              i * (math.pi / 2.4);
                          final wave = (math.sin(phase) + 1) / 2;
                          final opacity = 0.30 + 0.70 * wave;
                          final scale = 0.78 + 0.34 * wave;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kAccent.withValues(alpha: opacity),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
    );
  }
}
