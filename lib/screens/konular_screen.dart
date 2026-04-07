import 'package:flutter/material.dart';
import '../models/soru_model.dart';
import '../services/daily_limit_service.dart';
import '../services/premium_service.dart';
import '../services/soru_secim_service.dart';
import '../services/soru_son_gorulen_service.dart';
import '../services/soru_yukleme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/limit_exceeded_dialog.dart';
import 'konu_pratik_screen.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cGold  = Color(0xFFFFD60A);
const _cMuted = Color(0xFFA1B5D8);

/// Sınav şablonu ile aynı soru tipleri (normalize anahtar → etiket).
const _konuSoruTipleri = <String, String>{
  'Yapi': 'Yapı',
  'Ceviri': 'Çeviri',
  'Kelime': 'Kelime',
  'Okuma': 'Okuma',
  'Cumle_Tamamlama': 'Cümle tamamlama',
  'Bosluk_Doldurma': 'Boşluk doldurma',
};

// ─────────────────────────────────────────────────────────────────────────────
class KonularScreen extends StatefulWidget {
  const KonularScreen({super.key});

  @override
  State<KonularScreen> createState() => _KonularScreenState();
}

class _KonularScreenState extends State<KonularScreen> {
  List<String>      _kategoriler = [];
  List<SoruModel>   _tumSorular  = [];
  bool              _loading     = true;

  /// true: tüm havuz dengeli (alt satırlar görselde seçili değil).
  bool _karisikMod = true;
  final Set<String> _seciliTipler = {};
  bool _soruTipiPanelAcik = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _soruTipiOzet() {
    if (_karisikMod) return 'Tüm soru tipleri, dengeli dağılım';
    final n = _seciliTipler.length;
    if (n == 0) return 'Alttan en az bir soru tipi seç';
    if (n == 1) {
      final k = _seciliTipler.first;
      return _konuSoruTipleri[k] ?? k;
    }
    return '$n tip seçili';
  }

  Future<void> _loadData() async {
    final list = await SoruYuklemeService.tumSorulariYukle();

    // Benzersiz kategoriler (sıralı)
    final cats = list.map((s) => s.kategori).toSet().toList()..sort();

    if (!mounted) return;
    setState(() {
      _tumSorular  = list;
      _kategoriler = cats;
      _loading     = false;
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
      avoidRecentIds:   avoid,
    );
    if (!mounted) return;
    if (sorular.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şu an çözülecek soru bulunamadı. Veri yüklemesini kontrol edin.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KonuPratikScreen(
          kategoriAdi: 'Tüm Konular',
          sorular:     sorular,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Konulara Yönelik Çalışma',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ── Sabit Alt Buton ────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _StartButton(
            enabled: !_loading && (_karisikMod || _seciliTipler.isNotEmpty),
            onTap:   () => _baslat(),
          ),
        ),
      ),

      // ── Gövde ─────────────────────────────────────────────────────────────
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: kAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 1. Karşılama Kartı ───────────────────────────────────
                  const _InfoCard(),
                  const SizedBox(height: 20),

                  // ── 2. Soru tipi: Karışık veya seçili tipler ─────────────
                  _SoruTipiAcilirKart(
                    acik: _soruTipiPanelAcik,
                    ozet: _soruTipiOzet(),
                    karisikMod: _karisikMod,
                    seciliTipler: _seciliTipler,
                    onBaslik: () => setState(
                      () => _soruTipiPanelAcik = !_soruTipiPanelAcik,
                    ),
                    onTipToggle: (tipKey, secili) => setState(() {
                      _karisikMod = false;
                      if (secili) {
                        _seciliTipler.add(tipKey);
                      } else {
                        _seciliTipler.remove(tipKey);
                        if (_seciliTipler.isEmpty) {
                          _karisikMod = true;
                        }
                      }
                    }),
                    onKarisikChanged: (karisik) => setState(() {
                      _karisikMod = karisik;
                      if (karisik) _seciliTipler.clear();
                    }),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Karşılama Kartı ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon + başlık
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: kAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Sistem ve Gramer\nOdaklı Pratik',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ayırıcı
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),

          const SizedBox(height: 16),

          // Açıklama
          const Text(
            'Bu modda süre stresi yok. Soruları çözerken anında taktikleri, '
            'çevirileri ve gramer kurallarını öğrenerek ilerleyeceksin.',
            style: TextStyle(
              color: _cMuted,
              fontSize: 13,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 16),

          // Özellik rozetleri
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _FeatureBadge(icon: Icons.flash_on_rounded,   label: 'Anında Geri Bildirim'),
              _FeatureBadge(icon: Icons.lightbulb_rounded,  label: 'Taktik Açıklamaları'),
              _FeatureBadge(icon: Icons.quiz_rounded,       label: 'Sınav odaklı çalışma'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF233056),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _cGold, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Soru tipi: alta açılan çoklu seçim ───────────────────────────────────────

class _SoruTipiAcilirKart extends StatelessWidget {
  const _SoruTipiAcilirKart({
    required this.acik,
    required this.ozet,
    required this.karisikMod,
    required this.seciliTipler,
    required this.onBaslik,
    required this.onTipToggle,
    required this.onKarisikChanged,
  });

  final bool acik;
  final String ozet;
  final bool karisikMod;
  final Set<String> seciliTipler;
  final VoidCallback onBaslik;
  final void Function(String tipKey, bool secili) onTipToggle;
  final void Function(bool karisik) onKarisikChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBaslik,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 8, acik ? 10 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      color: kAccent.withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Soru tipi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ozet,
                            style: const TextStyle(
                              color: _cMuted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: acik ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: kAccent.withValues(alpha: 0.95),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: acik
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Karışık açıkken tüm tipler dengeli gelir. Karışık kapalıyken yalnızca işaretlediğin tipler havuza girer.',
                              style: TextStyle(
                                color: _cMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: const Color(0xFF253354),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () =>
                                          onKarisikChanged(!karisikMod),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Checkbox(
                                              value: karisikMod,
                                              onChanged: (v) =>
                                                  onKarisikChanged(v ?? false),
                                              activeColor: kAccent,
                                              checkColor:
                                                  const Color(0xFF0B132B),
                                              side: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.28),
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Karışık',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Tüm soru tipleri, dengeli dağılım',
                                                    style: TextStyle(
                                                      color: _cMuted
                                                          .withValues(
                                                              alpha: 0.95),
                                                      fontSize: 12,
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 10,
                                                right: 6,
                                              ),
                                              child: Icon(
                                                Icons.shuffle_rounded,
                                                color: kAccent.withValues(
                                                  alpha: 0.9,
                                                ),
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                for (final e in _konuSoruTipleri.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: const Color(0xFF1C2541),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () {
                                          final suAn =
                                              !karisikMod &&
                                              seciliTipler.contains(e.key);
                                          onTipToggle(e.key, !suAn);
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: !karisikMod &&
                                                    seciliTipler.contains(
                                                      e.key,
                                                    ),
                                                onChanged: (v) =>
                                                    onTipToggle(
                                                  e.key,
                                                  v ?? false,
                                                ),
                                                activeColor: kAccent,
                                                checkColor:
                                                    const Color(0xFF0B132B),
                                                side: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  e.value,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Çalışmaya Başla Butonu ───────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.onTap,
  });
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 58,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF48CAE4), Color(0xFF0096C7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF2D4A5A), Color(0xFF1A3040)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF48CAE4).withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!enabled)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            else ...[
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFF0B132B),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'ÇALIŞMAYA BAŞLA',
                style: TextStyle(
                  color: Color(0xFF0B132B),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
