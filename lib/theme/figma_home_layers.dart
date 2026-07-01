import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_theme.dart';

// ── Figma `.fig` fill layer specs (AeroTest- anasayfa, node sessionID:localID) ──

/// Study-card drop shadows — shared on base nodes 17:3255 / 17:3277 / 17:3299 / 17:3321.
const List<BoxShadow> kFigmaStudyCardShadows = [
  BoxShadow(
    color: Color(0x143B82F6), // #3B82F6 @ 0.08 — effect[0] on 17:3277
    blurRadius: 21.901611328125,
    spreadRadius: 0,
    offset: Offset.zero,
  ),
  BoxShadow(
    color: Color(0x4D000000), // #000000 @ 0.30 — effect[1] on 17:3277
    blurRadius: 13.14096736907959,
    spreadRadius: 0,
    offset: Offset(0, 4.380321979522705),
  ),
];

/// Figma gradient stop — `#RRGGBB` + alpha (`.fig` parse).
Color figmaStopColor(String hex, double alpha) {
  final rgb = Color(int.parse(hex.replaceFirst('#', '0xFF')));
  return rgb.withValues(alpha: alpha);
}

/// Study kartı: yarı saydam stopları arka plan üzerine birleştirir + tek overlay.
LinearGradient figmaStudyCardGradient({
  required List<Color> stopColors,
  required List<double> stopPositions,
  required double m00,
  required double m01,
  required double m02,
  required double m10,
  required double m11,
  required double m12,
  Color? overlayColor,
  double overlayOpacity = 0,
}) {
  return figmaOpaqueLayeredGradient(
    background: kBgPrimary,
    stopColors: stopColors,
    stopPositions: stopPositions,
    m00: m00,
    m01: m01,
    m02: m02,
    m10: m10,
    m11: m11,
    m12: m12,
    overlayColor: overlayColor,
    overlayOpacity: overlayOpacity,
  );
}

/// Figma linear gradient axis: (0, 0.5) → (1, 0.5) in normalized space,
/// transformed by fillPaints[].transform (2×3 matrix from `.fig`).
LinearGradient figmaLinearGradient({
  required List<Color> colors,
  required List<double> stops,
  required double m00,
  required double m01,
  required double m02,
  required double m10,
  required double m11,
  required double m12,
}) {
  final begin = Alignment(
    (m02 + m01 * 0.5) * 2 - 1,
    (m12 + m11 * 0.5) * 2 - 1,
  );
  final end = Alignment(
    (m00 + m02 + m01 * 0.5) * 2 - 1,
    (m10 + m12 + m11 * 0.5) * 2 - 1,
  );
  return LinearGradient(
    begin: begin,
    end: end,
    colors: colors,
    stops: stops,
  );
}

/// Figma stop rengini sayfa arka planı üzerine birleştirir (opak çıktı).
Color figmaCompositeStop(Color background, Color stop) {
  final a = stop.a;
  if (a <= 0) return background;
  if (a >= 1) return stop;
  return Color.alphaBlend(stop, background);
}

/// Opaklı gradient katmanı — yarı saydam stop + overlay → tek opak gradient.
LinearGradient figmaOpaqueLayeredGradient({
  required Color background,
  required List<Color> stopColors,
  required List<double> stopPositions,
  required double m00,
  required double m01,
  required double m02,
  required double m10,
  required double m11,
  required double m12,
  Color? overlayColor,
  double overlayOpacity = 0,
}) {
  final base = stopColors
      .map((c) => figmaCompositeStop(background, c))
      .map(
        (c) => overlayColor != null && overlayOpacity > 0
            ? figmaCompositeStop(c, overlayColor.withValues(alpha: overlayOpacity))
            : c,
      )
      .toList();
  return figmaLinearGradient(
    colors: base,
    stops: stopPositions,
    m00: m00,
    m01: m01,
    m02: m02,
    m10: m10,
    m11: m11,
    m12: m12,
  );
}

