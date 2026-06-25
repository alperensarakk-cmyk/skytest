import 'package:flutter/material.dart';
import '../models/sinav_sonucu.dart';
import '../services/istatistik_service.dart';
import '../services/kelime_istatistik_service.dart';
import '../services/kelime_yanlis_service.dart';
import '../theme/app_theme.dart';
import '../utils/sinav_puan_format.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cGold   = Color(0xFFFFD60A);
const _cMuted  = Color(0xFFA1B5D8);
const _cCard2  = Color(0xFF1C2541);
const _cRed    = Color(0xFFFF6B6B);
const _cGreen  = Color(0xFF4CAF50);

// ─────────────────────────────────────────────────────────────────────────────

class IstatistikScreen extends StatefulWidget {
  const IstatistikScreen({super.key});

  @override
  State<IstatistikScreen> createState() => _IstatistikScreenState();
}

class _IstatistikScreenState extends State<IstatistikScreen> {
  List<SinavSonucu>?   _sonuclar;
  Map<String, dynamic>? _kelimeStats;
  int _kelimeYanlisCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final s  = await IstatistikService.getSinavSonuclari();
    final ks = await KelimeIstatistikService.getTodayStats();
    final kc = await KelimeYanlisService.getCountAsync();
    if (!mounted) return;
    setState(() {
      _sonuclar          = s;
      _kelimeStats       = ks;
      _kelimeYanlisCount = kc;
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'İstatistikler',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_sonuclar != null && _sonuclar!.isNotEmpty)
            IconButton(
              tooltip: 'İstatistikleri Sıfırla',
              icon: const Icon(Icons.delete_sweep_rounded, color: _cMuted),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: _sonuclar == null
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : RefreshIndicator(
              color: kAccent,
              backgroundColor: kBgCard,
              onRefresh: _loadData,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    final hasExams = _sonuclar?.isNotEmpty ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── Kart 0: Kelime Özeti (her zaman göster) ──────────────────────
        if (_kelimeStats != null) ...[
          _KelimeOzetCard(
            stats:       _kelimeStats!,
            yanlisCount: _kelimeYanlisCount,
            onClear:     _confirmClearKelime,
          ),
          const SizedBox(height: 28),
        ],

        // ── Kart 1: Tamamlanan Sınavlar ─────────────────────────────────
        _SectionHeader(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Tamamlanan Sınavlar',
          subtitle: hasExams ? '${_sonuclar!.length} sınav' : 'Henüz sınav yok',
        ),
        const SizedBox(height: 12),
        if (!hasExams) ...[
          _EmptyState(),
        ] else ...[
          _ExamSummaryBar(sonuclar: _sonuclar!),
          const SizedBox(height: 10),
          ..._sonuclar!.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExamCard(sonuc: s),
              )),
        ],
      ],
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İstatistikleri Sıfırla',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Tüm sınav geçmişi silinecek. Bu işlem geri alınamaz.',
          style: TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç', style: TextStyle(color: _cMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sıfırla',
                  style: TextStyle(
                      color: _cRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    await IstatistikService.clearAll();
    await _loadData();
  }

  Future<void> _confirmClearKelime() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kelime Verilerini Sıfırla',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Bugünkü kelime çalışması istatistikleri silinecek. Emin misin?',
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç', style: TextStyle(color: _cMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sıfırla',
                  style: TextStyle(color: _cRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    await KelimeIstatistikService.clearAll();
    await _loadData();
  }
}

