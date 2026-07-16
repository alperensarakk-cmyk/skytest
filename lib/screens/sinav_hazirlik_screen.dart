import 'package:flutter/material.dart';

import '../services/daily_limit_service.dart';
import '../services/istatistik_service.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../services/yanlis_service.dart';
import '../services/zayif_konu_service.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layers.dart';
import '../theme/figma_home_layout.dart';
import '../theme/figma_home_typography.dart';
import '../widgets/limit_exceeded_dialog.dart';
import '../widgets/zayif_konular_panel.dart';
import 'yanlislarim_screen.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cRed = Color(0xFFFF6B6B);

enum _AcikAyar { none, soru, sure }

/// Scroll içinde güvenli Figma yüzeyi.
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
        child: layers.overlayColor != null && (layers.overlayOpacity ?? 0) > 0
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

class SinavHazirlikScreen extends StatefulWidget {
  const SinavHazirlikScreen({super.key});

  @override
  State<SinavHazirlikScreen> createState() => _SinavHazirlikScreenState();
}

class _SinavHazirlikScreenState extends State<SinavHazirlikScreen> {
  int _soruSayisi = 30;
  int _sureDak = 30;
  int _yanlisCount = 0;
  ZayifKonuOzet _zayifOzet = const ZayifKonuOzet(
    konular: [],
    toplamCevaplanan: 0,
    minGerekli: ZayifKonuService.minToplamCevaplanan,
  );
  bool _loading = true;
  _AcikAyar _acikAyar = _AcikAyar.none;

  static const _soruSecenekleri = [10, 20, 30, 40, 50, 60, 80];
  static const _sureSecenekleri = [10, 20, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final q = await SettingsService.getExamQuestionCount();
    final d = await SettingsService.getExamDurationMin();
    final y = await YanlisService.getCountAsync();
    final z = await IstatistikService.getZayifKonuOzet();
    if (!mounted) return;
    setState(() {
      _soruSayisi = q;
      _sureDak = d;
      _yanlisCount = y;
      _zayifOzet = z;
      _loading = false;
    });
  }

