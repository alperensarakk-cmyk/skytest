import 'package:shared_preferences/shared_preferences.dart';

/// Son oturumlarda gösterilen soru ID'lerini tutar; yeni seçimde aynı soruların
/// sürekli başta gelmesini azaltmak için kullanılır.
class SoruSonGorulenService {
  SoruSonGorulenService._();

  static const _key = 'soru_son_gorulen_ids';
  static const _maxStored = 450;

  static Future<Set<int>> getAvoidSet() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map(int.parse).toSet();
  }

  static Future<void> recordSessionIds(Iterable<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final prev = prefs.getStringList(_key) ?? [];
    final next = <String>[...prev, ...ids.map((e) => e.toString())];
    if (next.length > _maxStored) {
      next.removeRange(0, next.length - _maxStored);
    }
    await prefs.setStringList(_key, next);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
