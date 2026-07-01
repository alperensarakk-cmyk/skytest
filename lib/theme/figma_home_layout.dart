import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'figma_home_layers.dart';
/// AeroTest home frame `1:5` — absolute layout from `.fig` parse (430×931).
abstract final class FigmaHomeLayout {
  static const frameWidth = 430.0;
  static const frameHeight = 931.0;
  static const statusBarH = 45.130859375;

  /// Horizontal inset for full-width cards (sinav inner `17:3034` x).
  static const paddingH = 15.26646900177002;

  /// Study grid wrap inner offset (`17:3254` inside `17:3253`).
  static const studyGridInsetH = 10.562499046325684;
  static const studyGridInsetV = 15.364402770996094;

  static const headerH = 61.45650100708008;
  static const headerY = 48.0;
  static const heroH = 113.31041717529297;
  static const heroY = 120.0;
  static const headerToHeroGap = heroY - (headerY + headerH);

  static const countdownH = 119.07196044921875;
  static const countdownY = 244.0;
  static const heroToCountdownGap = countdownY - (heroY + heroH);

  static const sinavH = 115.47100830078125;
  static const sinavY = 352.0;

  static const studyGridH = 319.76580810546875;
  static const studyGridY = 466.0;

  static const statsH = 58.0;
  static const statsY = 873.0;
  static const navH = 78.74113464355469;
  static const navY = 778.0;

  static const countdownInnerH = 107.54887390136719;
  static const sinavInnerH = 103.9478988647461;
  static const countdownToSinavGap = 11.974220275878906;
  static const sinavToStudyGap =
      studyGridY - sinavY - sinavInnerH; // ≈10.05 — Figma mutlak boşluk

  /// Study kartları — eşit ölçek (kenar hizası korunur).
  static const studyCardScaleFactor = 1.13;

  /// Büyütme sonrası dış boşluk sıkılaştırma (Sınav Modu + stats yakın kalsın).
  static const studyGapTighten = 4.0;

  static double get studyRow1Render => studyRow1H * studyCardScaleFactor;

  static double get studyRow2Render => studyRow2LeftH * studyCardScaleFactor;

  static double get studyGridGapRender => studyGridGap * studyCardScaleFactor;

  static double get studyGridRenderH =>
      studyRow1Render + studyGridGapRender + studyRow2Render;

  static double get sinavToStudyGapRender =>
      math.max(4.0, sinavToStudyGap - studyGapTighten);

  static double get studyToStatsGapRender =>
      math.max(4.0, studyToStatsGap - studyGapTighten);

  /// Stats şeridi ile alt nav arası (`873 - 856.74` nav bitişi).
  static const statsToNavGap = 16.259765625;

  /// İstatistik şeridinin üstündeki boşluk (study grid → stats).
  static const studyToStatsGap = 11.0;

  static const heroImageTransform = (
    m00: 1.2001067399978638,
    m01: 0.0,
    m02: -0.19937002658843994,
    m10: 0.0,
    m11: 0.6321991086006165,
    m12: 0.2725018560886383,
  );

  /// `17:2633` metin kutusu genişliği.
  static const heroTitleW = 252.0;

  /// Ekrana sığdır: genişlik + yükseklik (scroll yok).
  static double scaleFor(BoxConstraints constraints) {
    final wScale = constraints.maxWidth / frameWidth;
    final hScale = constraints.maxHeight / contentColumnH;
    return math.min(wScale, hScale);
  }

  static double get contentColumnH =>
      headerH +
      headerToHeroGap +
      heroH +
      heroToCountdownGap +
      countdownInnerH +
      countdownToSinavGap +
      sinavInnerH +
      sinavToStudyGapRender +
      studyGridRenderH +
      studyToStatsGapRender +
      statsH +
      statsToNavGap;

  static const studyRow1H = 137.04249572753906;
  static const studyRow2LeftH = 140.087890625;
  static const studyRow2RightH = 137.04249572753906;
  static const studyGridGap = 13.14096736907959;

  static const cardKonularW = 194.90489196777344;
  static const cardKaliplarW = 191.85951232910156;

  /// Satır genişliği — kartlar + ara boşluk (Sınav Modu ile aynı kenar hizası).
  static double get studyRowInnerW =>
      cardKonularW + studyGridGap + cardKaliplarW;

  /// Eski parse değeri; yatay inset artık kullanılmıyor.
  static const studyGridInnerW = 411.12750244140625;

  static const heroGreetingLeft = 35.000389099121094;
  static const heroGreetingTop = 7.999889373779297;

  static const logoBoxH = 42.28271484375;

  static double studyGridPadV() =>
      (studyGridH - studyRow1H - studyGridGap - studyRow2LeftH) / 2;

  static double homeScale(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w / frameWidth;
  }