/// One composited Figma card surface: base gradient + optional overlay + stroke + shadow.
class FigmaCardLayers {
  const FigmaCardLayers({
    required this.baseGradientNodeId,
    required this.baseGradient,
    this.overlayNodeId,
    this.overlayColor,
    this.overlayOpacity,
    this.overlayBlendMode = BlendMode.srcOver,
    required this.strokeNodeId,
    required this.strokeColor,
    required this.strokeOpacity,
    required this.strokeWeight,
    required this.cornerRadius,
    this.shadows = const [],
    this.backgroundBlurSigma,
    this.backgroundBlurNodeId,
  });

  final String baseGradientNodeId;
  final LinearGradient baseGradient;

  /// Overlay fill from companion frame (e.g. 29:160 on top of 17:3277).
  final String? overlayNodeId;
  final Color? overlayColor;
  final double? overlayOpacity;
  final BlendMode overlayBlendMode;

  /// strokePaints[0] — from overlay node when overlay exists, else base node.
  final String strokeNodeId;
  final Color strokeColor;
  final double strokeOpacity;
  final double strokeWeight;

  final double cornerRadius;
  final List<BoxShadow> shadows;

  /// BACKGROUND_BLUR effect (stats bar 15:2486 effect[0]).
  final double? backgroundBlurSigma;
  final String? backgroundBlurNodeId;
}

// ── Base gradients (fillPaints[0] GRADIENT_LINEAR) ───────────────────────────

/// 17:3255 + 29:135 — Konulara Yönelik
final LinearGradient kFigmaGradKonular = figmaStudyCardGradient(
  stopColors: [
    figmaStopColor('#3B82F6', 0.35),
    figmaStopColor('#0F172A', 0.7),
    figmaStopColor('#0A0F23', 0.85),
  ],
  stopPositions: const [0.0, 0.6000000238418579, 1.0],
  m00: 0.4173690676689148,
  m01: 0.5825921893119812,
  m02: 0.000019365365005796775,
  m10: 0.6710296869277954,
  m11: -0.4591991901397705,
  m12: 0.39408472180366516,
  overlayColor: const Color(0xFF249FF3),
  overlayOpacity: 0.20000000298023224,
);

/// 17:3277 + 29:160 — Altın Kalıplar (koyu mavi — indigo varyasyon)
final LinearGradient kFigmaGradKaliplar = figmaStudyCardGradient(
  stopColors: [
    figmaStopColor('#1E3A8A', 0.38),
    figmaStopColor('#0F172A', 0.699999988079071),
    figmaStopColor('#071B3A', 0.8500000238418579),
  ],
  stopPositions: const [0.0, 0.6000000238418579, 1.0],
  m00: 0.4173690676689148,
  m01: 0.5825921893119812,
  m02: 0.000019365365005796775,
  m10: 0.6710296869277954,
  m11: -0.4591991901397705,
  m12: 0.39408472180366516,
  overlayColor: const Color(0xFF2563EB),
  overlayOpacity: 0.20000000298023224,
);

/// 17:3299 + 29:183 — Kelime Çalışması (Haftalık ile renk takası — gece mavisi)
final LinearGradient kFigmaGradKelime = figmaStudyCardGradient(
  stopColors: [
    figmaStopColor('#172554', 0.34),
    figmaStopColor('#0F172A', 0.699999988079071),
    figmaStopColor('#071B3A', 0.8500000238418579),
  ],
  stopPositions: const [0.0, 0.6000000238418579, 1.0],
  m00: 0.33192551136016846,
  m01: 0.47858306765556335,
  m02: 0.18831788003444672,
  m10: 0.5544130802154541,
  m11: -0.3696325719356537,
  m12: 0.4019869267940521,
  overlayColor: const Color(0xFF1D4ED8),
  overlayOpacity: 0.20000000298023224,
);

