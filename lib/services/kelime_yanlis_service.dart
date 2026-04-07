import 'package:shared_preferences/shared_preferences.dart';

/// Yanlış yapılan kelime ID'lerini SharedPreferences'a yazar/okur.
/// – Maksimum 100 ID tutulur (FIFO: en eski düşer).
/// – Aynı kelime tekrar yanlış yapılırsa listedeki konumu güncellenir.
/// – Doğru yapılırsa listeden çıkarılır.
class KelimeYanlisService {
  static const _key      = 'kelime_yanlis_ids';
  static const _maxCount = 100;

  static Future<List<int>> getYanlisIdsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toList();
  }

  static Future<int> getCountAsync() async {
    final list = await getYanlisIdsAsync();
    return list.length;
  }

  static Future<void> addYanlis(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_key) ?? [];
    list.remove(id.toString());
    list.add(id.toString());
    if (list.length > _maxCount) {
      list.removeAt(0);
    }
    await prefs.setStringList(_key, list);
  }

  static Future<void> removeYanlis(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_key) ?? [];
    list.remove(id.toString());
    await prefs.setStringList(_key, list);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
