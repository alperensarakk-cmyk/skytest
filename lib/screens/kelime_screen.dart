import 'package:flutter/material.dart';
import '../models/kelime_model.dart';
import '../services/daily_limit_service.dart';
import '../services/kelime_service.dart';
import '../services/kelime_yanlis_service.dart';
import '../services/premium_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/limit_exceeded_dialog.dart';
import 'kelime_pratik_screen.dart';
import 'kelime_yanlislarim_screen.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cMuted  = Color(0xFFA1B5D8);
const _cGold   = Color(0xFFFFD60A);
const _cPurple = Color(0xFF6C63FF);

// ─────────────────────────────────────────────────────────────────────────────
class KelimeScreen extends StatefulWidget {
  const KelimeScreen({super.key});

  @override
  State<KelimeScreen> createState() => _KelimeScreenState();
}

class _KelimeScreenState extends State<KelimeScreen> {
  List<KelimeModel>? _tumKelimeler;
  int  _setSize         = 0;
  int  _kelimeYanlisCount = 0;
  bool _loading           = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final kelimeler  = await KelimeService.loadAll();
    final setSize    = await SettingsService.getKelimeSetSize();
    final yanlisCount = await KelimeYanlisService.getCountAsync();
    if (!mounted) return;
    setState(() {
      _tumKelimeler      = kelimeler;
      _setSize           = setSize;
      _kelimeYanlisCount = yanlisCount;
      _loading           = false;
    });
  }

  Future<void> _baslat() async {
    if (_tumKelimeler == null) return;
    await DailyLimitService.ensureDay();
    final premium = await PremiumService.isPremiumUser();
    var remKelime = 999999;
    if (!premium) {
      remKelime = await DailyLimitService.kelimeRemaining();
      if (remKelime <= 0) {
        if (mounted) await showDailyLimitExceededDialog(context);
        return;
      }
    }

    final shuffled = List<KelimeModel>.from(_tumKelimeler!)..shuffle();
    var take = _setSize == 0 ? shuffled.length : _setSize;
    if (!premium) {
      take = take < remKelime ? take : remKelime;
    }
    final set = shuffled.take(take).toList();
    if (set.isEmpty) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KelimePratikScreen(
          kelimeler:    set,
          tumKelimeler: _tumKelimeler!,
        ),
      ),
    ).then((_) => _loadData());
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
          'Kelime Çalışması',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ── Sabit Alt Buton ───────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _StartButton(
            enabled: !_loading,
            onTap:   _baslat,
          ),
        ),
      ),

      // ── Gövde ─────────────────────────────────────────────────────────────
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _InfoCard(),
                  const SizedBox(height: 16),
                  _YanlisCard(
                    count: _kelimeYanlisCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const KelimeYanlislarimScreen()),
                    ).then((_) => _loadData()),
                  ),
                  const SizedBox(height: 20),
                  _OturumBoyutuCard(
                    setSize: _setSize,
                    onSelect: (v) async {
                      setState(() => _setSize = v);
                      await SettingsService.setKelimeSetSize(v);
                    },
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
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _cPurple.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.spellcheck_rounded, color: _cPurple, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Teknik Havacılık\nKelime Hazinesi',
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
          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 16),
          const Text(
            'Çoktan seçmeli sorularla çalış; kelimeler her oturumda karışık gelir. '
            'Yanlış yaptıklarını tekrar listene ekle, doğru yaptıklarını listeden çıkar.',
            style: TextStyle(color: _cMuted, fontSize: 13, height: 1.65),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _Badge(icon: Icons.quiz_rounded, label: 'Çoktan Seçmeli'),
              _Badge(icon: Icons.lightbulb_rounded, label: 'Örnek Cümleler'),
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

// ─── Oturum boyutu (Ayarlar ile aynı değerler) ────────────────────────────────

class _OturumBoyutuCard extends StatelessWidget {
  const _OturumBoyutuCard({
    required this.setSize,
    required this.onSelect,
  });

  final int setSize;
  final ValueChanged<int> onSelect;

  static const _options = [0, 10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded,
                  color: _cPurple.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 10),
              const Text(
                'Oturum boyutu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _options)
                _OturumChip(
                  label: v == 0 ? 'Sonsuz' : '$v',
                  selected: setSize == v,
                  onTap: () => onSelect(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OturumChip extends StatelessWidget {
  const _OturumChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? _cPurple.withValues(alpha: 0.22)
                : const Color(0xFF233056),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _cPurple : Colors.white.withValues(alpha: 0.1),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _cMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
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
    required this.onTap,
  });
  final bool         enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF2D2050), Color(0xFF1A3040)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _cPurple.withValues(alpha: 0.35),
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
              const Text(
                'ÇALIŞMAYA BAŞLA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Yanlış Kelimelerim Kısayol Kartı ────────────────────────────────────────

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
                  ? const Color(0xFFFF6B6B).withValues(alpha: 0.35)
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
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.replay_circle_filled_rounded,
                    color: Color(0xFFFF6B6B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yanlış Kelimelerim',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(
                      hasYanlis
                          ? '$count yanlış kelime tekrar bekliyor'
                          : 'Henüz yanlış kelime yok',
                      style: const TextStyle(
                          color: Color(0xFFA1B5D8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (hasYanlis)
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFFF6B6B), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
