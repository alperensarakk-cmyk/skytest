import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamamlanan sınavların özetini SharedPreferences'a kaydeder.
/// [yuzde] alanı 0–100 arası nottur (100 üzerinden; soru başına 100/toplam).

class SinavSonucu {
  const SinavSonucu({
    required this.tarih,
    required this.dogru,
    required this.yanlis,
    required this.bos,
    required this.toplam,
    required this.yuzde,
    required this.yanlisKategoriler, // {'Bağlaçlar ve Edatlar': 3, ...}
  });

  final DateTime        tarih;
  final int             dogru;
  final int             yanlis;
  final int             bos;
  final int             toplam;
  final double          yuzde;
  final Map<String,int> yanlisKategoriler;

  Map<String, dynamic> toJson() => {
        'tarih':             tarih.toIso8601String(),
        'dogru':             dogru,
        'yanlis':            yanlis,
        'bos':               bos,
        'toplam':            toplam,
        'yuzde':             yuzde,
        'yanlisKategoriler': yanlisKategoriler,
      };

  factory SinavSonucu.fromJson(Map<String, dynamic> j) => SinavSonucu(
        tarih:    DateTime.parse(j['tarih'] as String),
        dogru:    j['dogru']  as int,
        yanlis:   j['yanlis'] as int,
        bos:      j['bos']    as int,
        toplam:   j['toplam'] as int,
        yuzde:    (j['yuzde'] as num).toDouble(),
        yanlisKategoriler: Map<String, int>.from(
          (j['yanlisKategoriler'] as Map).map(
            (k, v) => MapEntry(k as String, v as int),
          ),
        ),
      );
}

class IstatistikService {
  static const _sinavKey = 'sinav_sonuclari';
  static const _maxSinav = 50; // maksimum saklanan sınav

  // ── Sınav Sonuçları ───────────────────────────────────────────────────────

  static Future<List<SinavSonucu>> getSinavSonuclari() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sinavKey) ?? [];
    return raw
        .map((e) => SinavSonucu.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
        .reversed // en yeni önce
        .toList();
  }

  static Future<void> saveSinavSonucu(SinavSonucu sonuc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sinavKey) ?? [];
    raw.add(jsonEncode(sonuc.toJson()));
    if (raw.length > _maxSinav) raw.removeAt(0);
    await prefs.setStringList(_sinavKey, raw);
  }

  // ── Zayıf Kategori Özeti (tüm sınavlardan birleşik) ─────────────────────
  /// Tüm sınavlardaki yanlış kategori sayılarını toplar.
  /// Döndürür: {'Bağlaçlar ve Edatlar': 12, 'Modal Fiiller': 5, ...}
  /// (en çok yanlıştan en aza sıralı)
  static Future<Map<String, int>> getZayifKategoriler() async {
    final sonuclar = await getSinavSonuclari();
    final toplam   = <String, int>{};

    for (final s in sonuclar) {
      s.yanlisKategoriler.forEach((kat, count) {
        toplam[kat] = (toplam[kat] ?? 0) + count;
      });
    }

    final sorted = Map.fromEntries(
      toplam.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sinavKey);
  }
}
