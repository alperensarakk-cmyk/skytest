import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kalip_model.dart';
import 'kelime_session_service.dart';
import 'premium_service.dart';

/// Ücretsiz kullanıcı günlük limitleri (yerel takvim günü).
class DailyLimitService {
  DailyLimitService._();

  static const int freeExamQuestionsPerDay = 10;
  static const int freeKonuPerDay          = 5;
  static const int freeKaliplarCardsPerDay = 5;
  static const int freeKelimeSessionsPerDay = 1;

  static const _kDate       = 'daily_limit_date_yyyy_mm_dd';
  static const _kExamQ      = 'daily_limit_exam_questions';
  static const _kKonuQ      = 'daily_limit_konu_answers';
  static const _kKalipMaxIx = 'daily_limit_kalip_max_index';
  static const _kKalipOrderIds = 'daily_limit_kalip_order_ids';
  static const _kKelimeSessions = 'daily_limit_kelime_sessions';

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// Gün değiştiyse sayaçları sıfırla.
  static Future<void> ensureDay() async {
    final prefs = await _p();
    final today = _today();
    final stored = prefs.getString(_kDate);
    if (stored == today) return;
    await prefs.setString(_kDate, today);
    await prefs.setInt(_kExamQ, 0);
    await prefs.setInt(_kKonuQ, 0);
    await prefs.setInt(_kKalipMaxIx, -1);
    await prefs.remove(_kKalipOrderIds);
    await prefs.setInt(_kKelimeSessions, 0);
    await KelimeSessionService.onDayChanged();
  }

  static Future<bool> _isPremium() => PremiumService.isPremiumUser();

  // ── Sınav: bugün çözülen sınav sorusu toplamı ─────────────────────────────
  static Future<int> examQuestionsUsedToday() async {
    await ensureDay();
    if (await _isPremium()) return 0;
    return (await _p()).getInt(_kExamQ) ?? 0;
  }

  static Future<int> examQuestionsRemaining() async {
    if (await _isPremium()) return 999999;
    final u = await examQuestionsUsedToday();
    return (freeExamQuestionsPerDay - u).clamp(0, freeExamQuestionsPerDay);
  }

  static Future<void> recordExamCompleted(int questionCount) async {
    if (await _isPremium()) return;
    await ensureDay();
    final prefs = await _p();
    final cur = prefs.getInt(_kExamQ) ?? 0;
    await prefs.setInt(_kExamQ, cur + questionCount);
  }

  // ── Konu pratiği: cevaplanan soru ────────────────────────────────────────
  static Future<int> konuAnsweredToday() async {
    await ensureDay();
    if (await _isPremium()) return 0;
    return (await _p()).getInt(_kKonuQ) ?? 0;
  }

  static Future<int> konuRemaining() async {
    if (await _isPremium()) return 999999;
    final u = await konuAnsweredToday();
    return (freeKonuPerDay - u).clamp(0, freeKonuPerDay);
  }

  static Future<void> recordKonuAnswered() async {
    if (await _isPremium()) return;
    await ensureDay();
    final prefs = await _p();
    final cur = prefs.getInt(_kKonuQ) ?? 0;
    await prefs.setInt(_kKonuQ, cur + 1);
  }

  /// Ücretsiz: en fazla [freeKaliplarCardsPerDay] kart (0 tabanlı indeks).
  static Future<int> kaliplarMaxAllowedIndex() async {
    if (await _isPremium()) return 1 << 30;
    return freeKaliplarCardsPerDay - 1;
  }

  static Future<void> recordKaliplarPageIndex(int index) async {
    if (await _isPremium()) return;
    await ensureDay();
    final prefs = await _p();
    final prev = prefs.getInt(_kKalipMaxIx) ?? -1;
    if (index > prev) await prefs.setInt(_kKalipMaxIx, index);
  }

  static Future<int> kaliplarMaxReachedToday() async {
    await ensureDay();
    return (await _p()).getInt(_kKalipMaxIx) ?? -1;
  }

  /// Ücretsiz: günün sabit 5 kalıbı (giriş-çıkışta aynı liste). Premium: tümü karışık.
  static Future<List<KalipModel>> kaliplarDeckForToday(
    List<KalipModel> all,
  ) async {
    if (await _isPremium()) {
      final out = List<KalipModel>.from(all)..shuffle(Random());
      return out;
    }
    await ensureDay();
    final orderIds = await _getOrCreateKalipOrderIds(all);
    final byId = {for (final k in all) k.id: k};
    final ordered = [
      for (final id in orderIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    return ordered.take(freeKaliplarCardsPerDay).toList();
  }

  static Future<List<int>> _getOrCreateKalipOrderIds(List<KalipModel> all) async {
    final prefs = await _p();
    final allIds = all.map((k) => k.id).toSet();
    final raw = prefs.getString(_kKalipOrderIds);
    if (raw != null && raw.isNotEmpty) {
      final saved = raw
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .where(allIds.contains)
          .toList();
      if (saved.isNotEmpty) return saved;
    }
    final shuffled = List<KalipModel>.from(all)..shuffle(Random());
    final ids = shuffled.map((k) => k.id).toList();
    await prefs.setString(_kKalipOrderIds, ids.join(','));
    return ids;
  }

  // ── Kelime oturumu: tamamlanan oturum (10 liste + 10 test) ────────────────
  static Future<int> kelimeSessionsCompletedToday() async {
    await ensureDay();
    if (await _isPremium()) return 0;
    return (await _p()).getInt(_kKelimeSessions) ?? 0;
  }

  static Future<int> kelimeSessionsRemaining() async {
    if (await _isPremium()) return 999999;
    final u = await kelimeSessionsCompletedToday();
    return (freeKelimeSessionsPerDay - u).clamp(0, freeKelimeSessionsPerDay);
  }

  static Future<void> recordKelimeSessionCompleted() async {
    if (await _isPremium()) return;
    await ensureDay();
    final prefs = await _p();
    final cur = prefs.getInt(_kKelimeSessions) ?? 0;
    await prefs.setInt(_kKelimeSessions, cur + 1);
  }
}
