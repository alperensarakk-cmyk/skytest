import 'package:flutter/material.dart';

import '../screens/konu_pratik_screen.dart';
import '../services/soru_secim_service.dart';
import '../services/soru_son_gorulen_service.dart';
import '../services/soru_yukleme_service.dart';
import '../services/zayif_konu_service.dart';
import '../theme/app_theme.dart';

/// Zayıf konu satırına tıklanınca o soru tipinden kısa pratik oturumu açar.
class ZayifKonuPratikService {
  ZayifKonuPratikService._();

  static Future<void> baslat(
    BuildContext context,
    ZayifKonu konu,
  ) async {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kAccent),
      ),
    );

    try {
      final all = await SoruYuklemeService.tumSorulariYukle();
      final filtered = all
          .where((s) => ZayifKonuService.soruTipKeyEslesir(s, konu.tipKey))
          .toList();

      final avoid = await SoruSonGorulenService.getAvoidSet();
      final hedef = ZayifKonuService.pratikSoruSayisi.clamp(1, filtered.length);
      final sorular = SoruSecimService.secDengeli(
        filtered,
        hedef,
        useRandomization: true,
        avoidRecentIds: avoid,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (sorular.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${konu.label} konusunda soru bulunamadı.')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KonuPratikScreen(
            kategoriAdi: konu.label,
            sorular: sorular,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('ZayifKonuPratikService.baslat: $e\n$st');
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorular yüklenemedi. Lütfen tekrar dene.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
