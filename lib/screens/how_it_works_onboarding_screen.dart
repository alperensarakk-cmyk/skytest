import 'package:flutter/material.dart';

import '../data/app_mode_guides.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// Kelime Çalışması kartı ile aynı onboarding kart renkleri.
const _onboardingCardGradient = [Color(0xFF172554), Color(0xFF071B3A)];
const _onboardingCardAccent = Color(0xFF1D4ED8);

/// Splash sonrası kaydırmalı "Nasıl çalışır?" tanıtımı (yalnızca ilk açılış).
class HowItWorksOnboardingScreen extends StatefulWidget {
  const HowItWorksOnboardingScreen({super.key});

  @override
  State<HowItWorksOnboardingScreen> createState() =>
      _HowItWorksOnboardingScreenState();
}

class _HowItWorksOnboardingScreenState
    extends State<HowItWorksOnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.markHowItWorksSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const MainShell(),
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
  Widget build(BuildContext context) {
    final guides = kAppModeGuides;
    final isLast = _page == guides.length - 1;

    return Scaffold(
      backgroundColor: kBgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _finish,
                    icon: const Icon(Icons.close_rounded, color: kTextSecondary),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text(
                      'Atla',
                      style: TextStyle(
                        color: kTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline_rounded,
                          color: kAccent, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Nasıl çalışır?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kaydırarak dört çalışma modunu keşfet.',
                    style: TextStyle(
                      color: kTextSecondary.withValues(alpha: 0.95),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: guides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _GuidePageCard(guide: guides[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(guides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 10 : 8,
                    height: active ? 10 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? kAccent
                          : kAccent.withValues(alpha: 0.28),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: kAccent.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: isLast
                    ? _finish
                    : () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isLast ? 'Başla' : 'İleri',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePageCard extends StatelessWidget {
  const _GuidePageCard({required this.guide});

  final AppModeGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _onboardingCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(
          color: _onboardingCardAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Icon(guide.icon, color: _onboardingCardAccent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    guide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _onboardingCardAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    guide.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Text(
                guide.body,
                style: const TextStyle(
                  color: Color(0xFFCDD8EC),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
