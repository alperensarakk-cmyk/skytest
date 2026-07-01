import 'package:flutter/material.dart';
import '../data/app_mode_guides.dart';
import '../navigation/route_observer.dart';
import '../services/calisma_istatistik_service.dart';
import '../services/exam_countdown_service.dart';
import '../services/istatistik_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layout.dart';
import '../theme/figma_home_layers.dart';
import '../theme/figma_home_typography.dart';

const Color _gold = Color(0xFFF7C948);
const Color _premiumBorder = Color(0xFF3D3920);

String _formatStat(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.examBannerKey});

  final Key? examBannerKey;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _entranceCtrl;
  ModalRoute<void>? _route;

  int _tamamlananSinav = 0;
  int _basariYuzde = 0;
  int _gunSerisi = 0;
  int _calismaSaati = 0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceCtrl.forward();
    });
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadStats();
  }

  Future<void> _loadStats() async {
    final sonuclar = await IstatistikService.getSinavSonuclari();
    if (!mounted) return;

    final ozet = await CalismaIstatistikService.dashboardOzet(sonuclar);
    if (!mounted) return;

    setState(() {
      _tamamlananSinav = ozet.tamamlananSinav;
      _calismaSaati = ozet.calismaSaati;
      _gunSerisi = ozet.gunSerisi;
      _basariYuzde = ozet.basariYuzde;
    });
  }

  @override
  void dispose() {
    if (_route != null) routeObserver.unsubscribe(this);
    _entranceCtrl.dispose();
    super.dispose();
  }

  Widget _entrance(int index, Widget child) {
    final start = (index * 0.07).clamp(0.0, 0.65);
    final end = (start + 0.30).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgPrimary,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgGradientTop, kBgGradientBottom],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final s = FigmaHomeLayout.scaleFor(constraints);
              final topH = (FigmaHomeLayout.headerH +
                      FigmaHomeLayout.headerToHeroGap +
                      FigmaHomeLayout.heroH) *
                  s;
              final contentW = constraints.maxWidth -
                  2 * FigmaHomeLayout.paddingH * s;
              final gridInnerW = contentW;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: topH,
                    width: double.infinity,
                    child: _entrance(
                      0,
                      _TopScene(
                        scale: s,
                        width: constraints.maxWidth,
                        onInfo: () => _showInfoSheet(context),
                      ),
                    ),
                  ),
                  Padding(
                    padding: FigmaHomeLayout.horizontalPadding(s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: FigmaHomeLayout.heroToCountdownGap * s),
                    SizedBox(
                      height: FigmaHomeLayout.countdownInnerH * s,
                      child: _entrance(
                        1,
                        _ExamCountdownBanner(
                          key: widget.examBannerKey,
                          scale: s,
                        ),
                      ),
                    ),
                    SizedBox(height: FigmaHomeLayout.countdownToSinavGap * s),
                    SizedBox(
                      height: FigmaHomeLayout.sinavInnerH * s,
                      child: _entrance(
                        2,
                        _PrimaryActionCard(
                          scale: s,
                          icon: Icons.timer_rounded,
                          title: 'Sınav Modu',
                          layers: kFigmaLayersSinav,
                          accent: kAccent,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/sinav_hazirlik',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: FigmaHomeLayout.sinavToStudyGapRender * s),
                    SizedBox(
                      height: FigmaHomeLayout.studyGridRenderH * s,
                      child: _entrance(
                        3,
                        Column(
                          children: [
                            SizedBox(
                              height: FigmaHomeLayout.studyRow1Render * s,
                              child: Row(
                                  children: [
                                    SizedBox(
                                      width: FigmaHomeLayout.studyCardWidth(
                                        gridInnerW,
                                        FigmaHomeLayout.cardKonularW,
                                      ),
                                      child: _SecondaryActionCard(
                                        scale: s,
                                        title: 'Konulara Yönelik',
                                        subtitle:
                                            'Sistem ve gramer odaklı çalışma.',
                                        titleStyleBuilder:
                                            FigmaHomeTypography.studyTitle,
                                        subtitleStyleBuilder:
                                            FigmaHomeTypography.studySubKonular,
                                        layers: kFigmaLayersKonular,
                                        accent: kAccentTeal,
                                        image: 'assets/home/card_konular.png',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/konular',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: FigmaHomeLayout.studyGridGapWidth(
                                        gridInnerW,
                                      ),
                                    ),
                                    SizedBox(
                                      width: FigmaHomeLayout.studyCardWidth(
                                        gridInnerW,
                                        FigmaHomeLayout.cardKaliplarW,
                                      ),
                                      child: _SecondaryActionCard(
                                        scale: s,
                                        title: 'Altın Kalıplar',
                                        subtitle:
                                            'Kritik havacılık kalıplarını ezberle.',
                                        titleStyleBuilder:
                                            FigmaHomeTypography.studyTitle,
                                        subtitleStyleBuilder:
                                            FigmaHomeTypography.studySubAccent,
                                        layers: kFigmaLayersKaliplar,
                                        accent: const Color(0xFF2563EB),
                                        image: 'assets/home/card_kaliplar.png',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/kaliplar',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              height: FigmaHomeLayout.studyGridGapRender * s,
                            ),
                            SizedBox(
                              height: FigmaHomeLayout.studyRow2Render * s,
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: FigmaHomeLayout.studyCardWidth(
                                        gridInnerW,
                                        FigmaHomeLayout.cardKonularW,
                                      ),
                                      child: _SecondaryActionCard(
                                        scale: s,
                                        title: 'Kelime Çalışması',
                                        subtitle:
                                            'Teknik havacılık kelimelerini güçlendir.',
                                        titleStyleBuilder:
                                            FigmaHomeTypography.studyTitle,
                                        subtitleStyleBuilder:
                                            FigmaHomeTypography.studySubAccent,
                                        layers: kFigmaLayersKelime,
                                        accent: const Color(0xFF1D4ED8),
                                        image: 'assets/home/card_kelime.png',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/kelime',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: FigmaHomeLayout.studyGridGapWidth(
                                        gridInnerW,
                                      ),
                                    ),
                                    SizedBox(
                                      width: FigmaHomeLayout.studyCardWidth(
                                        gridInnerW,
                                        FigmaHomeLayout.cardKaliplarW,
                                      ),
                                      child: _SecondaryActionCard(
                                        scale: s,
                                        title: 'Haftalık Test',
                                        subtitle:
                                            'Diğer kullanıcılarla yarış.',
                                        titleStyleBuilder:
                                            FigmaHomeTypography.studyTitle,
                                        subtitleStyleBuilder:
                                            FigmaHomeTypography.studySubAccent,
                                        layers: kFigmaLayersHaftalik,
                                        accent: const Color(0xFF0284C7),
                                        image: 'assets/home/card_haftalik.png',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/challenge',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: FigmaHomeLayout.studyToStatsGapRender * s),
                    SizedBox(
                      height: FigmaHomeLayout.statsH * s,
                      child: _entrance(5, _statsStrip(scale: s)),
                    ),
                    SizedBox(height: FigmaHomeLayout.statsToNavGap * s),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Figma DIV-195: yatay ikon + değer/etiket şeridi.
  Widget _statsStrip({required double scale}) {
    return FigmaCardSurface(
      layers: kFigmaLayersStats,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: FigmaHomeLayout.statsH * scale * 0.08,
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.quiz_rounded,
                color: kAccent,
                value: _formatStat(_tamamlananSinav),
                label: 'Sınav Sayısı',
                scale: scale,
              ),
            ),
            _statDivider(FigmaHomeLayout.statsH * scale * 0.5),
            Expanded(
              child: _StatItem(
                icon: Icons.schedule_rounded,
                color: kAccentGreen,
                value: '$_calismaSaati',
                label: 'Saat Çalışma',
                scale: scale,
              ),
            ),
            _statDivider(FigmaHomeLayout.statsH * scale * 0.5),
            Expanded(
              child: _StatItem(
                icon: Icons.local_fire_department_rounded,
                color: kAccentOrange,
                value: '$_gunSerisi',
                label: 'Gün Serisi',
                scale: scale,
              ),
            ),
            _statDivider(FigmaHomeLayout.statsH * scale * 0.5),
            Expanded(
              child: _StatItem(
                icon: Icons.percent_rounded,
                color: kAccentPurple,
                value: '%$_basariYuzde',
                label: 'Başarı Oranı',
                scale: scale,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider(double height) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InfoSheet(),
    );
  }
}

// ─── Figma üst sahne: hero PNG + header + karşılama (tek blok) ───────────────

class _TopScene extends StatelessWidget {
  const _TopScene({
    required this.scale,
    required this.width,
    required this.onInfo,
  });

  final double scale;
  final double width;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final headerH = FigmaHomeLayout.headerH * s;
    final gapH = FigmaHomeLayout.headerToHeroGap * s;
    final heroH = FigmaHomeLayout.heroH * s;
    final heroTop = headerH + gapH;
    final gradUp = FigmaHeroLayout.gradientExtendUp * s;

    return SizedBox(
      width: width,
      height: heroTop + heroH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: heroTop,
            height: heroH,
            child: FigmaImageFill.hero(
              asset: 'assets/home/hero_bg.png',
              width: width,
              height: heroH,
              m00: FigmaHeroLayout.imageM00,
              m01: FigmaHeroLayout.imageM01,
              m02: FigmaHeroLayout.imageM02,
              m10: FigmaHeroLayout.imageM10,
              m11: FigmaHeroLayout.imageM11,
              m12: FigmaHeroLayout.imageM12,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: heroTop - gradUp,
            height: heroH + gradUp,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: kFigmaGradHeroOverlay,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: headerH,
            child: _TopHeaderBar(scale: s, width: width, onInfo: onInfo),
          ),
          Positioned(
            left: FigmaHeroLayout.groupX * s,
            top: heroTop + FigmaHeroLayout.merhabaY * s,
            width: FigmaHeroLayout.groupW * s,
            child: Text(
              'Merhaba 👋',
              style: FigmaHomeTypography.merhaba(s),
              maxLines: 1,
            ),
          ),
          Positioned(
            left: FigmaHeroLayout.groupX * s,
            top: heroTop + FigmaHeroLayout.titleY * s,
            width: FigmaHeroLayout.titleW * s,
            height: FigmaHeroLayout.titleH * s,
            child: Text(
              'Bugün ne çalışmak istersin?',
              style: FigmaHomeTypography.heroTitle(s),
              maxLines: 2,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.scale,
    required this.width,
    required this.onInfo,
  });

  final double scale;
  final double width;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final helpRight =
        (FigmaHeaderLayout.frameW -
                FigmaHeaderLayout.helpFrameX -
                FigmaHeaderLayout.helpFrameW) *
            s;
    final premiumRight =
        (FigmaHeaderLayout.frameW -
                FigmaHeaderLayout.premiumX -
                FigmaHeaderLayout.premiumW) *
            s;

    return SizedBox(
      height: FigmaHomeLayout.headerH * s,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: FigmaHeaderLayout.logoX * s,
            top: FigmaHeaderLayout.logoY * s,
            width: FigmaHeaderLayout.logoSize * s,
            height: FigmaHeaderLayout.logoSize * s,
            child: Image.asset(
              'assets/branding/logo_mark.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: FigmaHeaderLayout.titleX * s,
            top: FigmaHeaderLayout.titleTextY * s,
            width: FigmaHeaderLayout.titleW * s,
            child: Text(
              'AeroTest',
              maxLines: 1,
              style: FigmaHomeTypography.appTitle(s),
            ),
          ),
          Positioned(
            left: FigmaHeaderLayout.titleX * s,
            top: FigmaHeaderLayout.subtitleY * s,
            width: (FigmaHeaderLayout.premiumX -
                    FigmaHeaderLayout.titleX -
                    8) *
                s,
            height: (FigmaHeaderLayout.frameH -
                    FigmaHeaderLayout.subtitleY -
                    2) *
                s,
            child: Text(
              'Havacılık İngilizcesi Sınav Hazırlık Uygulaması.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FigmaHomeTypography.appSubtitle(s),
            ),
          ),
          Positioned(
            right: premiumRight,
            top: FigmaHeaderLayout.premiumY * s,
            width: FigmaHeaderLayout.premiumW * s,
            height: FigmaHeaderLayout.premiumH * s,
            child: _DashboardPremiumCta(scale: s, figmaHeader: true),
          ),
          Positioned(
            right: helpRight,
            top: FigmaHeaderLayout.helpFrameY * s,
            width: FigmaHeaderLayout.helpFrameW * s,
            height: FigmaHeaderLayout.helpFrameH * s,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onInfo,
                borderRadius: BorderRadius.circular(8 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: FigmaHeaderLayout.helpIconBtnH * s,
                      child: Center(
                        child: Icon(
                          Icons.help_outline_rounded,
                          color: const Color(0xFFB7C9E8),
                          size: FigmaHeaderLayout.helpIconSize * s,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: FigmaHeaderLayout.helpTextW * s,
                          child: Text(
                            'Nasıl çalışır?',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: FigmaHomeTypography.helpLink(s),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sınav geri sayım kartı (Figma: illüstrasyon sağda) ───────────────────────

class _ExamCountdownBanner extends StatefulWidget {
  const _ExamCountdownBanner({super.key, required this.scale});

  final double scale;

  @override
  State<_ExamCountdownBanner> createState() => _ExamCountdownBannerState();
}

class _ExamCountdownBannerState extends State<_ExamCountdownBanner> {
  DateTime? _date;
  int? _days;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ExamCountdownService.getTargetDate();
    final days = await ExamCountdownService.daysRemaining();
    if (!mounted) return;
    setState(() {
      _date = d;
      _days = days;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = today.add(const Duration(days: 365 * 5));
    final DateTime initial;
    if (_date == null || _date!.isBefore(today)) {
      initial = today;
    } else {
      initial = _date!;
    }
    final initialClamped = initial.isAfter(last) ? last : initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialClamped,
      firstDate: today,
      lastDate: last,
      helpText: 'Hedef sınav tarihi',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked == null || !mounted) return;
    await ExamCountdownService.setTargetDate(picked);
    await _load();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
        title: const Text('Tarihi kaldır',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Sınav geri sayımı ana ekrandan kaldırılsın mı?',
          style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: kAccentOrange)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ExamCountdownService.clearTargetDate();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = _date != null && _days != null;
    final passed = hasDate && _days! < 0;
    final today = hasDate && _days == 0;

    var gun = 0, saat = 0, dakika = 0;
    if (hasDate && !passed && !today) {
      final now = DateTime.now();
      final target0 = DateTime(_date!.year, _date!.month, _date!.day);
      var rem = target0.difference(now);
      if (rem.isNegative) rem = Duration.zero;
      gun = rem.inDays;
      saat = rem.inHours % 24;
      dakika = rem.inMinutes % 60;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kFigmaLayersCountdown.cornerRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickDate,
          onLongPress: hasDate ? _confirmClear : null,
          child: FigmaLayeredFill(
            layers: kFigmaLayersCountdown,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Builder(
                  builder: (context) {
                    final s = widget.scale;
                    return SizedBox(
                      height: FigmaCountdownLayout.innerH * s,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned(
                            left: FigmaCountdownLayout.calendarX * s,
                            top: FigmaCountdownLayout.calendarY * s,
                            width: FigmaCountdownLayout.calendarImageW * s,
                            height: FigmaCountdownLayout.calendarImageH * s,
                            child: Image.asset(
                              'assets/home/countdown_calendar_icon.png',
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                          Positioned(
                            left: FigmaCountdownLayout.textRenderX * s,
                            top: FigmaCountdownLayout.textY * s,
                            bottom: 3 * s,
                            width: FigmaCountdownLayout.textColumnRenderW(s),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sınava kalan süre',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: FigmaHomeTypography.countdownLabel(
                                    s * FigmaCountdownLayout.textBoost,
                                  ),
                                ),
                                SizedBox(height: 3 * s),
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: _countdownBody(
                                      s: s,
                                      hasDate: hasDate,
                                      passed: passed,
                                      today: today,
                                      days: _days,
                                      gun: gun,
                                      saat: saat,
                                      dakika: dakika,
                                    ),
                                  ),
                                ),
                                if (hasDate) ...[
                                  SizedBox(height: 2 * s),
                                  Text(
                                    ExamCountdownService.formatDateTr(_date!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: kTextSecondary.withValues(
                                          alpha: 0.92),
                                      fontSize: 11.5 * s,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(height: 2 * s),
                                  Text(
                                    'Kartın herhangi bir yerine dokun',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: kTextSecondary.withValues(
                                          alpha: 0.82),
                                      fontSize: 10.5 * s,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Positioned(
                            left: FigmaCountdownLayout.illustrationLeft * s,
                            top: FigmaCountdownLayout.illustrationTop * s,
                            width: FigmaCountdownLayout.illustrationRenderW * s,
                            height:
                                FigmaCountdownLayout.illustrationRenderH * s,
                            child: Image.asset(
                              'assets/home/countdown_illustration.png',
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (hasDate)
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: _confirmClear,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: kTextSecondary.withValues(alpha: 0.75),
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _countdownBody({
    required double s,
    required bool hasDate,
    required bool passed,
    required bool today,
    required int? days,
    required int gun,
    required int saat,
    required int dakika,
  }) {
    final ts = s * FigmaCountdownLayout.textBoost;

    if (!hasDate) {
      return Text(
        'Tarih seçerek geri sayım başlat',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: kTextPrimary,
          fontSize: 15 * s,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
      );
    }
    if (passed) {
      return Text(
        'Sınav tarihi ${days!.abs()} gün önce geçti',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: kAccentOrange,
          fontSize: 15 * s,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
      );
    }
    if (today) {
      return Text(
        'Sınavınız bugün — başarılar! 🎉',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: kAccentYellow,
          fontSize: 15 * s,
          fontWeight: FontWeight.w700,
          height: 1.12,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _timeBlock(ts, gun.toString().padLeft(2, '0'), 'Gün'),
          _timeSep(s),
          _timeBlock(ts, saat.toString().padLeft(2, '0'), 'Saat'),
          _timeSep(s),
          _timeBlock(ts, dakika.toString().padLeft(2, '0'), 'Dakika'),
        ],
      ),
    );
  }

  Widget _timeBlock(double scale, String value, String label) {
    return SizedBox(
      width: FigmaCountdownLayout.timeBlockW * scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: FigmaHomeTypography.countdownValue(scale),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: FigmaHomeTypography.countdownUnit(scale),
          ),
        ],
      ),
    );
  }

  Widget _timeSep(double scale) {
    return SizedBox(
      width: FigmaCountdownLayout.timeSepMarginW * scale,
      height: FigmaCountdownLayout.timeSepH * scale,
      child: Center(
        child: Container(
          width: FigmaCountdownLayout.timeSepW * scale,
          height: FigmaCountdownLayout.timeSepH * scale,
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

// ─── Bilgi Sayfası ────────────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B3E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A6B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.rocket_launch_rounded, color: kAccent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Bu Uygulamada Neler Var?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'AeroTest, SHGM/EASA sınavlarına hazırlık için tasarlanmış dört farklı çalışma modunu bir arada sunar.',
                style: TextStyle(
                    color: kTextSecondary, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  for (var i = 0; i < kAppModeGuides.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _ModeCard(guide: kAppModeGuides[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.guide});

  final AppModeGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: guide.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: guide.iconColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(guide.icon, color: guide.iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                guide.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: guide.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  guide.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            guide.body,
            style: const TextStyle(
              color: Color(0xFFCDD8EC),
              fontSize: 13,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPremiumCta extends StatefulWidget {
  const _DashboardPremiumCta({
    required this.scale,
    this.figmaHeader = false,
  });

  final double scale;
  final bool figmaHeader;

  @override
  State<_DashboardPremiumCta> createState() => _DashboardPremiumCtaState();
}

class _DashboardPremiumCtaState extends State<_DashboardPremiumCta>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PremiumService.isPremiumNotifier.addListener(_onChanged);
    PremiumService.premiumExpirationNotifier.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PremiumService.isPremiumNotifier.removeListener(_onChanged);
    PremiumService.premiumExpirationNotifier.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = PremiumService.isPremiumNotifier.value;
    final days = PremiumService.premiumCalendarDaysRemaining();

    final String label;
    if (!isPremium) {
      label = 'Premium';
    } else if (days != null) {
      label = 'Premium · $days g';
    } else {
      label = 'Premium';
    }

    final s = widget.scale;

    if (widget.figmaHeader) {
      return InkWell(
        onTap: () => Navigator.pushNamed(context, '/premium'),
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _gold.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: _gold,
                  size: 13.22 * s,
                ),
                SizedBox(width: 4 * s),
                Text(
                  'Premium',
                  maxLines: 1,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10.881270408630371 * s,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/premium'),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12 * s,
          vertical: 7 * s,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _premiumBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: _gold,
              size: 17 * s,
            ),
            SizedBox(width: 5 * s),
            Text(
              label.length > 14 ? 'Premium' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _gold,
                fontSize: 10.881270408630371 * s,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.scale,
    required this.icon,
    required this.title,
    required this.layers,
    required this.accent,
    required this.onTap,
  });

  final double scale;

  final IconData icon;
  final String title;
  final FigmaCardLayers layers;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final s = scale;
        final iconD = 45.97 * s;
        final arrowD = 38.0 * s;

        return ClipRRect(
          borderRadius: BorderRadius.circular(layers.cornerRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: accent.withValues(alpha: 0.14),
              child: FigmaLayeredFill(
                layers: layers,
                child: SizedBox(
                  height: h,
                  width: constraints.maxWidth,
                  child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * s,
                    vertical: 12 * s,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: iconD,
                        height: iconD,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF094199),
                          size: iconD * 0.52,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              style: FigmaHomeTypography.sinavTitle(s),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Container(
                        width: arrowD,
                        height: arrowD,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: arrowD * 0.48,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  const _SecondaryActionCard({
    required this.scale,
    required this.title,
    required this.subtitle,
    required this.titleStyleBuilder,
    required this.subtitleStyleBuilder,
    required this.layers,
    required this.accent,
    required this.onTap,
    required this.image,
  });

  final double scale;
  final String title;
  final String subtitle;
  final TextStyle Function(double scale) titleStyleBuilder;
  final TextStyle Function(double scale) subtitleStyleBuilder;
  final FigmaCardLayers layers;
  final Color accent;
  final VoidCallback onTap;
  final String image;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final sx = w / FigmaStudyCardLayout.referenceCardW;
        final sy = h / FigmaStudyCardLayout.referenceCardH;
        final textScale = scale *
            (sx > sy ? sx : sy) *
            FigmaStudyCardLayout.textBoost;
        final titleStyle = titleStyleBuilder(textScale);
        final subtitleStyle = subtitleStyleBuilder(textScale);
        final pad = FigmaStudyCardLayout.padding * sx;
        final cardScale = sx > sy ? sx : sy;
        final artW = FigmaStudyCardLayout.artWidth *
            cardScale *
            FigmaStudyCardLayout.artBoost;
        final artHt = FigmaStudyCardLayout.artHeight *
            cardScale *
            FigmaStudyCardLayout.artBoost;
        final arrowSz = FigmaStudyCardLayout.arrowSize * sx;

        return ClipRRect(
          borderRadius: BorderRadius.circular(layers.cornerRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: accent.withValues(alpha: 0.14),
              child: FigmaCardSurface(
                layers: layers,
                child: SizedBox(
                  height: h,
                  width: w,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      pad,
                      pad * 0.35,
                      pad * 0.85,
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(right: artW * 0.22),
                              child: Text(
                                title,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            SizedBox(height: 4 * sy),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: artW * 0.12),
                                child: Text(
                                  subtitle,
                                  maxLines: 4,
                                  softWrap: true,
                                  overflow: TextOverflow.clip,
                                  style: subtitleStyle,
                                ),
                              ),
                            ),
                            SizedBox(height: 4 * sy),
                            SizedBox(
                              width: arrowSz,
                              height: arrowSz,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: accent,
                                  size: arrowSz * 0.52,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: artW,
                          height: artHt,
                          child: Image.asset(
                            image,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomRight,
                            gaplessPlayback: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Figma stats: ikon solda, değer + etiket sağda (yatay).
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.scale,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final iconD = 28.0 * scale;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconD,
            height: iconD,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(7 * scale),
            ),
            child: Icon(icon, color: color, size: iconD * 0.52),
          ),
          SizedBox(width: 6 * scale),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FigmaHomeTypography.statValue(scale),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FigmaHomeTypography.statLabel(scale),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
