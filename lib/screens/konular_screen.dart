import 'package:flutter/material.dart';

import '../models/soru_model.dart';
import '../services/daily_limit_service.dart';
import '../services/premium_service.dart';
import '../services/soru_secim_service.dart';
import '../services/soru_son_gorulen_service.dart';
import '../services/soru_yukleme_service.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layers.dart';
import '../theme/figma_home_layout.dart';
import '../theme/figma_home_typography.dart';
import '../widgets/limit_exceeded_dialog.dart';
import 'konu_pratik_screen.dart';

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

/// Sınav şablonu ile aynı soru tipleri (normalize anahtar → etiket).
const _konuSoruTipleri = <String, String>{
  'Yapi': 'Yapı',
  'Ceviri': 'Çeviri',
  'Kelime': 'Kelime',
  'Okuma': 'Okuma',
  'Cumle_Tamamlama': 'Cümle tamamlama',
  'Bosluk_Doldurma': 'Boşluk doldurma',
};

const _konuSoruTipiIkon = <String, IconData>{
  'Yapi': Icons.account_tree_rounded,
  'Ceviri': Icons.translate_rounded,
  'Kelime': Icons.spellcheck_rounded,
  'Okuma': Icons.menu_book_rounded,
  'Cumle_Tamamlama': Icons.short_text_rounded,
  'Bosluk_Doldurma': Icons.space_bar_rounded,
};

class KonularScreen extends StatefulWidget {
  const KonularScreen({super.key});

  @override
  State<KonularScreen> createState() => _KonularScreenState();
}

class _KonularScreenState extends State<KonularScreen> {
  List<SoruModel> _tumSorular = [];
  bool _loading = true;

  /// true: tüm havuz dengeli (alt satırlar görselde seçili değil).
  bool _karisikMod = true;
  final Set<String> _seciliTipler = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _soruTipiOzet() {
    if (_karisikMod) return 'Tüm tipler dengeli dağılır';
    final n = _seciliTipler.length;
    if (n == 0) return 'En az bir tip seç';
    if (n == 1) {
      final k = _seciliTipler.first;
      return _konuSoruTipleri[k] ?? k;
    }
    return '$n tip seçili';
  }

  Future<void> _loadData() async {
    final list = await SoruYuklemeService.tumSorulariYukle();

    if (!mounted) return;
    setState(() {
      _tumSorular = list;
      _loading = false;
    });
  }

  List<SoruModel> _havuzKonuPratik() {
    if (_karisikMod) return _tumSorular;
    if (_seciliTipler.isEmpty) return [];
    return _tumSorular
        .where(
          (s) => _seciliTipler
              .contains(SoruSecimService.normalizeSoruTipi(s.soruTipi)),
        )
        .toList();
  }

  String _pratikAppBarBasligi() {
    if (_karisikMod) return 'Karışık';
    final keys = _seciliTipler.toList()..sort();
    if (keys.isEmpty) return 'Konular';
    if (keys.length == 1) {
      return _konuSoruTipleri[keys.first] ?? keys.first;
    }
    return keys.map((k) => _konuSoruTipleri[k] ?? k).join(', ');
  }

  Future<void> _baslat() async {
    final pool = _havuzKonuPratik();
    if (pool.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seçili tiplerde soru yok. Farklı tipler dene veya tümünü seç.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await DailyLimitService.ensureDay();
    var n = pool.length;
    if (!await PremiumService.isPremiumUser()) {
      final rem = await DailyLimitService.konuRemaining();
      if (rem <= 0) {
        if (mounted) await showDailyLimitExceededDialog(context);
        return;
      }
      n = n < rem ? n : rem;
    }
    final avoid = await SoruSonGorulenService.getAvoidSet();
    final sorular = SoruSecimService.secDengeli(
      pool,
      n,
      useRandomization: true,
      avoidRecentIds: avoid,
    );
    if (!mounted) return;
    if (sorular.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Şu an çözülecek soru bulunamadı. Veri yüklemesini kontrol edin.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KonuPratikScreen(
          kategoriAdi: _pratikAppBarBasligi(),
          sorular: sorular,
        ),
      ),
    );
  }

