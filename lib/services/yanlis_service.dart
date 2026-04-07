import 'package:shared_preferences/shared_preferences.dart';

/// Yanlış yapılan soru ID'lerini SharedPreferences'a yazar/okur.
/// – Maksimum 50 ID tutulur (FIFO: en eski düşer).
/// – Aynı soru tekrar yanlış yapılırsa listedeki konumu güncellenir.
/// – Doğru yapılırsa listeden çıkarılır.
class YanlisService {
  static const _key      = 'yanlis_ids';
  static const _maxCount = 50;

  // ── Oku ────────────────────────────────────────────────────────────────────
  static Future<List<int>> getYanlisIdsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toList();
  }

  static Future<int> getCountAsync() async {
    final list = await getYanlisIdsAsync();
    return list.length;
  }

  // ── Yanlış ekle ────────────────────────────────────────────────────────────
  /// Eğer ID zaten varsa önce çıkar, sona ekle (en taze).
  /// 50 limitini aşarsa baştaki (en eski) düşer.
  static Future<void> addYanlis(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_key) ?? [];

    list.remove(id.toString());   // varsa eski konumunu temizle
    list.add(id.toString());      // sona (en taze) ekle

    if (list.length > _maxCount) {
      list.removeAt(0);           // en eski düşür
    }

    await prefs.setStringList(_key, list);
  }

  // ── Doğru yapılınca çıkar ──────────────────────────────────────────────────
  static Future<void> removeYanlis(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_key) ?? [];
    list.remove(id.toString());
    await prefs.setStringList(_key, list);
  }

  // ── Toplu ekle (sınav bitişi) ──────────────────────────────────────────────
  static Future<void> addMultiple(List<int> ids) async {
    for (final id in ids) {
      await addYanlis(id);
    }
  }

  // ── Listeyi tamamen sil ────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
