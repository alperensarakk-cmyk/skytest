import 'package:flutter/material.dart';
import '../services/daily_limit_service.dart';
import '../services/istatistik_service.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/limit_exceeded_dialog.dart';
import '../services/zayif_konu_service.dart';
import '../widgets/zayif_konular_panel.dart';
import 'yanlislarim_screen.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cMuted  = Color(0xFFA1B5D8);
const _cRed    = Color(0xFFFF6B6B);
enum _AcikAyar { none, soru, sure }

// ─────────────────────────────────────────────────────────────────────────────

class SinavHazirlikScreen extends StatefulWidget {
  const SinavHazirlikScreen({super.key});

  @override
  State<SinavHazirlikScreen> createState() => _SinavHazirlikScreenState();
}

class _SinavHazirlikScreenState extends State<SinavHazirlikScreen> {
  int  _soruSayisi    = 30;
  int  _sureDak       = 30;
  int              _yanlisCount = 0;
  ZayifKonuOzet    _zayifOzet   = const ZayifKonuOzet(
    konular: [],
    toplamCevaplanan: 0,
    minGerekli: ZayifKonuService.minToplamCevaplanan,
  );
  bool             _loading     = true;
  _AcikAyar        _acikAyar    = _AcikAyar.none;

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
      _soruSayisi     = q;
      _sureDak        = d;
      _yanlisCount    = y;
      _zayifOzet      = z;
      _loading        = false;
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

  Widget _ayarKolon({
    required IconData icon,
    required String label,
    required String birim,
    required int secili,
    required List<int> secenekler,
    required _AcikAyar tip,
    required ValueChanged<int> onSelect,
  }) {
    final acik = _acikAyar == tip;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AyarOzetKarti(
            icon: icon,
            label: label,
            birim: birim,
            secili: secili,
            acik: acik,
            onTap: () => _toggleAyar(tip),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: acik
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _KompaktSecimSeridi(
                      secenekler: secenekler,
                      secili: secili,
                      birim: birim,
                      onSelect: onSelect,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _openYanlislar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const YanlislarimScreen()),
    ).then((_) => _loadData());
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
        title: buildAeroTestAppBarTitle('Sınav Modu'),
      ),

