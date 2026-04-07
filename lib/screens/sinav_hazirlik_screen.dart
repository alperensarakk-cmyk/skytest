import 'package:flutter/material.dart';
import '../services/daily_limit_service.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/limit_exceeded_dialog.dart';
import 'yanlislarim_screen.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cMuted  = Color(0xFFA1B5D8);
const _cRed    = Color(0xFFFF6B6B);
const _cGold   = Color(0xFFFFD60A);

// ─────────────────────────────────────────────────────────────────────────────

class SinavHazirlikScreen extends StatefulWidget {
  const SinavHazirlikScreen({super.key});

  @override
  State<SinavHazirlikScreen> createState() => _SinavHazirlikScreenState();
}

class _SinavHazirlikScreenState extends State<SinavHazirlikScreen> {
  int  _soruSayisi    = 30;
  int  _sureDak       = 30;
  int  _yanlisCount   = 0;
  bool _loading       = true;

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
    if (!mounted) return;
    setState(() {
      _soruSayisi  = q;
      _sureDak     = d;
      _yanlisCount = y;
      _loading     = false;
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
        title: const Text(
          'Sınav Modu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  const SizedBox(height: 16),

                  // Yanlışlarım kısayolu
                  _YanlisCard(
                    count: _yanlisCount,
                    onTap: _openYanlislar,
                  ),
                  const SizedBox(height: 24),

                  // Sınav ayarları
                  _AyarBaslik(
                    icon:  Icons.quiz_rounded,
                    label: 'Soru Sayısı',
                  ),
                  const SizedBox(height: 10),
                  _SecenekSatiri(
                    secenekler: _soruSecenekleri,
                    secili:     _soruSayisi,
                    birim:      'soru',
                    onSelect:   (v) => setState(() => _soruSayisi = v),
                  ),
                  const SizedBox(height: 20),

                  _AyarBaslik(
                    icon:  Icons.timer_outlined,
                    label: 'Süre',
                  ),
                  const SizedBox(height: 10),
                  _SecenekSatiri(
                    secenekler: _sureSecenekleri,
                    secili:     _sureDak,
                    birim:      'dk',
                    onSelect:   (v) => setState(() => _sureDak = v),
                  ),
                  const SizedBox(height: 8),
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
            'Karışık sorularla süre baskısı altında kendini test et. '
            'Sınav sırasında doğru/yanlış gösterilmez; '
            'bittiğinde detaylı sonuç ekranı açılır.',
            style: TextStyle(color: _cMuted, fontSize: 13, height: 1.65),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _Badge(icon: Icons.shuffle_rounded,       label: 'Rastgele Sorular'),
              _Badge(icon: Icons.visibility_off_rounded, label: 'Geri Bildirim Yok'),
              _Badge(icon: Icons.bar_chart_rounded,     label: 'Detaylı Sonuç'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
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
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
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

// ─── Ayar Başlığı ─────────────────────────────────────────────────────────────

class _AyarBaslik extends StatelessWidget {
  const _AyarBaslik({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kAccent, size: 17),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Seçenek Satırı ──────────────────────────────────────────────────────────

class _SecenekSatiri extends StatelessWidget {
  const _SecenekSatiri({
    required this.secenekler,
    required this.secili,
    required this.birim,
    required this.onSelect,
  });

  final List<int>       secenekler;
  final int             secili;
  final String          birim;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: secenekler.map((v) {
        final isSelected = v == secili;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onSelect(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? kAccent.withValues(alpha: 0.18)
                      : kBgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kAccent : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$v',
                      style: TextStyle(
                        color: isSelected ? kAccent : Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      birim,
                      style: TextStyle(
                        color: isSelected
                            ? kAccent.withValues(alpha: 0.75)
                            : _cMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