  static EdgeInsets horizontalPadding(double scale) =>
      EdgeInsets.symmetric(horizontal: paddingH * scale);

  static double studyCardWidth(double rowWidth, double figmaCardW) =>
      figmaCardW / studyRowInnerW * rowWidth;

  static double studyGridGapWidth(double rowWidth) =>
      studyGridGap / studyRowInnerW * rowWidth;
}

/// Header `35:1874` DIV-5 — mutlak koordinatlar (430.2×61.46 frame içi).
abstract final class FigmaHeaderLayout {
  static const frameW = 430.19549560546875;
  static const frameH = 61.45650100708008;

  static const logoX = 19.205078125;
  static const logoY = 9.599609375;
  static const logoSize = 42.28271484375;
  static const logoRadius = 8.64232063293457;

  static const titleX = 66.869140625;
  static const titleW = 193.0078125;
  static const titleTextY = 6.755859375;
  static const subtitleY = 30.490234375;
  static const subtitleW = 193.0078125;

  static const premiumX = 273.67279052734375;
  static const premiumY = 19.20492458343506;
  static const premiumW = 88.5571060180664;
  static const premiumH = 28.8077335357666;

  static const helpFrameX = 371.6192626953125;
  static const helpFrameY = 8.641839504241943;
  static const helpFrameW = 39.370567321777344;
  static const helpFrameH = 53.774436950683594;
  static const helpIconBtnH = 25.92696189880371;
  static const helpIconSize = 23.428791046142578;
  static const helpTextY = 36.48931705951691;
  static const helpTextW = 40.33082962036133;
}

/// Hero `17:2626` DIV-28 + `24:3752` DIV-36 + Group 7.
abstract final class FigmaHeroLayout {
  static const frameW = 430.19549560546875;
  static const frameH = 113.31041717529297;

  /// DIV-36 gradient hero üstüne taşar.
  static const gradientExtendUp = 8.642578125;

  static const groupX = 35.000389099121094;
  static const groupW = 359.7759094238281;

  static const merhabaY = 7.816802024841309;
  static const merhabaH = 18.0;
  static const merhabaLineH = 17.633825302124023;

  static const titleY = 27.357799530029297;
  static const titleW = 252.0;
  static const titleH = 60.0;
  static const titleLineH = 29.767993927001953;

  static const merhabaToTitleGap =
      titleY - merhabaY - merhabaH; // ~1.54px

  /// `17:2626` IMAGE fill transform.
  static const imageM00 = 1.2001067399978638;
  static const imageM01 = 0.0;
  static const imageM02 = -0.19937002658843994;
  static const imageM10 = 0.0;
  static const imageM11 = 0.6321991086006165;
  static const imageM12 = 0.2725018560886383;

  /// PNG'de uçak gövdesi dikey UV ~0.58 (alt-orta; üst gökyüzü kırpılır).
  static const imageVCenter = 0.58;

  /// Kanat sağda kalsın — Figma uCenter (~0.583) + sağa kaydırma.
  static const imageAlignXBoost = 0.28;
}

/// Countdown kartı `SECTION-41` / `17:2975` DIV-48 — mutlak konumlar.
abstract final class FigmaCountdownLayout {
  static const outerH = 119.07196044921875;
  static const innerW = 399.46722412109375;
  static const innerH = 107.54887390136719;

  /// `17:2977` margin-wrap — takvim bloğu.
  static const calendarX = 16.324382781982422;
  static const calendarY = 24.274436950683594;
  static const calendarWrapW = 59.535980224609375;
  static const calendarWrapH = 59.0;
  static const calendarImageW = 57.0;
  static const calendarImageH = 59.0;
  static const calendarM00 = 0.4173177182674408;
  static const calendarM02 = 0.0631510391831398;
  static const calendarM11 = 0.6455078125;
  static const calendarM12 = 0.169921875;

  /// `17:2985` DIV-52 — metin + sayaç.
  static const textX = 75.86014556884766;
  static const textY = 11.613649368286133;
  static const textColumnW = 171.88613891601562;
  static const textColumnH = 84.32150268554688;

  /// `17:3017` + `17:3018` + `17:3024` — sağ illüstrasyon.
  static const illustrationWrapX = 247.7465057373047;
  static const illustrationWrapY = 0.9602622985839844;
  static const illustrationWrapW = 126.7540283203125;
  static const illustrationWrapH = 105.62834930419922;
  static const illustrationFrameX = 26.0087890625;
  static const illustrationFrameY = 9.22021484375;
  static const illustrationFrameW = 109.0830078125;
  static const illustrationFrameH = 87.43954467773438;
  static const illustrationImageW = 99.55984497070312;
  static const illustrationImageH = 87.2090072631836;
  static const illustrationM00 = 0.5823677778244019;
  static const illustrationM02 = 0.20772157609462738;
  static const illustrationM11 = 0.7651836276054382;
  static const illustrationM12 = 0.06111086905002594;

