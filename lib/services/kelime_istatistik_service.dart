import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class KelimeIstatistikService {
  static const _keyPrefix = 'kelime_stats_';

  static String _todayKey() {
    final now = DateTime.now();
    return '$_keyPrefix${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ── Cevap kaydet ──────────────────────────────────────────────────────────
  static Future<void> recordAnswer({
    required String modul,
    required bool   correct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key   = _todayKey();
    final raw   = prefs.getString(key);

    Map<String, dynamic> data = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : {'total': 0, 'correct': 0, 'moduller': <String, dynamic>{}};

    data['total']   = (data['total']   as int) + 1;
    if (correct) data['correct'] = (data['correct'] as int) + 1;

    final moduller  = Map<String, dynamic>.from(data['moduller'] as Map);
    if (!moduller.containsKey(modul)) {
      moduller[modul] = {'total': 0, 'yanlis': 0};
    }
    final m = Map<String, dynamic>.from(moduller[modul] as Map);
    m['total']  = (m['total']  as int) + 1;
    if (!correct) m['yanlis'] = (m['yanlis'] as int) + 1;
    moduller[modul] = m;
    data['moduller'] = moduller;

    await prefs.setString(key, jsonEncode(data));
  }

  // ── Bugünkü istatistikler ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTodayStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_todayKey());
    if (raw == null) {
      return {'total': 0, 'correct': 0, 'moduller': <String, dynamic>{}};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── En zayıf modül (en çok yanlış) ───────────────────────────────────────
  static Future<String?> getZayifModul() async {
    final stats   = await getTodayStats();
    final moduller = stats['moduller'] as Map<String, dynamic>;
    if (moduller.isEmpty) return null;

    String? worst;
    int     maxYanlis = 0;
    for (final entry in moduller.entries) {
      final yanlis = (entry.value as Map)['yanlis'] as int;
      if (yanlis > maxYanlis) {
        maxYanlis = yanlis;
        worst     = entry.key;
      }
    }
    return worst;
  }

  // ── Tüm kelime istatistiklerini sıfırla ──────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
