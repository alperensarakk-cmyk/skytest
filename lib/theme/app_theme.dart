import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Renk Paleti ──────────────────────────────────────────────────────────────
const Color kBgDark        = Color(0xFF0B132B);
const Color kBgCard        = Color(0xFF1C2541);
const Color kAccent        = Color(0xFF2CAEFE);
const Color kTextPrimary   = Color(0xFFFFFFFF);
const Color kTextSecondary = Color(0xFFB7C9E8);

/// Figma Background tokens (AeroTest- anasayfa frame fill).
const Color kBgPrimary          = Color(0xFF00091C);
const Color kBgGradientTop      = Color(0xFF00091C);
const Color kBgGradientBottom   = Color(0xFF01091B);
const Color kBgSecondary        = Color(0xFF071B3A);

/// Figma Accent tokens.
const Color kAccentBlueGlow     = Color(0xFF3B82F6);
const Color kAccentPurple       = Color(0xFF7C4DFF);
const Color kAccentYellow       = Color(0xFFF7C948);
const Color kAccentTeal         = Color(0xFF5EEAD4);
const Color kAccentGreen        = Color(0xFF4ADE80);
const Color kAccentOrange       = Color(0xFFFF6B35);

/// Figma Border tokens.
const Color kBorderSubtle       = Color(0x0DFFFFFF);
const Color kBorderBlue         = Color(0x4038BDF8);

/// Figma Spacing (Boşluk).
const double kSpaceXs = 4;
const double kSpaceSm = 8;
const double kSpaceMd = 12;
const double kSpaceBase = 16;
const double kSpaceLg = 20;
const double kSpaceXl = 24;

/// Figma Radius.
const double kRadiusSm = 8;
const double kRadiusMd = 12;
const double kRadiusLg = 16;
const double kRadiusXl = 23;
const double kSurfaceRadius = 23;
const double kStatsRadius = 23;

/// Material 3 kart köşe yarıçapı (genel).
const double kCardRadiusLg = 22;
const double kCardRadiusMd = 18;

/// Figma ana ekran yatay padding (~18px frame inspect).
const double kHomePaddingH = 15.26646900177002;

/// Figma card shadow.
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x143B82F6),
    blurRadius: 20,
    spreadRadius: 0,
  ),
  BoxShadow(
    color: Color(0x4D000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  ),
];

/// Uygulama geneli yazı tipi — Figma tasarımıyla aynı (Red Hat Display).
TextTheme _redHatTextTheme(TextTheme base) =>
    GoogleFonts.redHatDisplayTextTheme(base);

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  final fontFamily = GoogleFonts.redHatDisplay().fontFamily;
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: kBgGradientBottom,
    colorScheme: ColorScheme.dark(
      surface: kBgDark,
      primary: kAccent,
      onPrimary: kBgDark,
      secondary: kBgCard,
      surfaceContainerHighest: kBgCard,
    ),
    cardTheme: CardThemeData(
      color: kBgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadiusLg),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: kBgDark,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadiusMd),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBgDark,
      foregroundColor: kAccent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: kAccent),
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    iconTheme: const IconThemeData(color: kAccent),
    textTheme: _redHatTextTheme(base.textTheme).apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ).copyWith(
      headlineSmall: const TextStyle(
        color: kTextPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      titleMedium: const TextStyle(
        color: kTextPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyMedium: const TextStyle(
        color: kTextPrimary,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: const TextStyle(
        color: kTextSecondary,
        fontSize: 13,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        color: kTextPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// AppBar: AeroTest (`kAccent`) + altında ekran başlığı (beyaz).
Widget buildAeroTestAppBarTitle(
  String subtitle, {
  double subtitleFontSize = 17,
  FontWeight subtitleWeight = FontWeight.bold,
  int subtitleMaxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'AeroTest',
        style: TextStyle(
          color: kAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
      Text(
        subtitle,
        style: TextStyle(
          color: Colors.white,
          fontSize: subtitleFontSize,
          fontWeight: subtitleWeight,
        ),
        maxLines: subtitleMaxLines,
        overflow: subtitleMaxLines == 1 ? TextOverflow.ellipsis : null,
      ),
    ],
  );
}
