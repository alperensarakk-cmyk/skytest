import 'package:shared_preferences/shared_preferences.dart';

import '../models/sinav_sonucu.dart';

/// Kullanıcı çalışma süresi ve aktif gün serisi (ana ekran istatistik şeridi).
class CalismaIstatistikService {
  CalismaIstatistikService._();

  static const _kTotalSec = 'calisma_total_sec';
  static const _kActiveDays = 'calisma_active_days';
  static const _kHoursMigrated = 'calisma_hours_migrated_v1';
  static const _kDashboardEpoch = 'dashboard_stats_epoch_v1';
  static const _kDashboardResetDone = 'dashboard_stats_reset_v1';

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static Future<SharedPreferences> _prefs() =>
      SharedPreferences.getInstance();

  /// Tamamlanan çalışma / sınav oturumu süresini kaydeder.
  static Future<void> recordOturum({required int saniye}) async {
    if (saniye <= 0) return;
    final prefs = await _prefs();
    final cur = prefs.getInt(_kTotalSec) ?? 0;
    await prefs.setInt(_kTotalSec, cur + saniye);
    await _markToday(prefs);
  }

  static Future<void> _markToday(SharedPreferences prefs) async {
    final today = _todayKey();
    final days = prefs.getStringList(_kActiveDays) ?? [];
    if (days.contains(today)) return;
    days.add(today);
    days.sort();
    if (days.length > 400) {
      days.removeRange(0, days.length - 400);
    }
    await prefs.setStringList(_kActiveDays, days);
  }

  /// Güncelleme sonrası ana ekran şeridini sıfırlar; eski sınavlar sayılmaz.
  static Future<void> _ensureDashboardReset() async {
    final prefs = await _prefs();
    if (prefs.getBool(_kDashboardResetDone) == true) return;

    final epoch = DateTime.now();
    await prefs.setString(_kDashboardEpoch, epoch.toIso8601String());
    await prefs.setInt(_kTotalSec, 0);
    await prefs.setStringList(_kActiveDays, []);
    await prefs.setBool(_kHoursMigrated, true);
    await prefs.setBool(_kDashboardResetDone, true);
  }

  static Future<DateTime?> _dashboardEpoch() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_kDashboardEpoch);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static List<SinavSonucu> _sonuclarForDashboard(
    List<SinavSonucu> sonuclar,
    DateTime? epoch,
  ) {
    if (epoch == null) return sonuclar;
    return sonuclar.where((s) => !s.tarih.isBefore(epoch)).toList();
  }

  static Future<void> _syncExamDays(List<SinavSonucu> sonuclar) async {
    if (sonuclar.isEmpty) return;
    final prefs = await _prefs();
    final days = prefs.getStringList(_kActiveDays) ?? [];
    final set = days.toSet();
    for (final s in sonuclar) {
      final d = s.tarih;
      set.add(
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}',
      );
    }
    final merged = set.toList()..sort();
    if (merged.length > 400) {
      merged.removeRange(0, merged.length - 400);
    }
    await prefs.setStringList(_kActiveDays, merged);
  }

  static Set<DateTime> _parseDays(List<String> raw) {
    final out = <DateTime>{};
    for (final d in raw) {
      final parts = d.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (y == null || m == null || day == null) continue;
      out.add(DateTime(y, m, day));
    }
    return out;
  }

  static int hesaplaGunSerisi(Set<DateTime> gunler) {
    if (gunler.isEmpty) return 0;
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!gunler.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var seri = 0;
    while (gunler.contains(cursor)) {
      seri++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return seri;
  }

  static int calismaSaatiFromSaniye(int saniye) {
    if (saniye <= 0) return 0;
    return (saniye / 3600).round().clamp(0, 999999);
  }

  static int basariYuzdesi(List<SinavSonucu> sonuclar) {
    if (sonuclar.isEmpty) return 0;
    final dogru = sonuclar.fold<int>(0, (s, e) => s + e.dogru);
    final toplam = sonuclar.fold<int>(0, (s, e) => s + e.toplam);
    if (toplam <= 0) return 0;
    return (dogru * 100 / toplam).round().clamp(0, 100);
  }

  /// Ana ekran istatistik şeridi verileri (güncelleme sonrası kayıtlar).
  static Future<({
    int tamamlananSinav,
    int calismaSaati,
    int gunSerisi,
    int basariYuzde,
  })> dashboardOzet(List<SinavSonucu> sonuclar) async {
    await _ensureDashboardReset();
    final epoch = await _dashboardEpoch();
    final filtered = _sonuclarForDashboard(sonuclar, epoch);

    await _syncExamDays(filtered);

    final prefs = await _prefs();
    final saniye = prefs.getInt(_kTotalSec) ?? 0;
    final gunler = _parseDays(prefs.getStringList(_kActiveDays) ?? []);

    return (
      tamamlananSinav: filtered.length,
      calismaSaati: calismaSaatiFromSaniye(saniye),
      gunSerisi: hesaplaGunSerisi(gunler),
      basariYuzde: basariYuzdesi(filtered),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await _prefs();
    await prefs.remove(_kTotalSec);
    await prefs.remove(_kActiveDays);
    await prefs.remove(_kHoursMigrated);
    await prefs.remove(_kDashboardEpoch);
    await prefs.remove(_kDashboardResetDone);
  }
}
