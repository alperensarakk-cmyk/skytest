import 'package:flutter/material.dart';

import '../models/kelime_model.dart';
import '../services/daily_limit_service.dart';
import '../services/kelime_service.dart';
import '../services/kelime_session_service.dart';
import '../services/kelime_yanlis_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layers.dart';
import '../theme/figma_home_layout.dart';
import '../theme/figma_home_typography.dart';
import '../widgets/limit_exceeded_dialog.dart';
import 'kelime_oturum_screen.dart';
import 'kelime_yanlislarim_screen.dart';

/// Scroll içinde güvenli Figma yüzeyi (`StackFit.expand` kullanmaz).
class _FigmaPanel extends StatelessWidget {
  const _FigmaPanel({
    required this.layers,
    required this.child,
  });

  final FigmaCardLayers layers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = layers.cornerRadius;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        gradient: layers.baseGradient,
        border: Border.all(
          color: layers.strokeColor.withValues(alpha: layers.strokeOpacity),
          width: layers.strokeWeight,
        ),
        boxShadow: layers.shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: layers.overlayColor != null &&
                (layers.overlayOpacity ?? 0) > 0
            ? ColoredBox(
                color: layers.overlayColor!.withValues(
                  alpha: layers.overlayOpacity!,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

class KelimeScreen extends StatefulWidget {
  const KelimeScreen({super.key});

  @override
  State<KelimeScreen> createState() => _KelimeScreenState();
}

class _KelimeScreenState extends State<KelimeScreen> {
  List<KelimeModel>? _tumKelimeler;
  int _kelimeYanlisCount = 0;
  bool _loading = true;
  bool _premium = false;
  KelimeSessionSnapshot? _activeSession;
  int _sessionsRemaining = 1;
  KelimeZorlukModu _zorlukMod = KelimeZorlukModu.kolay;
  int _kolayOturumBoyutu = KelimeSessionService.kolaySizeMin;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final kelimeler = await KelimeService.loadAll();
    final yanlisCount = await KelimeYanlisService.getCountAsync();
    final premium = await PremiumService.isPremiumUser();
    final active = await KelimeSessionService.getActiveSession();
    final preferredMod = await KelimeSessionService.getPreferredMod();
    final kolaySize = await KelimeSessionService.getPreferredKolaySize();
    var remSessions = 999999;
    if (!premium) {
      remSessions = await DailyLimitService.kelimeSessionsRemaining();
    }
    if (!mounted) return;
    setState(() {
      _tumKelimeler = kelimeler;
      _kelimeYanlisCount = yanlisCount;
      _premium = premium;
      _activeSession = active;
      _sessionsRemaining = remSessions;
      _zorlukMod = active?.mod ?? preferredMod;
      _kolayOturumBoyutu =
          premium ? kolaySize : KelimeSessionService.kolaySizeMin;
      _loading = false;
    });
  }

  Future<bool> _confirmAbandonSession(String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Oturumu sonlandır?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oturumu sonlandır',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _abandonActiveSession() async {
    final modLabel =
        _activeSession?.mod == KelimeZorlukModu.zor ? 'zor' : 'kolay';
    final ok = await _confirmAbandonSession(
      'Devam eden $modLabel mod oturumun silinecek. '
      'Mod veya oturum boyutunu değiştirebilirsin.',
    );
    if (!ok || !mounted) return;
    await KelimeSessionService.abandonSession();
    await _loadData();
  }

  Future<void> _selectMod(KelimeZorlukModu mod) async {
    if (_activeSession != null && _activeSession!.mod != mod) {
      final hedef = mod == KelimeZorlukModu.zor ? 'zor' : 'kolay';
      final ok = await _confirmAbandonSession(
        'Devam eden oturumu sonlandırıp $hedef moda geçmek istiyor musun?',
      );
      if (!ok || !mounted) return;
      await KelimeSessionService.abandonSession();
    }
    setState(() => _zorlukMod = mod);
    await KelimeSessionService.setPreferredMod(mod);
    await _loadData();
  }

  Future<void> _selectKolaySize(int size) async {
    if (!_premium && size > KelimeSessionService.kolaySizeMin) return;
    if (_activeSession != null) {
      final ok = await _confirmAbandonSession(
        'Oturum boyutunu değiştirmek için mevcut oturumu sonlandırman gerekir.',
      );
      if (!ok || !mounted) return;
      await KelimeSessionService.abandonSession();
    }
    setState(() => _kolayOturumBoyutu = size);
    await KelimeSessionService.setPreferredKolaySize(size);
    await _loadData();
  }

  Future<void> _oturumBaslat() async {
    if (_tumKelimeler == null) return;
    await DailyLimitService.ensureDay();

    try {
      final snap = await KelimeSessionService.startOrResume(
        _tumKelimeler!,
        mod: _zorlukMod,
        kolaySize: _kolayOturumBoyutu,
      );
      final words =
          KelimeSessionService.resolveWords(_tumKelimeler!, snap.wordIds);
      if (words.isEmpty) return;

      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => KelimeOturumScreen(
            sessionWords: words,
            tumKelimeler: _tumKelimeler!,
            sessionMod: snap.mod,
          ),
        ),
      );
      await _loadData();
    } on KelimeSessionLimitException {
      if (mounted) await showDailyLimitExceededDialog(context);
    }
  }

