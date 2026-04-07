import 'package:shared_preferences/shared_preferences.dart';

/// Ana ekranda gösterilen hedef sınav tarihi (geri sayım).
class ExamCountdownService {
  ExamCountdownService._();

  static const _kTargetIso = 'exam_target_date_yyyy_mm_dd';

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// Kayıtlı hedef gün (saat yok, yerel takvim günü).
  static Future<DateTime?> getTargetDate() async {
    final raw = (await _p()).getString(_kTargetIso);
    if (raw == null || raw.isEmpty) return null;
    final p = raw.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static Future<void> setTargetDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final iso =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await (await _p()).setString(_kTargetIso, iso);
  }

  static Future<void> clearTargetDate() async {
    await (await _p()).remove(_kTargetIso);
  }

  /// Bugün ile hedef gün arasındaki tam gün farkı (hedef − bugün).
  /// Hedef geçmişse negatif, yoksa null.
  static Future<int?> daysRemaining() async {
    final target = await getTargetDate();
    if (target == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(target.year, target.month, target.day);
    return exam.difference(today).inDays;
  }

  static String formatDateTr(DateTime d) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
