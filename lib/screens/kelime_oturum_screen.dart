import 'package:flutter/material.dart';

import '../models/kelime_model.dart';
import '../services/kelime_session_service.dart';
import '../theme/app_theme.dart';
import 'kelime_liste_tab.dart';
import 'kelime_pratik_screen.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cPurple = Color(0xFF6C63FF);

class KelimeOturumScreen extends StatefulWidget {
  const KelimeOturumScreen({
    super.key,
    required this.sessionWords,
    required this.tumKelimeler,
    required this.sessionMod,
  });

  final List<KelimeModel> sessionWords;
  final List<KelimeModel> tumKelimeler;
  final KelimeZorlukModu sessionMod;

  @override
  State<KelimeOturumScreen> createState() => _KelimeOturumScreenState();
}

class _KelimeOturumScreenState extends State<KelimeOturumScreen> {
  bool _navigatingToTest = false;
  bool _testDevam = false;

  @override
  void initState() {
    super.initState();
    _loadPhase();
  }

  Future<void> _loadPhase() async {
    final snap = await KelimeSessionService.getActiveSession();
    if (!mounted) return;
    setState(() {
      _testDevam = snap?.phase == KelimeSessionPhase.test;
    });
  }

  Future<void> _goToTest() async {
    if (_navigatingToTest) return;
    _navigatingToTest = true;

    await KelimeSessionService.setPhase(KelimeSessionPhase.test);
    final shuffled = KelimeSessionService.shuffledForTest(widget.sessionWords);

    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => KelimePratikScreen(
          kelimeler: shuffled,
          tumKelimeler: widget.tumKelimeler,
          isSessionMode: true,
          sessionMod: widget.sessionMod,
        ),
      ),
    );
    if (mounted) {
      await _loadPhase();
      setState(() => _navigatingToTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.sessionWords.length;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Kelime Oturumu', subtitleFontSize: 14),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: _StepIndicator(activeStep: 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.sessionMod == KelimeZorlukModu.zor
                  ? 'Zor mod: Önce $count kelimeyi incele. Testte 10/10 yapmadan yeni kelimelere geçemezsin.'
                  : 'Önce $count kelimeyi incele, ardından aynı kelimelerden test çöz.',
              style: const TextStyle(color: _cMuted, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: widget.sessionWords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  KelimeListTile(kelime: widget.sessionWords[i]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: GestureDetector(
            onTap: _navigatingToTest ? null : _goToTest,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _navigatingToTest
                      ? const [Color(0xFF2D2050), Color(0xFF1A3040)]
                      : const [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _navigatingToTest
                    ? []
                    : [
                        BoxShadow(
                          color: _cPurple.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_navigatingToTest)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  else ...[
                    const Icon(Icons.quiz_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      _testDevam ? 'TESTE DEVAM ET' : 'TESTE GEÇ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepChip(
          step: 1,
          label: 'Liste',
          active: activeStep == 0,
          done: activeStep > 0,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: activeStep > 0
                ? _cPurple.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        _StepChip(
          step: 2,
          label: 'Test',
          active: activeStep == 1,
          done: false,
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.step,
    required this.label,
    required this.active,
    required this.done,
  });

  final int step;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active || done ? _cPurple : _cMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active || done
                ? _cPurple.withValues(alpha: 0.22)
                : const Color(0xFF233056),
            shape: BoxShape.circle,
            border: Border.all(
              color: active || done
                  ? _cPurple
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: _cPurple)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _cMuted,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
