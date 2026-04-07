import 'package:shared_preferences/shared_preferences.dart';

import 'premium_service.dart';

/// Ücretsiz kullanıcı günlük limitleri (yerel takvim günü).
class DailyLimitService {
  DailyLimitService._();

  static const int freeExamQuestionsPerDay = 10;
  static const int freeKonuPerDay          = 5;
  static const int freeKaliplarCardsPerDay = 5;
  static const int freeKelimePerDay        = 10;

  static const _kDate       = 'daily_limit_date_yyyy_mm_dd';
  static const _kExamQ      = 'daily_limit_exam_questions';
  static const _kKonuQ      = 'daily_limit_konu_answers';
  static const _kKalipMaxIx = 'daily_limit_kalip_max_index';
  static const _kKelime     = 'daily_limit_kelime_answers';

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
    await prefs.setInt(_kKelime, 0);
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

  /// Ücretsiz: en fazla [freeKaliplarCardsPerDay] kart (indeks 0..4).
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

  // ── Kelime pratiği: cevaplanan kelime ─────────────────────────────────────
  static Future<int> kelimeAnsweredToday() async {
    await ensureDay();
    if (await _isPremium()) return 0;
    return (await _p()).getInt(_kKelime) ?? 0;
  }

  static Future<int> kelimeRemaining() async {
    if (await _isPremium()) return 999999;
    final u = await kelimeAnsweredToday();
    return (freeKelimePerDay - u).clamp(0, freeKelimePerDay);
  }

  static Future<void> recordKelimeAnswered() async {
    if (await _isPremium()) return;
    await ensureDay();
    final prefs = await _p();
    final cur = prefs.getInt(_kKelime) ?? 0;
    await prefs.setInt(_kKelime, cur + 1);
  }
}
