import 'package:shared_preferences/shared_preferences.dart';

import 'exam_countdown_service.dart';
import 'soru_son_gorulen_service.dart';

/// Uygulama genelindeki tüm kullanıcı ayarlarını yönetir.
/// Her ayar için varsayılan değer bu sınıfta tanımlıdır.
class SettingsService {
  // ── Key sabitleri ──────────────────────────────────────────────────────────
  static const kAutoNextPractice   = 'setting_auto_next_practice';
  static const kShowAnalysisPanel  = 'setting_show_analysis_default';
  static const kTextScale          = 'setting_text_scale'; // 'small'|'medium'|'large'

  static const kExamQuestionCount  = 'setting_exam_question_count'; // 20|30|40
  static const kExamDurationMin    = 'setting_exam_duration_min';   // 20|30|45|60
  static const kExamAutoNext       = 'setting_exam_auto_next';

  static const kKelimeSetSize      = 'setting_kelime_set_size';     // 0=sonsuz|10|20|30|50

  // ── Varsayılanlar ──────────────────────────────────────────────────────────
  static const bool   _defAutoNextPractice  = true;
  static const bool   _defShowAnalysisPanel = true;
  static const String _defTextScale         = 'medium';
  static const int    _defExamQuestionCount = 30;
  static const int    _defExamDurationMin   = 30;
  static const bool   _defExamAutoNext      = true;
  static const int    _defKelimeSetSize     = 0; // 0 = sonsuz

  // ── Okuma ─────────────────────────────────────────────────────────────────
  static Future<bool>   getAutoNextPractice()  async =>
      (await _p()).getBool(kAutoNextPractice)  ?? _defAutoNextPractice;

  static Future<bool>   getShowAnalysisPanel() async =>
      (await _p()).getBool(kShowAnalysisPanel) ?? _defShowAnalysisPanel;

  static Future<String> getTextScale()         async =>
      (await _p()).getString(kTextScale)       ?? _defTextScale;

  static Future<int>    getExamQuestionCount() async =>
      (await _p()).getInt(kExamQuestionCount)  ?? _defExamQuestionCount;

  static Future<int>    getExamDurationMin()   async =>
      (await _p()).getInt(kExamDurationMin)    ?? _defExamDurationMin;

  static Future<bool>   getExamAutoNext()      async =>
      (await _p()).getBool(kExamAutoNext)      ?? _defExamAutoNext;

  static Future<int>    getKelimeSetSize()    async =>
      (await _p()).getInt(kKelimeSetSize)      ?? _defKelimeSetSize;

  // ── Yazma ─────────────────────────────────────────────────────────────────
  static Future<void> setAutoNextPractice(bool v)   async =>
      (await _p()).setBool(kAutoNextPractice, v);

  static Future<void> setShowAnalysisPanel(bool v)  async =>
      (await _p()).setBool(kShowAnalysisPanel, v);

  static Future<void> setTextScale(String v)        async =>
      (await _p()).setString(kTextScale, v);

  static Future<void> setExamQuestionCount(int v)   async =>
      (await _p()).setInt(kExamQuestionCount, v);

  static Future<void> setExamDurationMin(int v)     async =>
      (await _p()).setInt(kExamDurationMin, v);

  static Future<void> setExamAutoNext(bool v)       async =>
      (await _p()).setBool(kExamAutoNext, v);

  static Future<void> setKelimeSetSize(int v)       async =>
      (await _p()).setInt(kKelimeSetSize, v);

  // ── Sıfırlama (Veri Yönetimi) ─────────────────────────────────────────────
  static Future<void> resetAll() async {
    final p = await _p();
    await p.remove(kAutoNextPractice);
    await p.remove(kShowAnalysisPanel);
    await p.remove(kTextScale);
    await p.remove(kExamQuestionCount);
    await p.remove(kExamDurationMin);
    await p.remove(kExamAutoNext);
    await p.remove(kKelimeSetSize);
    await ExamCountdownService.clearTargetDate();
    // Eski günlük bildirim anahtarları (kaldırıldı)
    await p.remove('setting_daily_reminder_enabled');
    await p.remove('setting_daily_reminder_hour');
    await p.remove('setting_daily_reminder_minute');
    await p.remove('setting_daily_reminder_msg_idx');
    await p.remove('setting_daily_reminder_first_ymd');
    await SoruSonGorulenService.clear();
  }

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();
}