/// 17:3321 + 29:205 — Haftalık Test (Kelime ile renk takası — teal/cyan)
final LinearGradient kFigmaGradHaftalik = figmaStudyCardGradient(
  stopColors: [
    figmaStopColor('#0C4A6E', 0.36),
    figmaStopColor('#0F172A', 0.699999988079071),
    figmaStopColor('#0A0F23', 0.8500000238418579),
  ],
  stopPositions: const [0.0, 0.6000000238418579, 1.0],
  m00: 0.39584288001060486,
  m01: 0.6041557788848877,
  m02: 6.766544515812711e-7,
  m10: 0.670975387096405,
  m11: -0.5021742582321167,
  m12: 0.41559943556785583,
  overlayColor: const Color(0xFF0284C7),
  overlayOpacity: 0.20000000298023224,
);

/// 17:3035 DIV-88 — Sınav Modu (mat, göz yormayan koyu mavi)
final LinearGradient kFigmaGradSinav = figmaStudyCardGradient(
  stopColors: [
    figmaStopColor('#1A3560', 0.36),
    figmaStopColor('#0F172A', 0.699999988079071),
    figmaStopColor('#071B3A', 0.8500000238418579),
  ],
  stopPositions: const [0.0, 0.6000000238418579, 1.0],
  m00: 0.9349323511123657,
  m01: 0.2824888825416565,
  m02: 0.1282545030117035,
  m10: 0.6840264797210693,
  m11: -0.15331831574440002,
  m12: 0.28289148211479187,
  overlayColor: const Color(0xFF2563EB),
  overlayOpacity: 0.10,
);

/// 17:2975 DIV-48 — Sınava kalan süre
final LinearGradient kFigmaGradCountdown = figmaLinearGradient(
  colors: const [Color(0xFF020C1B), Color(0xFF091C3B)],
  stops: const [0.0, 1.0],
  m00: 0,
  m01: -1,
  m02: 1,
  m10: 1,
  m11: 0,
  m12: 0,
);

/// 15:2486 DIV-164 — Stats bar
final LinearGradient kFigmaGradStats = figmaLinearGradient(
  colors: const [Color(0xFF000000), Color(0xFF071B3A)],
  stops: const [0.0, 1.0],
  m00: 1.457006817418005e-7,
  m01: -0.4036337733268738,
  m02: 0.5828951597213745,
  m10: 0.4036337733268738,
  m11: 3.2790126169857103e-9,
  m12: 0.2982819974422455,
);

// ── Composited layer stacks ───────────────────────────────────────────────────

final FigmaCardLayers kFigmaLayersKonular = FigmaCardLayers(
  baseGradientNodeId: '17:3255',
  baseGradient: kFigmaGradKonular,
  overlayNodeId: '29:135',
  overlayColor: Color(0xFF249FF3),
  overlayOpacity: 0.20000000298023224,
  overlayBlendMode: BlendMode.srcOver,
  strokeNodeId: '29:135',
  strokeColor: Color(0xFF249FF3),
  strokeOpacity: 0.20000000298023224,
  strokeWeight: 1.0950804948806763,
  cornerRadius: 17.52128791809082,
  shadows: kFigmaStudyCardShadows,
);

final FigmaCardLayers kFigmaLayersKaliplar = FigmaCardLayers(
  baseGradientNodeId: '17:3277',
  baseGradient: kFigmaGradKaliplar,
  overlayNodeId: '29:160',
  overlayColor: Color(0xFF2563EB),
  overlayOpacity: 0.20000000298023224,
  overlayBlendMode: BlendMode.srcOver,
  strokeNodeId: '29:160',
  strokeColor: Color(0xFF60A5FA),
  strokeOpacity: 0.20000000298023224,
  strokeWeight: 1.0950804948806763,
  cornerRadius: 17.52128791809082,
  shadows: kFigmaStudyCardShadows,
);