// ─── Boş Durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 72, color: kAccent.withValues(alpha: 0.25)),
            const SizedBox(height: 20),
            const Text(
              'Henüz sınav yok',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sınav Modu\'ndan bir test tamamladıktan sonra istatistiklerin burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _cMuted, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bölüm Başlığı ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = kAccent,
  });

  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(color: _cMuted, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

// ─── Özet Bar (toplam doğru/yanlış/oran) ──────────────────────────────────────

class _ExamSummaryBar extends StatelessWidget {
  const _ExamSummaryBar({required this.sonuclar});
  final List<SinavSonucu> sonuclar;

  @override
  Widget build(BuildContext context) {
    final totalDogru  = sonuclar.fold(0, (s, e) => s + e.dogru);
    final totalYanlis = sonuclar.fold(0, (s, e) => s + e.yanlis);
    final totalSoru   = sonuclar.fold(0, (s, e) => s + e.toplam);
    final avgYuzde    = sonuclar.fold(0.0, (s, e) => s + e.yuzde) / sonuclar.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
              value: '$totalSoru', label: 'Toplam\nSoru', color: kAccent),
          _VDivider(),
          _SummaryItem(
              value: '$totalDogru', label: 'Toplam\nDoğru', color: _cGreen),
          _VDivider(),
          _SummaryItem(
              value: '$totalYanlis',
              label: 'Toplam\nYanlış',
              color: _cRed),
          _VDivider(),
          _SummaryItem(
              value:
                  '${SinavPuanFormat.formatPuan(avgYuzde)}/100',
              label: 'Ort.\nNot',
              color: _cGold),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cMuted, fontSize: 10, height: 1.3)),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 36, color: Colors.white.withValues(alpha: 0.07));
}

// ─── Tek Sınav Satırı ─────────────────────────────────────────────────────────

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.sonuc});
  final SinavSonucu sonuc;

  String _formatDate(DateTime d) {
    final months = [
      '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${d.day} ${months[d.month]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Color _yuzdeColor(double y) {
    if (y >= 80) return _cGreen;
    if (y >= 60) return _cGold;
    return _cRed;
  }

  @override
  Widget build(BuildContext context) {
    final yuzde = sonuc.yuzde;
    final color = _yuzdeColor(yuzde);

    return Container(
      decoration: BoxDecoration(
        color: _cCard2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          // 100 üzerinden not
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    SinavPuanFormat.formatPuan(yuzde),
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.05),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Tarih + detaylar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(sonuc.tarih),
                  style: const TextStyle(color: _cMuted, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _Tag(label: '✓ ${sonuc.dogru}', color: _cGreen),
                    const SizedBox(width: 6),
                    _Tag(label: '✗ ${sonuc.yanlis}', color: _cRed),
                    const SizedBox(width: 6),
                    _Tag(
                        label: '— ${sonuc.bos}',
                        color: Colors.white.withValues(alpha: 0.35)),
                  ],
                ),
              ],
            ),
          ),

          // Soru sayısı
          Text(
            '${sonuc.toplam} soru',
            style: const TextStyle(color: _cMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Kelime Özeti Kartı ───────────────────────────────────────────────────────

const _cPurple = Color(0xFF6C63FF);

class _KelimeOzetCard extends StatelessWidget {
  const _KelimeOzetCard({
    required this.stats,
    required this.yanlisCount,
    required this.onClear,
  });

  final Map<String, dynamic> stats;
  final int                  yanlisCount;
  final VoidCallback         onClear;

  @override
  Widget build(BuildContext context) {
    final total   = stats['total']   as int? ?? 0;
    final correct = stats['correct'] as int? ?? 0;
    final ratio   = total > 0 ? correct / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _cCard2,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: _cPurple, width: 3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _cPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.spellcheck_rounded,
                    color: _cPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bugünkü Kelime Çalışması',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text('Günlük özet',
                        style: TextStyle(color: _cMuted, fontSize: 11)),
                  ],
                ),
              ),
              // Temizle butonu
              IconButton(
                tooltip: 'Kelime Verilerini Sıfırla',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: _cMuted, size: 20),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // İstatistik satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _KelimeStat(value: '$total', label: 'Çözülen'),
              _KelimeStat(value: '$correct', label: 'Doğru'),
              _KelimeStat(
                  value: '${total - correct}', label: 'Yanlış'),
              _KelimeStat(
                  value: '$yanlisCount', label: 'Listede'),
            ],
          ),

          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(_cPurple),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '%${(ratio * 100).round()} doğru oranı',
              style: const TextStyle(color: _cMuted, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Bugün henüz kelime çalışması yapılmadı.',
              style: TextStyle(color: _cMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _KelimeStat extends StatelessWidget {
  const _KelimeStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: _cPurple,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: _cMuted, fontSize: 10)),
      ],
    );
  }
}