  String get _startLabel {
    if (_activeSession != null) return 'OTURUMA DEVAM ET';
    return 'OTURUMA BAŞLA';
  }

  bool get _canStart =>
      _premium || _sessionsRemaining > 0 || _activeSession != null;

  @override
  Widget build(BuildContext context) {
    final s = figmaHomeScale(context);

    return Scaffold(
      backgroundColor: kBgPrimary,
      appBar: AppBar(
        backgroundColor: kBgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Kelime Çalışması', subtitleFontSize: 18),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 16 * s),
          child: FilledButton.icon(
            onPressed: _loading || !_canStart ? null : _oturumBaslat,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(_startLabel),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgGradientTop, kBgGradientBottom],
          ),
        ),
        child: _loading || _tumKelimeler == null
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    padding: EdgeInsets.only(bottom: 24 * s),
                    children: [
                      _KelimeHero(
                        scale: s,
                        width: constraints.maxWidth,
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          kHomePaddingH * s,
                          16 * s,
                          kHomePaddingH * s,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_activeSession != null) ...[
                              _ActiveSessionBanner(
                                scale: s,
                                session: _activeSession!,
                                onAbandon: _abandonActiveSession,
                              ),
                              SizedBox(height: 12 * s),
                            ],
                            _SessionSetupCard(
                              scale: s,
                              mod: _zorlukMod,
                              kolaySize: _kolayOturumBoyutu,
                              premium: _premium,
                              sessionsRemaining: _sessionsRemaining,
                              hasActive: _activeSession != null,
                              onMod: _selectMod,
                              onSize: _selectKolaySize,
                            ),
                            SizedBox(height: 12 * s),
                            _YanlisRow(
                              scale: s,
                              count: _kelimeYanlisCount,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const KelimeYanlislarimScreen(),
                                ),
                              ).then((_) => _loadData()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

// ─── Ana sayfa hero (PNG + overlay + karşılama) ───────────────────────────────

class _KelimeHero extends StatelessWidget {
  const _KelimeHero({
    required this.scale,
    required this.width,
  });

  final double scale;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final heroH = FigmaHomeLayout.heroH * s;
    final gradUp = FigmaHeroLayout.gradientExtendUp * s;

    return SizedBox(
      width: width,
      height: heroH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: heroH,
            child: FigmaImageFill.hero(
              asset: 'assets/home/hero_bg.png',
              width: width,
              height: heroH,
              m00: FigmaHeroLayout.imageM00,
              m01: FigmaHeroLayout.imageM01,
              m02: FigmaHeroLayout.imageM02,
              m10: FigmaHeroLayout.imageM10,
              m11: FigmaHeroLayout.imageM11,
              m12: FigmaHeroLayout.imageM12,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -gradUp,
            height: heroH + gradUp,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: kFigmaGradHeroOverlay,
              ),
            ),
          ),
          Positioned(
            left: 16 * s,
            top: 12 * s,
            right: width * 0.38,
            child: Text(
              'Önce ezberle, sonra test et.',
              style: FigmaHomeTypography.heroTitle(s),
              maxLines: 2,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Devam eden oturum ───────────────────────────────────────────────────────

class _ActiveSessionBanner extends StatelessWidget {
  const _ActiveSessionBanner({
    required this.scale,
    required this.session,
    required this.onAbandon,
  });

  final double scale;
  final KelimeSessionSnapshot session;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final zor = session.mod == KelimeZorlukModu.zor;
    final phaseLabel = session.phase == KelimeSessionPhase.test
        ? 'Test'
        : 'Liste';

    return _FigmaPanel(
      layers: kFigmaLayersCountdown,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 8 * s, 12 * s),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline_rounded,
                color: kAccentTeal, size: 22 * s),
            SizedBox(width: 10 * s),
            Expanded(
              child: Text(
                '${zor ? 'Zor' : 'Kolay'} · ${session.wordIds.length} kelime · $phaseLabel',
                style: FigmaHomeTypography.studySubAccent(s),
              ),
            ),
            TextButton(
              onPressed: onAbandon,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF8A80),
                padding: EdgeInsets.symmetric(horizontal: 8 * s),
                minimumSize: Size(0, 32 * s),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Sonlandır',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5 * s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tek kurulum kartı (Figma kelime yüzeyi) ─────────────────────────────────

class _SessionSetupCard extends StatelessWidget {
  const _SessionSetupCard({
    required this.scale,
    required this.mod,
    required this.kolaySize,
    required this.premium,
    required this.sessionsRemaining,
    required this.hasActive,
    required this.onMod,
    required this.onSize,
  });

  final double scale;
  final KelimeZorlukModu mod;
  final int kolaySize;
  final bool premium;
  final int sessionsRemaining;
  final bool hasActive;
  final ValueChanged<KelimeZorlukModu> onMod;
  final ValueChanged<int> onSize;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final zor = mod == KelimeZorlukModu.zor;
    final tip = zor
        ? 'Yeni kelimelere geçmek için testte 10/10 gerekir.'
        : 'Yanlışların olsa da oturumu tamamlayabilirsin.';

    String? statusLine;
    if (!premium) {
      if (sessionsRemaining <= 0 && !hasActive) {
        statusLine = 'Bugünlük ücretsiz hakkın doldu';
      } else if (hasActive) {
        statusLine = 'Ayar değiştirmek için oturumu sonlandır';
      } else {
        statusLine = 'Ücretsiz · günde 1 oturum · 10 kelime';
      }
    } else if (hasActive) {
      statusLine = 'Ayar değiştirmek için oturumu sonlandır';
    }

    return _FigmaPanel(
      layers: kFigmaLayersKelime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140 * s,
            child: Stack(
              children: [
                Positioned(
                  right: 4 * s,
                  bottom: 0,
                  width: 132 * s,
                  height: 132 * s,
                  child: Image.asset(
                    'assets/home/card_kelime.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * s, 22 * s, 110 * s, 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oturum',
                        style: FigmaHomeTypography.studyTitle(s * 1.05),
                      ),
                      SizedBox(height: 8 * s),
                      Text(
                        tip,
                        style: FigmaHomeTypography.studySubAccent(s),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16 * s, 4 * s, 16 * s, 20 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zorluk', style: FigmaHomeTypography.countdownLabel(s)),
                SizedBox(height: 10 * s),
                Row(
                  children: [
                    Expanded(
                      child: _ModChip(
                        scale: s,
                        label: 'Kolay',
                        selected: !zor,
                        onTap: () => onMod(KelimeZorlukModu.kolay),
                      ),
                    ),
                    SizedBox(width: 8 * s),
                    Expanded(
                      child: _ModChip(
                        scale: s,
                        label: 'Zor',
                        selected: zor,
                        onTap: () => onMod(KelimeZorlukModu.zor),
                      ),
                    ),
                  ],
                ),
                if (premium && !zor) ...[
                  SizedBox(height: 16 * s),
                  Text(
                    'Oturum boyutu',
                    style: FigmaHomeTypography.countdownLabel(s),
                  ),
                  SizedBox(height: 8 * s),
                  Wrap(
                    spacing: 8 * s,
                    runSpacing: 8 * s,
                    children: [
                      for (final v in KelimeSessionService.kolaySizeOptions)
                        _SizeChip(
                          scale: s,
                          label: '$v',
                          selected: kolaySize == v,
                          onTap: () => onSize(v),
                        ),
                    ],
                  ),
                ],
                if (statusLine != null) ...[
                  SizedBox(height: 14 * s),
                  Text(
                    statusLine,
                    style: FigmaHomeTypography.studySubKonular(s),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModChip extends StatelessWidget {
  const _ModChip({
    required this.scale,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double scale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 12 * s),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF93C5FD).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : kTextSecondary,
              fontSize: 14 * s,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.scale,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double scale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 9 * s),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF93C5FD).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : kTextSecondary,
              fontSize: 13 * s,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Yanlışlar satırı ────────────────────────────────────────────────────────

class _YanlisRow extends StatelessWidget {
  const _YanlisRow({
    required this.scale,
    required this.count,
    required this.onTap,
  });

  final double scale;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final hasYanlis = count > 0;

    return Opacity(
      opacity: hasYanlis ? 1 : 0.55,
      child: _FigmaPanel(
        layers: kFigmaLayersStats,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasYanlis ? onTap : null,
            borderRadius: BorderRadius.circular(kFigmaLayersStats.cornerRadius),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
              child: Row(
                children: [
                  Icon(
                    Icons.replay_rounded,
                    color: const Color(0xFFFF8A80),
                    size: 20 * s,
                  ),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      hasYanlis
                          ? 'Yanlış kelimeler · $count'
                          : 'Yanlış kelime yok',
                      style: FigmaHomeTypography.studyTitle(s * 0.88),
                    ),
                  ),
                  if (hasYanlis)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 14 * s,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