  bool get _canStart => !_loading && (_karisikMod || _seciliTipler.isNotEmpty);

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
        title: buildAeroTestAppBarTitle(
          'Konulara Yönelik',
          subtitleFontSize: 18,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 16 * s),
          child: FilledButton.icon(
            onPressed: _canStart ? _baslat : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('ÇALIŞMAYA BAŞLA'),
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
                      _KonularHero(
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
                            _IntroCard(
                              scale: s,
                            ),
                            SizedBox(height: 12 * s),
                            _SoruTipiCard(
                              scale: s,
                              ozet: _soruTipiOzet(),
                              karisikMod: _karisikMod,
                              seciliTipler: _seciliTipler,
                              onKarisik: () => setState(() {
                                _karisikMod = true;
                                _seciliTipler.clear();
                              }),
                              onOzel: () => setState(() {
                                _karisikMod = false;
                              }),
                              onTipToggle: (tipKey) => setState(() {
                                _karisikMod = false;
                                if (_seciliTipler.contains(tipKey)) {
                                  _seciliTipler.remove(tipKey);
                                } else {
                                  _seciliTipler.add(tipKey);
                                }
                              }),
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

class _KonularHero extends StatelessWidget {
  const _KonularHero({
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
              'Süre stresi yok, adım adım öğren.',
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
  const _IntroCard({
    required this.scale,
  });

  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return _FigmaPanel(
      layers: kFigmaLayersKonular,
      child: SizedBox(
        height: 110 * s,
        child: Stack(
          children: [
            Positioned(
              right: 4 * s,
              bottom: 0,
              width: 110 * s,
              height: 110 * s,
              child: Image.asset(
                'assets/home/card_konular.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16 * s, 22 * s, 100 * s, 16 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konu çalışması',
                    style: FigmaHomeTypography.studyTitle(s * 1.05),
                  ),
                  SizedBox(height: 8 * s),
                  Text(
                    'Anında açıklama ve ipuçları ile çalışmaya başla.',
                    style: FigmaHomeTypography.studySubKonular(s),
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

// ─── Soru tipi (segment + sessiz liste) ───────────────────────────────────────

class _SoruTipiCard extends StatelessWidget {
  const _SoruTipiCard({
    required this.scale,
    required this.ozet,
    required this.karisikMod,
    required this.seciliTipler,
    required this.onKarisik,
    required this.onOzel,
    required this.onTipToggle,
  });

  final double scale;
  final String ozet;
  final bool karisikMod;
  final Set<String> seciliTipler;
  final VoidCallback onKarisik;
  final VoidCallback onOzel;
  final ValueChanged<String> onTipToggle;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return _FigmaPanel(
      layers: kFigmaLayersStats,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 16 * s, 16 * s, 14 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soru tipi', style: FigmaHomeTypography.countdownLabel(s)),
            SizedBox(height: 6 * s),
            Text(ozet, style: FigmaHomeTypography.studySubKonular(s)),
            SizedBox(height: 14 * s),
            _SegmentedMode(
              scale: s,
              karisik: karisikMod,
              onKarisik: onKarisik,
              onOzel: onOzel,
            ),
            if (!karisikMod) ...[
              SizedBox(height: 12 * s),
              ..._konuSoruTipleri.entries.map((e) {
                final selected = seciliTipler.contains(e.key);
                return _TipRow(
                  scale: s,
                  label: e.value,
                  icon: _konuSoruTipiIkon[e.key] ?? Icons.quiz_outlined,
                  selected: selected,
                  onTap: () => onTipToggle(e.key),
                );
              }),
              if (seciliTipler.isEmpty) ...[
                SizedBox(height: 8 * s),
                Text(
                  'Devam etmek için en az bir tip seç.',
                  style: FigmaHomeTypography.studySubAccent(s),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedMode extends StatelessWidget {
  const _SegmentedMode({
    required this.scale,
    required this.karisik,
    required this.onKarisik,
    required this.onOzel,
  });

  final double scale;
  final bool karisik;
  final VoidCallback onKarisik;
  final VoidCallback onOzel;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      padding: EdgeInsets.all(3 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegItem(
              scale: s,
              label: 'Karışık',
              selected: karisik,
              onTap: onKarisik,
            ),
          ),
          Expanded(
            child: _SegItem(
              scale: s,
              label: 'Seçerek',
              selected: !karisik,
              onTap: onOzel,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 11 * s),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : kTextSecondary,
              fontSize: 14 * s,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.scale,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final double scale;
  final String label;
  final IconData icon;
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
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10 * s, horizontal: 4 * s),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18 * s,
                color: selected ? kAccentTeal : kTextSecondary,
              ),
              SizedBox(width: 12 * s),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : kTextSecondary,
                    fontSize: 14 * s,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0.25,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20 * s,
                  color: selected ? kAccentTeal : kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
