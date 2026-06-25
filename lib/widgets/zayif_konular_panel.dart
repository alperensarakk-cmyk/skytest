import 'package:flutter/material.dart';

import '../services/istatistik_service.dart';
import '../services/zayif_konu_pratik_service.dart';
import '../services/zayif_konu_service.dart';
import '../theme/app_theme.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cGold  = Color(0xFFFFD60A);
const _cRed   = Color(0xFFFF6B6B);
const _cCard  = Color(0xFF1C2541);

Future<bool> confirmZayifKonuAnalizTemizle(
  BuildContext context, {
  required int analizSoruSayisi,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1C2541),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Analizi Sıfırla',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        analizSoruSayisi > 0
            ? '$analizSoruSayisi soruluk zayıf konu analizi silinecek. '
                'İlerleme 0\'dan başlar. Sınav skorların korunur.'
            : 'Zayıf konu analizi sıfırlanacak.',
        style: const TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç', style: TextStyle(color: _cMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            'Temizle',
            style: TextStyle(color: _cRed, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}

/// Sınav hazırlık ekranında özet kart — konu listesi ayrı ekranda açılır.
class ZayifKonularPanel extends StatelessWidget {
  const ZayifKonularPanel({
    super.key,
    required this.ozet,
    this.onAnalizCleared,
  });

  final ZayifKonuOzet ozet;
  final VoidCallback? onAnalizCleared;

  void _ac(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ZayifKonularScreen()),
    ).then((_) => onAnalizCleared?.call());
  }

  Future<void> _temizle(BuildContext context) async {
    if (ozet.toplamCevaplanan <= 0) return;

    final onay = await confirmZayifKonuAnalizTemizle(
      context,
      analizSoruSayisi: ozet.toplamCevaplanan,
    );
    if (!onay || !context.mounted) return;

    await IstatistikService.clearZayifKonuAnalizi();
    if (!context.mounted) return;
    onAnalizCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final yeterli  = ozet.yeterliVeri &&
        ozet.toplamCevaplanan >= ZayifKonuService.minToplamCevaplanan;
    final hasWeak  = yeterli && ozet.zayifKonuVar;
    final acilabilir = hasWeak;
    final temizlenebilir = ozet.toplamCevaplanan > 0;

    return Container(
      decoration: BoxDecoration(
        color: acilabilir
            ? const Color(0xFF1A2238)
            : const Color(0xFF161C28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: acilabilir
              ? _cGold.withValues(alpha: 0.30)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_down_rounded,
                  color: _cGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: acilabilir ? () => _ac(context) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zayıf Konularım',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _altBaslik(),
                            style: const TextStyle(
                              color: _cMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (temizlenebilir)
                IconButton(
                  tooltip: 'Analizi Sıfırla',
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: _cRed,
                    size: 22,
                  ),
                  onPressed: () => _temizle(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              if (acilabilir)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _ac(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _cGold,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!yeterli) ...[
            const SizedBox(height: 14),
            _IlerlemeCubugu(
              mevcut: ozet.toplamCevaplanan,
              hedef: ozet.minGerekli,
            ),
          ] else if (!hasWeak) ...[
            const SizedBox(height: 12),
            Text(
              'Henüz belirgin zayıf konun yok. Sınavlara devam et!',
              style: TextStyle(
                color: _cMuted.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _altBaslik() {
    final yeterli = ozet.yeterliVeri &&
        ozet.toplamCevaplanan >= ZayifKonuService.minToplamCevaplanan;
    if (!yeterli) {
      return 'En az ${ozet.minGerekli} sınav sorusu sonrası analiz başlar';
    }
    if (!ozet.zayifKonuVar) {
      return '${ozet.toplamCevaplanan} soru analiz edildi';
    }
    return 'En çok zorlandığın alanlar hazır dokunarak incele';
  }
}

/// Zayıf konu listesinin tam ekranı.
class ZayifKonularScreen extends StatefulWidget {
  const ZayifKonularScreen({super.key});

  @override
  State<ZayifKonularScreen> createState() => _ZayifKonularScreenState();
}

class _ZayifKonularScreenState extends State<ZayifKonularScreen> {
  ZayifKonuOzet? _ozet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final z = await IstatistikService.getZayifKonuOzet();
    if (!mounted) return;
    setState(() {
      _ozet    = z;
      _loading = false;
    });
  }

  Future<void> _temizle() async {
    final ozet = _ozet;
    if (ozet == null || ozet.toplamCevaplanan <= 0) return;

    final onay = await confirmZayifKonuAnalizTemizle(
      context,
      analizSoruSayisi: ozet.toplamCevaplanan,
    );
    if (!onay || !mounted) return;

    await IstatistikService.clearZayifKonuAnalizi();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ozet = _ozet;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Zayıf Konularım', subtitleFontSize: 14),
        actions: [
          if (ozet != null && ozet.toplamCevaplanan > 0)
            IconButton(
              tooltip: 'Analizi Sıfırla',
              icon: const Icon(Icons.delete_sweep_rounded, color: _cRed),
              onPressed: _temizle,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _buildBody(ozet!),
    );
  }

  Widget _buildBody(ZayifKonuOzet ozet) {
    final yeterli = ozet.yeterliVeri &&
        ozet.toplamCevaplanan >= ZayifKonuService.minToplamCevaplanan;
    final hasWeak = yeterli && ozet.zayifKonuVar;

    if (!hasWeak) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!yeterli) ...[
                _IlerlemeCubugu(
                  mevcut: ozet.toplamCevaplanan,
                  hedef: ozet.minGerekli,
                ),
                const SizedBox(height: 20),
              ],
              Text(
                yeterli
                    ? 'Henüz belirgin zayıf konun yok.\nSınavlara devam et!'
                    : 'Analiz için ${ozet.minGerekli} sınav sorusu gerekli.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _cMuted.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _cGold.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            '${ozet.toplamCevaplanan} sınav sorusu analiz edildi. '
            'Bir alana dokunarak o konudan pratik yapabilirsin.',
            style: TextStyle(
              color: _cGold.withValues(alpha: 0.92),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...ozet.konular.map(
          (konu) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _KonuSatiri(
              konu: konu,
              onTap: () => ZayifKonuPratikService.baslat(context, konu),
            ),
          ),
        ),
      ],
    );
  }
}

class _IlerlemeCubugu extends StatelessWidget {
  const _IlerlemeCubugu({required this.mevcut, required this.hedef});

  final int mevcut;
  final int hedef;

  @override
  Widget build(BuildContext context) {
    final oran  = hedef > 0 ? (mevcut / hedef).clamp(0.0, 1.0) : 0.0;
    final kalan = (hedef - mevcut).clamp(0, hedef);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Analiz için ilerleme',
              style: TextStyle(
                color: _cMuted.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
            Text(
              '$mevcut / $hedef soru',
              style: const TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 6,
            backgroundColor: _cCard,
            valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
          ),
        ),
        if (kalan > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$kalan soru daha',
            style: TextStyle(
              color: _cMuted.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _KonuSatiri extends StatelessWidget {
  const _KonuSatiri({required this.konu, required this.onTap});

  final ZayifKonu konu;
  final VoidCallback onTap;

  Color _barColor(double oran) {
    if (oran >= 0.55) return _cRed;
    if (oran >= 0.40) return _cGold;
    return kAccent;
  }

  @override
  Widget build(BuildContext context) {
    final oran  = konu.hataOrani;
    final color = _barColor(oran);
    final yuzde = (oran * 100).round();

    return Material(
      color: _cCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      konu.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '%$yuzde hata',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: Text(
                  '${konu.yanlisSayisi} yanlış · ${konu.toplamDeneme} soru',
                  style: TextStyle(
                    color: _cMuted.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: oran.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: kBgDark,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