final FigmaCardLayers kFigmaLayersKelime = FigmaCardLayers(
  baseGradientNodeId: '17:3299',
  baseGradient: kFigmaGradKelime,
  overlayNodeId: '29:183',
  overlayColor: Color(0xFF1D4ED8),
  overlayOpacity: 0.20000000298023224,
  overlayBlendMode: BlendMode.srcOver,
  strokeNodeId: '29:183',
  strokeColor: Color(0xFF93C5FD),
  strokeOpacity: 0.20000000298023224,
  strokeWeight: 1.0950804948806763,
  cornerRadius: 17.52128791809082,
  shadows: kFigmaStudyCardShadows,
);

final FigmaCardLayers kFigmaLayersHaftalik = FigmaCardLayers(
  baseGradientNodeId: '17:3321',
  baseGradient: kFigmaGradHaftalik,
  overlayNodeId: '29:205',
  overlayColor: Color(0xFF0284C7),
  overlayOpacity: 0.20000000298023224,
  overlayBlendMode: BlendMode.srcOver,
  strokeNodeId: '29:205',
  strokeColor: Color(0xFF38BDF8),
  strokeOpacity: 0.20000000298023224,
  strokeWeight: 1.0950804948806763,
  cornerRadius: 17.52128791809082,
  shadows: kFigmaStudyCardShadows,
);

final FigmaCardLayers kFigmaLayersSinav = FigmaCardLayers(
  baseGradientNodeId: '17:3035',
  baseGradient: kFigmaGradSinav,
  strokeNodeId: '17:3035',
  strokeColor: Color(0xFF3B82F6),
  strokeOpacity: 0.14,
  strokeWeight: 0.9602578282356262,
  cornerRadius: 19.205156326293945,
);

final FigmaCardLayers kFigmaLayersCountdown = FigmaCardLayers(
  baseGradientNodeId: '17:2975',
  baseGradient: kFigmaGradCountdown,
  strokeNodeId: '17:2975',
  strokeColor: Color(0xFF3C78DC),
  strokeOpacity: 0.15000000596046448,
  strokeWeight: 0.9602578282356262,
  cornerRadius: 23.046188354492188,
);

final FigmaCardLayers kFigmaLayersStats = FigmaCardLayers(
  baseGradientNodeId: '15:2486',
  baseGradient: kFigmaGradStats,
  strokeNodeId: '15:2486',
  strokeColor: Color(0xFF6496FF),
  strokeOpacity: 0.11999999731779099,
  strokeWeight: 0.9602578282356262,
  cornerRadius: 19.205156326293945,
  backgroundBlurNodeId: '15:2486',
  backgroundBlurSigma: 11.523094177246094,
);

/// Paints base gradient + overlay + inside stroke.
class FigmaLayeredFill extends StatelessWidget {
  const FigmaLayeredFill({
    super.key,
    required this.layers,
    required this.child,
  });

  final FigmaCardLayers layers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = layers.cornerRadius;
    final border = Border.all(
      color: layers.strokeColor.withValues(alpha: layers.strokeOpacity),
      width: layers.strokeWeight,
    );

    Widget surface = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: layers.baseGradient,
            borderRadius: BorderRadius.circular(r),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            border: border,
          ),
        ),
        child,
      ],
    );

    if (layers.backgroundBlurSigma != null) {
      surface = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: layers.backgroundBlurSigma!,
            sigmaY: layers.backgroundBlurSigma!,
          ),
          child: surface,
        ),
      );
    }

    return surface;
  }
}

/// Outer wrapper: shadow + clip + [FigmaLayeredFill].
class FigmaCardSurface extends StatelessWidget {
  const FigmaCardSurface({
    super.key,
    required this.layers,
    required this.child,
  });

  final FigmaCardLayers layers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = layers.cornerRadius;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: layers.shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: FigmaLayeredFill(layers: layers, child: child),
      ),
    );
  }
}
