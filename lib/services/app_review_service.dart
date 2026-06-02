import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../widgets/app_review_sheet.dart';

/// Mağaza değerlendirme kartı — oturum bitişlerinde ve Ayarlar’dan.
///
/// Kurallar:
/// - 4–5 yıldız + mağaza → bir daha otomatik gösterilmez
/// - 1–3 yıldız + geri bildirim → bir daha otomatik gösterilmez
/// - Hayır / Sonra (puan vermeden) → 7 gün sonra tekrar denenebilir
/// - Otomatik kart: ilk uygun tamamlamada; tekrar gösterim min. 7 gün
/// - Kelime / konu: 5. kelime veya sorudan sonra (sonsuz oturum dahil)
class AppReviewService {
  AppReviewService._();

  static const _kRated = 'app_review_has_rated';
  static const _kPostponedAtMs = 'app_review_postponed_at_ms';
  static const _kLastAutoPromptMs = 'app_review_last_auto_prompt_ms';
  static const _kCompletionCount = 'app_review_completion_count';
  static const _cooldownDays = 7;
  static const _minCompletionsForAuto = 1;

  /// Kelime ve konu pratiğinde kaçıncı öğeden sonra kart denenir.
  static const int milestoneItemCount = 5;

  static final InAppReview _inAppReview = InAppReview.instance;

  static Future<bool> hasRated() async =>
      (await SharedPreferences.getInstance()).getBool(_kRated) ?? false;

  /// Tamamlanan çalışma / sınav / oyun oturumu (+1).
  static Future<void> recordCompletion() async {
    final p = await SharedPreferences.getInstance();
    final n = (p.getInt(_kCompletionCount) ?? 0) + 1;
    await p.setInt(_kCompletionCount, n);
  }

  static bool _withinCooldown(int? ms) {
    if (ms == null) return false;
    final elapsed = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    return elapsed.inDays < _cooldownDays;
  }

  static Future<bool> shouldShowAutoPrompt() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kRated) == true) return false;

    if (_withinCooldown(p.getInt(_kPostponedAtMs))) return false;
    if (_withinCooldown(p.getInt(_kLastAutoPromptMs))) return false;

    final completions = p.getInt(_kCompletionCount) ?? 0;
    return completions >= _minCompletionsForAuto;
  }

  static Future<void> recordAutoPromptDisplayed() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _kLastAutoPromptMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Kelime / konu: [answeredCount] soru veya kelime cevaplandıktan sonra.
  static int milestoneTriggerAt(int sessionTotal) {
    if (sessionTotal <= 0) return milestoneItemCount;
    return sessionTotal < milestoneItemCount
        ? sessionTotal
        : milestoneItemCount;
  }

  static Future<void> markRated() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRated, true);
    await p.remove(_kPostponedAtMs);
  }

  static Future<void> markPostponed() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _kPostponedAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Oturum / eşik sonrası: sayacı artır, uygunsa kartı göster.
  static Future<void> tryShowAfterCompletion(BuildContext context) async {
    await recordCompletion();
    if (!context.mounted) return;
    if (!await shouldShowAutoPrompt()) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    await recordAutoPromptDisplayed();
    if (!context.mounted) return;
    await showAppReviewSheet(context);
  }

  /// Ayarlar → her zaman açılır (zaten puanladıysa mağazaya gider).
  static Future<void> openFromSettings(BuildContext context) async {
    if (await hasRated()) {
      await openStoreListing();
      return;
    }
    if (!context.mounted) return;
    await showAppReviewSheet(context, fromSettings: true);
  }

  static Future<void> openStoreListing() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.openStoreListing(
        appStoreId: '6761938550',
      );
      return;
    }
    final url = (!kIsWeb && Platform.isIOS) ? kAppStoreUrl : kPlayStoreUrl;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> requestInAppReviewThenStore() async {
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    } else {
      await openStoreListing();
    }
  }

  static Future<void> openFeedbackEmail({int? stars}) async {
    final subject = stars != null
        ? 'AeroTest Geri Bildirim ($stars/5)'
        : 'AeroTest Geri Bildirim';
    final uri = Uri(
      scheme: 'mailto',
      path: 'aerotest.app@outlook.com',
      queryParameters: {'subject': subject},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      debugPrint('AppReviewService: e-posta açılamadı');
    }
  }
}
