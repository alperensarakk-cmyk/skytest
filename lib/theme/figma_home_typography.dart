import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Figma home-screen typography (Red Hat Display — node IDs in comments).
abstract final class FigmaHomeTypography {
  static TextStyle _base({
    required double fontSize,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.redHatDisplay(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// 17:2631 Merhaba 👋
  static TextStyle merhaba(double scale) => _base(
        fontSize: 13.443608283996582 * scale,
        weight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.800000011920929),
        height: 17.633825302124023 / 13.443608283996582,
      );

  /// 17:2633 Bugün ne çalışmak istersin?
  static TextStyle heroTitle(double scale) => _base(
        fontSize: 24 * scale,
        weight: FontWeight.w700,
        color: Colors.white,
        height: 29.767993927001953 / 24,
        letterSpacing: -0.3,
      );

  /// 35:1883 AeroTest
  static TextStyle appTitle(double scale) => _base(
        fontSize: 17.28464126586914 * scale,
        weight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.4,
      );

  /// 35:1886 alt başlık — okunabilirlik için Figma'dan hafif büyütüldü
  static TextStyle appSubtitle(double scale) => _base(
        fontSize: 10.8 * scale,
        weight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.78),
        letterSpacing: 0.02,
        height: 1.28,
      );

  /// 31:1129 Nasıl çalışır?
  static TextStyle helpLink(double scale) => _base(
        fontSize: 8.64232063293457 * scale,
        weight: FontWeight.w700,
        color: const Color(0xFFB7C9E8),
      );

  /// 17:2988 Sınava kalan süre
  static TextStyle countdownLabel(double scale) => _base(
        fontSize: 12 * scale,
        weight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.95),
      );

  /// 17:2992 countdown value
  static TextStyle countdownValue(double scale) => _base(
        fontSize: 28 * scale,
        weight: FontWeight.w800,
        color: Colors.white,
        height: 1.0,
        letterSpacing: 0.5,
      );

  /// 17:2995 Gün / Saat / Dakika
  static TextStyle countdownUnit(double scale) => _base(
        fontSize: 11 * scale,
        weight: FontWeight.w700,
        color: Colors.white.withValues(alpha: 0.82),
      );

  /// 17:3050 Sınav Modu
  static TextStyle sinavTitle(double scale) => _base(
        fontSize: 17.28464126586914 * scale,
        weight: FontWeight.w700,
        color: Colors.white,
      );

  /// 17:3052 Önerilen
  static TextStyle sinavBadge(double scale) => _base(
        fontSize: 10.562836647033691 * scale,
        weight: FontWeight.w500,
        color: const Color(0xFF5EEAD4),
      );

  /// 17:3055 gerçek sınav gibi test et.
  static TextStyle sinavSubtitle(double scale) => _base(
        fontSize: 14 * scale,
        weight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.699999988079071),
        height: 1.15,
      );

  /// 17:3267 / 17:3289 / 17:3311 / 17:3333 card titles (Figma 15 + 1px, Bold)
  static TextStyle studyTitle(double scale) => _base(
        fontSize: 16 * scale,
        weight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
      );

  /// 17:3269 Konulara subtitle (Figma 10 + 2px okunabilirlik)
  static TextStyle studySubKonular(double scale) => _base(
        fontSize: 12 * scale,
        weight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.8500000238418579),
        height: 1.2,
      );

  /// 17:3291 / 17:3313 Kalıp & Kelime subtitles (Figma 11 + 1px)
  static TextStyle studySubAccent(double scale) => _base(
        fontSize: 12 * scale,
        weight: FontWeight.w400,
        color: const Color(0xFFDCE2FF),
        height: 1.2,
      );

  /// 17:3335 Haftalık subtitle (Figma 10 + 2px)
  static TextStyle studySubHaftalik(double scale) => _base(
        fontSize: 12 * scale,
        weight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.8500000238418579),
        height: 1.2,
      );

  /// 15:2486 stat values (38-182, 15-193, …)
  static TextStyle statValue(double scale) => _base(
        fontSize: 13.443608283996582 * scale,
        weight: FontWeight.w700,
        color: Colors.white,
        height: 1.0,
      );

  /// 15:2498 stat labels
  static TextStyle statLabel(double scale) => _base(
        fontSize: 9.122448921203613 * scale,
        weight: FontWeight.w400,
        color: Colors.white.withValues(alpha: 0.800000011920929),
        height: 1.0,
      );
}

/// Figma study-card layout (`17:3277` DIV-99, 191.86×137).
abstract final class FigmaStudyCardLayout {
  static const figmaWidth = 194.90489196777344;
  static const figmaHeight = 137.04249572753906;
  static const padding = 16.426206588745117;
  static const iconBox = 28.753984451293945;
  static const iconTop = 16.426206588745117;
  static const titleTop = 51.55877733230591;
  static const subtitleTop = 68.74270248413086;
  static const subtitleWidth = 96.0;
  static const arrowTop = 99.3;
  static const arrowSize = 22.4;
  static const artLeft = 107.1;
  static const artTop = 58.8;
  static const artWidth = 78.74;
  static const artHeight = 75.86;

  /// Sağ 3D illüstrasyon — Figma üstüne hafif büyütme.
  static const artBoost = 1.18;

  /// Sağ illüstrasyon — kart genişliğine oran (Figma ~%41).
  static const artWidthFactor = 0.32;
  static const referenceCardW = 191.85951232910156;
  static const referenceCardH = 137.04249572753906;

  /// Kart metni — Figma üstüne ~1–2 tık (görünür ama abartısız).
  static const textBoost = 1.07;
}

/// Scale factor: card width vs Figma 194.9px reference.
double figmaCardScale(double cardWidth) =>
    (cardWidth / FigmaStudyCardLayout.figmaWidth).clamp(0.72, 1.08);

/// Scale factor: full home frame 430px.
double figmaHomeScale(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w / 430).clamp(0.85, 1.12);
}