  Future<void> _baslat() async {
    await DailyLimitService.ensureDay();
    var soru = _soruSayisi;
    if (!await PremiumService.isPremiumUser()) {
      final rem = await DailyLimitService.examQuestionsRemaining();
      if (rem <= 0) {
        if (mounted) await showDailyLimitExceededDialog(context);
        return;
      }
      if (soru > rem) {
        soru = rem;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ücretsiz planda bugün en fazla $rem sınav sorusu çözebilirsin.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    await SettingsService.setExamQuestionCount(soru);
    await SettingsService.setExamDurationMin(_sureDak);
    if (!mounted) return;
    Navigator.pushNamed(context, '/sinav').then((_) => _loadData());
  }

  void _toggleAyar(_AcikAyar tip) {
    setState(() {
      _acikAyar = _acikAyar == tip ? _AcikAyar.none : tip;
    });
  }

  void _openYanlislar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YanlislarimScreen()),
    ).then((_) => _loadData());
  }

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
        title: buildAeroTestAppBarTitle('Sınav Modu', subtitleFontSize: 18),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 16 * s),
          child: FilledButton.icon(
            onPressed: _loading ? null : _baslat,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text('SINAVA BAŞLA  ($_soruSayisi soru · $_sureDak dk)'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    padding: EdgeInsets.only(bottom: 24 * s),
                    children: [
                      _SinavHero(
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
                            _IntroCard(scale: s),
                            SizedBox(height: 12 * s),
                            _AyarlarCard(
                              scale: s,
                              soruSayisi: _soruSayisi,
                              sureDak: _sureDak,
                              acikAyar: _acikAyar,
                              soruSecenekleri: _soruSecenekleri,
                              sureSecenekleri: _sureSecenekleri,
                              onToggle: _toggleAyar,
                              onSoru: (v) => setState(() {
                                _soruSayisi = v;
                                _acikAyar = _AcikAyar.none;
                              }),
                              onSure: (v) => setState(() {
                                _sureDak = v;
                                _acikAyar = _AcikAyar.none;
                              }),
                            ),
                            SizedBox(height: 12 * s),
                            _YanlisRow(
                              scale: s,
                              count: _yanlisCount,
                              onTap: _openYanlislar,
                            ),
                            SizedBox(height: 12 * s),
                            ZayifKonularPanel(
                              ozet: _zayifOzet,
                              onAnalizCleared: _loadData,
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

// ─── Hero ────────────────────────────────────────────────────────────────────

class _SinavHero extends StatelessWidget {
  const _SinavHero({
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
              'Gerçek sınav temposunu dene.',
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

// ─── Giriş kartı ─────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return _FigmaPanel(
      layers: kFigmaLayersSinav,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 18 * s, 16 * s, 18 * s),
        child: Row(
          children: [
            Container(
              width: 44 * s,
              height: 44 * s,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_rounded, color: Colors.white, size: 22 * s),
            ),
            SizedBox(width: 14 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sınav denemesi',
                    style: FigmaHomeTypography.studyTitle(s * 1.05),
                  ),
                  SizedBox(height: 6 * s),
                  Text(
                    'Soru sayısı ve süreyi ayarla, gerçek koşullarda çöz.',
                    style: FigmaHomeTypography.sinavSubtitle(s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ayarlar ─────────────────────────────────────────────────────────────────

class _AyarlarCard extends StatelessWidget {
  const _AyarlarCard({
    required this.scale,
    required this.soruSayisi,
    required this.sureDak,
    required this.acikAyar,
    required this.soruSecenekleri,
    required this.sureSecenekleri,
    required this.onToggle,
    required this.onSoru,
    required this.onSure,
  });

  final double scale;
  final int soruSayisi;
  final int sureDak;
  final _AcikAyar acikAyar;
  final List<int> soruSecenekleri;
  final List<int> sureSecenekleri;
  final ValueChanged<_AcikAyar> onToggle;
  final ValueChanged<int> onSoru;
  final ValueChanged<int> onSure;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return _FigmaPanel(
      layers: kFigmaLayersStats,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * s, 14 * s, 14 * s, 14 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ayarlar', style: FigmaHomeTypography.countdownLabel(s)),
            SizedBox(height: 12 * s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AyarKolon(
                    scale: s,
                    icon: Icons.quiz_rounded,
                    label: 'Soru',
                    birim: 'soru',
                    secili: soruSayisi,
                    secenekler: soruSecenekleri,
                    acik: acikAyar == _AcikAyar.soru,
                    onTap: () => onToggle(_AcikAyar.soru),
                    onSelect: onSoru,
                  ),
                ),
                SizedBox(width: 10 * s),
                Expanded(
                  child: _AyarKolon(
                    scale: s,
                    icon: Icons.timer_outlined,
                    label: 'Süre',
                    birim: 'dk',
                    secili: sureDak,
                    secenekler: sureSecenekleri,
                    acik: acikAyar == _AcikAyar.sure,
                    onTap: () => onToggle(_AcikAyar.sure),
                    onSelect: onSure,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AyarKolon extends StatelessWidget {
  const _AyarKolon({
    required this.scale,
    required this.icon,
    required this.label,
    required this.birim,
    required this.secili,
    required this.secenekler,
    required this.acik,
    required this.onTap,
    required this.onSelect,
  });

  final double scale;
  final IconData icon;
  final String label;
  final String birim;
  final int secili;
  final List<int> secenekler;
  final bool acik;
  final VoidCallback onTap;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 12 * s),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: acik ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: acik
                      ? kAccent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
                  width: acik ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: kAccent, size: 18 * s),
                  SizedBox(width: 8 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: FigmaHomeTypography.studySubKonular(s * 0.9),
                        ),
                        SizedBox(height: 2 * s),
                        Text(
                          '$secili $birim',
                          style: FigmaHomeTypography.studyTitle(s * 0.92),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    acik
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kAccent,
                    size: 22 * s,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: acik
              ? Padding(
                  padding: EdgeInsets.only(top: 8 * s),
                  child: _SecimListesi(
                    scale: s,
                    secenekler: secenekler,
                    secili: secili,
                    birim: birim,
                    onSelect: onSelect,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SecimListesi extends StatelessWidget {
  const _SecimListesi({
    required this.scale,
    required this.secenekler,
    required this.secili,
    required this.birim,
    required this.onSelect,
  });

  final double scale;
  final List<int> secenekler;
  final int secili;
  final String birim;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      constraints: BoxConstraints(maxHeight: 160 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: 6 * s, horizontal: 6 * s),
        itemCount: secenekler.length,
        separatorBuilder: (_, __) => SizedBox(height: 4 * s),
        itemBuilder: (_, i) {
          final v = secenekler[i];
          final selected = v == secili;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(v),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 34 * s,
                padding: EdgeInsets.symmetric(horizontal: 10 * s),
                decoration: BoxDecoration(
                  color: selected
                      ? kAccent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? kAccent.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$v $birim',
                      style: TextStyle(
                        color: selected ? Colors.white : _cMuted,
                        fontSize: 13 * s,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_rounded, color: kAccent, size: 16 * s),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Yanlışlar ───────────────────────────────────────────────────────────────

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
              padding:
                  EdgeInsets.symmetric(horizontal: 16 * s, vertical: 14 * s),
              child: Row(
                children: [
                  Icon(Icons.replay_rounded, color: _cRed, size: 20 * s),
                  SizedBox(width: 12 * s),
                  Expanded(
                    child: Text(
                      hasYanlis
                          ? 'Yanlışlarım · $count'
                          : 'Yanlış soru yok',
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
