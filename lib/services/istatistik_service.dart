import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sinav_sonucu.dart';
import 'calisma_istatistik_service.dart';
import 'zayif_konu_service.dart';

/// Tamamlanan sınav özetlerini SharedPreferences'a kaydeder.
class IstatistikService {
  static const _sinavKey = 'sinav_sonuclari';
  static const _maxSinav = 50;
  static const _analizMigrationKey = 'zayif_konu_analiz_migration_v';
  static const _analizMigrationVersion = 4;

  static Future<List<SinavSonucu>> getSinavSonuclari() async {
    await _migrateAnalizVerisi();
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sinavKey) ?? [];
    return raw
        .map((e) => SinavSonucu.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  /// Eski / tutarsız konuPerformans kayıtlarını analiz dışı bırakır.
  static Future<void> _migrateAnalizVerisi() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt(_analizMigrationKey) ?? 0) >= _analizMigrationVersion) {
      return;
    }

    final raw = prefs.getStringList(_sinavKey) ?? [];
    if (raw.isEmpty) {
      await prefs.setInt(_analizMigrationKey, _analizMigrationVersion);
      return;
    }

    final updated = <String>[];
    for (final entry in raw) {
      final j = Map<String, dynamic>.from(
        jsonDecode(entry) as Map<String, dynamic>,
      );
      updated.add(jsonEncode(_stripZayifKonuAnalizi(j)));
    }

    await prefs.setStringList(_sinavKey, updated);
    await prefs.setInt(_analizMigrationKey, _analizMigrationVersion);
  }

  static Map<String, dynamic> _stripZayifKonuAnalizi(Map<String, dynamic> j) {
    j.remove('konuPerformans');
    j.remove('analizVersiyonu');
    return j;
  }

  /// Zayıf konu analiz geçmişini sıfırlar (sınav skor kayıtları kalır).
  static Future<void> clearZayifKonuAnalizi() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sinavKey) ?? [];
    if (raw.isEmpty) return;

    final updated = raw
        .map((e) => jsonEncode(
              _stripZayifKonuAnalizi(
                Map<String, dynamic>.from(
                  jsonDecode(e) as Map<String, dynamic>,
                ),
              ),
            ))
        .toList();

    await prefs.setStringList(_sinavKey, updated);
  }

  static Future<void> saveSinavSonucu(SinavSonucu sonuc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_sinavKey) ?? [];
    raw.add(jsonEncode(sonuc.toJson()));
    if (raw.length > _maxSinav) raw.removeAt(0);
    await prefs.setStringList(_sinavKey, raw);
  }

  static Future<ZayifKonuOzet> getZayifKonuOzet() async {
    final sonuclar = await getSinavSonuclari();
    return ZayifKonuService.hesapla(sonuclar);
  }

  static Future<List<ZayifKonu>> getZayifKonular() async {
    final ozet = await getZayifKonuOzet();
    return ozet.konular;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sinavKey);
    await CalismaIstatistikService.clearAll();
  }
}