  /// `17:2988` → `17:2992` dikey boşluk (margin-wrap).
  static const labelToValueGap = 20.365234375;

  /// `17:2992` DIV-56 sayaç satırı.
  static const timeRowH = 40.7540283203125;
  static const timeBlockW = 39.842498779296875;
  static const timeSepMarginW = 11.7734375;
  static const timeSepW = 0.912109375;
  static const timeSepH = 19.921875;

  /// Kullanıcı ayarı — metni sol ikondan uzaklaştırır.
  static const textExtraX = 22.0;

  /// Metin sütunu — sağdaki illüstrasyona kadar genişlet.
  static const textWidthBoost = 1.14;

  /// Metin / sayaç ölçeği.
  static const textBoost = 1.06;

  static double textColumnRenderW(double scale) {
    final maxW = (illustrationLeft - textRenderX - 4) * scale;
    return (textColumnW * textWidthBoost * scale).clamp(0.0, maxW);
  }

  static double timeRowRenderH(double scale) =>
      timeRowH * scale * textBoost;

  static double timeBlockRenderW(double scale) =>
      timeBlockW * scale * textBoost;

  /// Kullanıcı ayarı — uçaklı takvimi sağa kaydırır.
  static const illustrationExtraX = 7.0;

  /// Kullanıcı ayarı — illüstrasyon ölçeği (Figma 99.56×87.21 taban).
  static const illustrationSizeFactor = 1.20;

  /// Büyütünce hafif yukarı (dikey ortalama).
  static const illustrationLiftY = 5.0;

  static double get illustrationLeft =>
      illustrationWrapX + illustrationFrameX + illustrationExtraX;

  static double get illustrationTop =>
      illustrationWrapY + illustrationFrameY - illustrationLiftY;

  static double get illustrationRenderW =>
      illustrationImageW * illustrationSizeFactor;

  static double get illustrationRenderH =>
      illustrationImageH * illustrationSizeFactor;

  static double get textRenderX => textX + textExtraX;
}

/// Hero overlay gradient — `24:3752` DIV-36.
final LinearGradient kFigmaGradHeroOverlay = figmaLinearGradient(
  colors: const [Color(0x00000000), Color(0x80000000)],
  stops: const [0.5721153616905212, 0.8894230723381042],
  m00: -1,
  m01: 9.09954260345494e-17,
  m02: 1,
  m10: 0,
  m11: 9.09954260345494e-17,
  m12: 0.5,
);

/// Logo box gradient — `35:1875` DIV-8.
final LinearGradient kFigmaGradLogoBox = figmaLinearGradient(
  colors: const [Color(0xFF081E3E), Color(0xFF0B2A5B)],
  stops: const [0.0, 1.0],
  m00: 6.123234262925839e-17,
  m01: 1,
  m02: 0,
  m10: -1,
  m11: 6.123234262925839e-17,
  m12: 1,
);

/// Figma IMAGE fill — STRETCH (`17:3031`) veya hero cover (`17:2626`).
class FigmaImageFill extends StatelessWidget {
  const FigmaImageFill({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
    this.stretch = false,
  });

  const FigmaImageFill.hero({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
  }) : stretch = false;

  const FigmaImageFill.stretch({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.m00,
    required this.m01,
    required this.m02,
    required this.m10,
    required this.m11,
    required this.m12,
  }) : stretch = true;

  final String asset;
  final double width;
  final double height;
  final double m00;
  final double m01;
  final double m02;
  final double m10;
  final double m11;
  final double m12;
  final bool stretch;

  /// Figma clip: frame x=0 → görünür u = −m02/m00.
  static Alignment _coverAlignment({
    required double m00,
    required double m02,
    required double vCenter,
    required double alignXBoost,
  }) {
    final uMin = -m02 / m00;
    final uMax = (1 - m02) / m00;
    final uCenter = (uMin + uMax) / 2;
    final alignX = ((uCenter - 0.5) * 2 + alignXBoost).clamp(-1.0, 1.0);
    final alignY = ((vCenter - 0.5) * 2).clamp(-1.0, 1.0);
    return Alignment(alignX, alignY);
  }

  @override
  Widget build(BuildContext context) {
    if (stretch) {
      final imgW = m00 * width;
      final imgH = m11 * height;
      return ClipRect(
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: m02 * width,
                top: m12 * height,
                width: imgW,
                height: imgH,
                child: Image.asset(
                  asset,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final alignment = _coverAlignment(
      m00: m00,
      m02: m02,
      vCenter: FigmaHeroLayout.imageVCenter,
      alignXBoost: FigmaHeroLayout.imageAlignXBoost,
    );

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: alignment,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
