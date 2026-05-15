import 'package:flutter/material.dart';

// ── Renk Paleti ──────────────────────────────────────────────────────────────
const Color kBgDark        = Color(0xFF0B132B); // Ana arka plan – koyu lacivert
const Color kBgCard        = Color(0xFF1C2541); // Kart / AppBar arka planı
const Color kAccent        = Color(0xFF48CAE4); // İkon ve vurgu – gökyüzü mavisi
const Color kTextPrimary   = Color(0xFFFFFFFF); // Ana metin
const Color kTextSecondary = Color(0xFF7B8FAB); // Açıklama metni

// ── Tema ─────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBgDark,
    colorScheme: const ColorScheme.dark(
      surface: kBgDark,
      primary: kAccent,
      onPrimary: kBgDark,
      secondary: kBgCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBgCard,
      foregroundColor: kAccent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: kAccent),
      titleTextStyle: TextStyle(
        color: kAccent,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
    iconTheme: const IconThemeData(color: kAccent),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: kTextPrimary),
      bodySmall: TextStyle(color: kTextSecondary),
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