      // ── Sabit Alt Buton ─────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _StartButton(
            enabled: !_loading,
            soruSayisi: _soruSayisi,
            sureDak:    _sureDak,
            onTap:      _baslat,
          ),
        ),
      ),

      // ── Gövde ───────────────────────────────────────────────────────────
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bilgi kartı
                  _InfoCard(),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ayarKolon(
                        icon: Icons.quiz_rounded,
                        label: 'Soru Sayısı',
                        birim: 'soru',
                        secili: _soruSayisi,
                        secenekler: _soruSecenekleri,
                        tip: _AcikAyar.soru,
                        onSelect: (v) => setState(() {
                          _soruSayisi = v;
                          _acikAyar = _AcikAyar.none;
                        }),
                      ),
                      const SizedBox(width: 10),
                      _ayarKolon(
                        icon: Icons.timer_outlined,
                        label: 'Sınav Süresi',
                        birim: 'dk',
                        secili: _sureDak,
                        secenekler: _sureSecenekleri,
                        tip: _AcikAyar.sure,
                        onSelect: (v) => setState(() {
                          _sureDak = v;
                          _acikAyar = _AcikAyar.none;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _YanlisCard(
                    count: _yanlisCount,
                    onTap: _openYanlislar,
                  ),
                  const SizedBox(height: 12),
                  ZayifKonularPanel(
                    ozet: _zayifOzet,
                    onAnalizCleared: _loadData,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}

// ─── Ayar özet kartı + kompakt seçim şeridi ──────────────────────────────────

class _AyarOzetKarti extends StatelessWidget {
  const _AyarOzetKarti({
    required this.icon,
    required this.label,
    required this.birim,
    required this.secili,
    required this.acik,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String birim;
  final int secili;
  final bool acik;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBgCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: acik ? kAccent : Colors.white.withValues(alpha: 0.08),
              width: acik ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: kAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _cMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$secili $birim',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                acik
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: kAccent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KompaktSecimSeridi extends StatefulWidget {
  const _KompaktSecimSeridi({
    required this.secenekler,
    required this.secili,
    required this.birim,
    required this.onSelect,
  });

  final List<int> secenekler;
  final int secili;
  final String birim;
  final ValueChanged<int> onSelect;

  @override
  State<_KompaktSecimSeridi> createState() => _KompaktSecimSeridiState();
}

class _KompaktSecimSeridiState extends State<_KompaktSecimSeridi> {
  late final ScrollController _scrollCtrl;
  bool _canScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_syncScrollHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollHint());
  }

  void _syncScrollHint() {
    if (!_scrollCtrl.hasClients) return;
    final canScroll = _scrollCtrl.position.maxScrollExtent > 4;
    if (canScroll != _canScroll && mounted) {
      setState(() => _canScroll = canScroll);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: const Color(0xFF152238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            RawScrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 5,
              radius: const Radius.circular(4),
              thumbColor: Colors.white,
              trackColor: Colors.white.withValues(alpha: 0.14),
              trackBorderColor: Colors.white.withValues(alpha: 0.35),
              minThumbLength: 22,
              interactive: true,
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                itemCount: widget.secenekler.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final v = widget.secenekler[i];
                  final selected = v == widget.secili;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onSelect(v),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? kAccent.withValues(alpha: 0.18)
                              : kBgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? kAccent
                                : Colors.white.withValues(alpha: 0.08),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                '$v',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected ? kAccent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              ' ${widget.birim}',
                              style: TextStyle(
                                color: selected
                                    ? kAccent.withValues(alpha: 0.8)
                                    : _cMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_canScroll) ...[
              Positioned(
                left: 0,
                right: 12,
                bottom: 0,
                height: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF152238).withValues(alpha: 0),
                          const Color(0xFF152238).withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 14,
                bottom: 2,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Kaydır',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Bilgi Kartı ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(18),
        border: const Border(left: BorderSide(color: kAccent, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_rounded, color: kAccent, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Gerçek Sınav\nDeneyimi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 14),
          const Text(
            'Süre baskısı altında kendini test et. '
            'Soru sayısı ve süreyi yukarıdan ayarlayarak gerçek sınav koşullarını simüle et.',
            style: TextStyle(color: _cMuted, fontSize: 13, height: 1.65),
          ),
        ],
      ),
    );
  }
}

// ─── Yanlışlarım Kart ────────────────────────────────────────────────────────

class _YanlisCard extends StatelessWidget {
  const _YanlisCard({required this.count, required this.onTap});
  final int          count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasYanlis = count > 0;
    return Opacity(
      opacity: hasYanlis ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: hasYanlis ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: hasYanlis
                ? const Color(0xFF3D1A1A)
                : const Color(0xFF1C1616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasYanlis
                  ? _cRed.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.replay_circle_filled_rounded,
                    color: _cRed, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yanlışlarım',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(
                      hasYanlis
                          ? '$count yanlış soru seni bekliyor'
                          : 'Henüz yanlış soru yok',
                      style:
                          const TextStyle(color: _cMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (hasYanlis)
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: _cRed, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Başla Butonu ─────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.soruSayisi,
    required this.sureDak,
    required this.onTap,
  });

  final bool         enabled;
  final int          soruSayisi;
  final int          sureDak;
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
                  colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF1A2A40), Color(0xFF101B30)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: kAccent.withValues(alpha: 0.30),
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
                    strokeWidth: 2, color: Colors.white54),
              )
            else ...[
              const Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'SINAVA BAŞLA  ($soruSayisi soru · $sureDak dk)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
