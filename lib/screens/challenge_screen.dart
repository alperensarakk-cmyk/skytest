import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/challenge.dart';
import '../models/sky_fight_question.dart';
import '../services/app_review_service.dart';
import '../services/aviation_callsign_service.dart';
import '../services/challenge_service.dart';
import '../services/sky_fight_service.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layers.dart';
import '../theme/figma_home_layout.dart';
import '../theme/figma_home_typography.dart';

const _cGold = Color(0xFFFFD60A);
const _cMuted = Color(0xFFA1B5D8);
const _cCard = Color(0xFF1C2541);
const _cCorrect = Color(0xFF4CAF50);
const _cWrong = Color(0xFFF44336);
const _kChallengeInProgressPrefix = 'challenge_in_progress_';

String _challengeInProgressKey(String challengeId) =>
    '$_kChallengeInProgressPrefix$challengeId';

Future<void> _markChallengeInProgress(String challengeId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_challengeInProgressKey(challengeId), true);
}

Future<void> _clearChallengeInProgress(String challengeId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_challengeInProgressKey(challengeId));
}

Future<bool> _hasChallengeInProgress(String challengeId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_challengeInProgressKey(challengeId)) == true;
}

/// Scroll içinde güvenli Figma yüzeyi.
class _FigmaPanel extends StatelessWidget {
  const _FigmaPanel({
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
        gradient: layers.baseGradient,
        border: Border.all(
          color: layers.strokeColor.withValues(alpha: layers.strokeOpacity),
          width: layers.strokeWeight,
        ),
        boxShadow: layers.shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: layers.overlayColor != null && (layers.overlayOpacity ?? 0) > 0
            ? ColoredBox(
                color: layers.overlayColor!.withValues(
                  alpha: layers.overlayOpacity!,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ana giriş ekranı — günlük + haftalık seçimi + leaderboard
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeHomeScreen extends StatefulWidget {
  const ChallengeHomeScreen({super.key});

  @override
  State<ChallengeHomeScreen> createState() => _ChallengeHomeScreenState();
}

class _ChallengeHomeScreenState extends State<ChallengeHomeScreen> {
  String? _userId;
  String _pilotName = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await SkyFightService.ensureSignedIn();
    if (mounted) {
      setState(() {
        _userId = uid;
        _pilotName = AviationCallsignService.fromUserId(uid);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = figmaHomeScale(context);

    return Scaffold(
      backgroundColor: kBgPrimary,
      appBar: AppBar(
        backgroundColor: kBgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kAccent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Haftalık Test', subtitleFontSize: 18),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgGradientTop, kBgGradientBottom],
          ),
        ),
        child: _userId == null
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => _ChallengeHero(
                      scale: s,
                      width: constraints.maxWidth,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      kHomePaddingH * s,
                      12 * s,
                      kHomePaddingH * s,
                      0,
                    ),
                    child: _PilotNameBar(
                      scale: s,
                      pilotName: _pilotName,
                    ),
                  ),
                  Expanded(
                    child: _ChallengeTab(
                      challenge: ChallengeService.thisWeekly(),
                      userId: _userId!,
                      pilotName: _pilotName,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _ChallengeHero extends StatelessWidget {
  const _ChallengeHero({
    required this.scale,
    required this.width,
  });

  final double scale;
  final double width;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final heroH = FigmaHomeLayout.heroH * s;
    final gradUp = FigmaHeroLayout.gradientExtendUp * s;

    return SizedBox(
      width: width,
      height: heroH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
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
            top: -gradUp,
            height: heroH + gradUp,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: kFigmaGradHeroOverlay,
              ),
            ),
          ),
          Positioned(
            left: 16 * s,
            top: 12 * s,
            right: width * 0.38,
            child: Text(
              'Bu hafta sıralamada yerini al.',
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

class _PilotNameBar extends StatelessWidget {
  const _PilotNameBar({
    required this.scale,
    required this.pilotName,
  });

  final double scale;
  final String pilotName;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final name = pilotName.isEmpty ? 'Belirtilmedi' : pilotName;
    final initial = pilotName.isEmpty ? '?' : pilotName[0].toUpperCase();

    return _FigmaPanel(
      layers: kFigmaLayersStats,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
        child: Row(
          children: [
            Container(
              width: 36 * s,
              height: 36 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: _cGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 14 * s,
                ),
              ),
            ),
            SizedBox(width: 12 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Çağrı kodun',
                    style: FigmaHomeTypography.studySubKonular(s * 0.9),
                  ),
                  SizedBox(height: 2 * s),
                  Text(
                    name,
                    style: FigmaHomeTypography.studyTitle(s * 0.9),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.lock_outline_rounded,
              color: kAccent.withValues(alpha: 0.9),
              size: 18 * s,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tek bir challenge sekmesi
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeTab extends StatefulWidget {
  const _ChallengeTab({
    required this.challenge,
    required this.userId,
    required this.pilotName,
  });
  final Challenge challenge;
  final String userId;
  final String pilotName;

  @override
  State<_ChallengeTab> createState() => _ChallengeTabState();
}

class _ChallengeTabState extends State<_ChallengeTab> {
  bool _loading = true;
  bool _attemptLocked = false;
  ChallengeResult? _myResult;
  ChallengeResult? _prevWinner;
  List<ChallengeResult> _board = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _settleAbandonedAttempt() async {
    if (await _hasChallengeInProgress(widget.challenge.id) != true) return;
    final existing = await ChallengeService.myResult(
      widget.challenge.id,
      widget.userId,
      challengeType: widget.challenge.type,
    );
    if (existing != null) {
      await _clearChallengeInProgress(widget.challenge.id);
      return;
    }
    await ChallengeService.submitResult(
      challengeId: widget.challenge.id,
      userId: widget.userId,
      score: 0,
      totalQuestions: widget.challenge.questionIds.length,
      totalMs: 0,
    );
    // Yalnızca sunucuda bir sonuç olduğundan eminsek yerel kilidi kaldır.
    await _clearChallengeInProgress(widget.challenge.id);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final localResult = _myResult;
    final hadPendingAttempt =
        await _hasChallengeInProgress(widget.challenge.id);
    try {
      await _settleAbandonedAttempt();
      final results = await Future.wait([
        ChallengeService.myResult(
          widget.challenge.id,
          widget.userId,
          challengeType: widget.challenge.type,
        ),
        ChallengeService.leaderboardForChallenge(widget.challenge),
        ChallengeService.previousWinner(widget.challenge.type),
      ]);
      if (mounted) {
        setState(() {
          // Firestore geçici olarak okunamazsa bu oturumdaki yerel sonucu
          // kaybetme; yeniden giriş butonu açılmamalı.
          _myResult = (results[0] as ChallengeResult?) ?? localResult;
          _board = results[1] as List<ChallengeResult>;
          _prevWinner = results[2] as ChallengeResult?;
          _attemptLocked = false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _attemptLocked = hadPendingAttempt;
          _loading = false;
        });
      }
    }
  }

  Future<void> _startChallenge() async {
    // Zaten tamamlandıysa girme
    if (_myResult != null) return;

    // Firestore'dan bir kez daha kontrol et (race condition önlemi)
    final existing = await ChallengeService.myResult(
      widget.challenge.id,
      widget.userId,
      challengeType: widget.challenge.type,
    );
    if (existing != null) {
      if (mounted) setState(() => _myResult = existing);
      return;
    }

    final questions = await ChallengeService.fetchQuestions(
      widget.challenge.questionIds,
      refillSeed:
          ChallengeService.refillSeedForChallengeId(widget.challenge.id),
      minCount: widget.challenge.questionIds.length,
    );
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorular yüklenemedi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _markChallengeInProgress(widget.challenge.id);
    if (!mounted) return;
    setState(() => _attemptLocked = true);

    final result = await Navigator.push<ChallengeResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeExamScreen(
          challenge: widget.challenge,
          questions: questions,
          userId: widget.userId,
          pilotName: widget.pilotName,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      // Uygulama kesilirse / beklenmeyen pop: terk edilmiş denemeyi kapat.
      await _settleAbandonedAttempt();
    } else {
      setState(() => _myResult = result);
    }
    await _load(); // leaderboard'u yenile
  }

  @override
  Widget build(BuildContext context) {
    final s = figmaHomeScale(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: kAccent,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          kHomePaddingH * s,
          14 * s,
          kHomePaddingH * s,
          24 * s,
        ),
        children: [
          if (_prevWinner != null) ...[
            _PreviousWinnerCard(
              winner: _prevWinner!,
              type: widget.challenge.type,
              isMe: _prevWinner!.userId == widget.userId,
            ),
            SizedBox(height: 12 * s),
          ],
          _ChallengeHeaderCard(
            scale: s,
            challenge: widget.challenge,
            myResult: _myResult,
            attemptLocked: _attemptLocked,
            onStart: (_myResult == null && !_loading && !_attemptLocked)
                ? _startChallenge
                : null,
          ),
          SizedBox(height: 20 * s),
          Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: _cGold, size: 18 * s),
              SizedBox(width: 8 * s),
              Text(
                'Sıralama',
                style: FigmaHomeTypography.studyTitle(s),
              ),
              const Spacer(),
              Text(
                '${_board.length} katılımcı',
                style: FigmaHomeTypography.studySubKonular(s),
              ),
            ],
          ),
          SizedBox(height: 12 * s),
          if (_board.isEmpty)
            _FigmaPanel(
              layers: kFigmaLayersStats,
              child: Padding(
                padding: EdgeInsets.all(24 * s),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        color: _cMuted, size: 40 * s),
                    SizedBox(height: 12 * s),
                    Text(
                      'Henüz kimse katılmadı.\nİlk sen ol!',
                      textAlign: TextAlign.center,
                      style: FigmaHomeTypography.studySubKonular(s),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._board.asMap().entries.map((e) => _LeaderboardRow(
                  rank: e.key + 1,
                  result: e.value,
                  isMe: e.value.userId == widget.userId,
                  questionCount: widget.challenge.questionIds.length,
                )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Challenge başlık kartı
// ─────────────────────────────────────────────────────────────────────────────

class _ChallengeHeaderCard extends StatelessWidget {
  const _ChallengeHeaderCard({
    required this.scale,
    required this.challenge,
    required this.myResult,
    required this.attemptLocked,
    required this.onStart,
  });
  final double scale;
  final Challenge challenge;
  final ChallengeResult? myResult;
  final bool attemptLocked;
  final VoidCallback? onStart;

  String _remainingText() {
    final r = challenge.remaining;
    if (r.isNegative) return 'Bu haftanın sınavı sona erdi';
    if (r.inHours >= 24) return 'Yeni sınava ${r.inDays} gün kaldı';
    if (r.inHours >= 1) return 'Yeni sınava ${r.inHours} saat kaldı';
    return 'Yeni sınava ${r.inMinutes} dakika kaldı';
  }

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final total = challenge.questionIds.length;
    final done = myResult != null;

    return _FigmaPanel(
      layers: kFigmaLayersHaftalik,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 108 * s,
            child: Stack(
              children: [
                Positioned(
                  right: 4 * s,
                  bottom: 0,
                  width: 104 * s,
                  height: 104 * s,
                  child: Image.asset(
                    'assets/home/card_haftalik.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16 * s, 18 * s, 100 * s, 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haftalık yarışma',
                        style: FigmaHomeTypography.studyTitle(s * 1.05),
                      ),
                      SizedBox(height: 8 * s),
                      Text(
                        'Bakım bilgini diğer kullanıcılarla karşılaştır.',
                        style: FigmaHomeTypography.studySubAccent(s),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16 * s, 0, 16 * s, 16 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _remainingText(),
                  style: TextStyle(
                    color: _cGold.withValues(alpha: 0.92),
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12 * s),
                if (done) ...[
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: _cCorrect, size: 18 * s),
                      SizedBox(width: 8 * s),
                      Expanded(
                        child: Text(
                          'Tamamladın: ${myResult!.score}/$total doğru',
                          style: TextStyle(
                            color: _cCorrect,
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * s,
                          ),
                        ),
                      ),
                      Text(
                        _formatMs(myResult!.totalMs),
                        style: FigmaHomeTypography.studySubKonular(s),
                      ),
                    ],
                  ),
                  SizedBox(height: 10 * s),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total > 0 ? myResult!.score / total : 0,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_cCorrect),
                    ),
                  ),
                ] else if (attemptLocked)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 13 * s),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'DENEMEN KAYDEDİLİYOR',
                      style: FigmaHomeTypography.studySubAccent(s),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('YARIŞMAYA KATIL'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final sec = ms ~/ 1000;
    final m = sec ~/ 60;
    final rs = sec % 60;
    return m > 0 ? '${m}dk ${rs}sn' : '${sec}sn';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leaderboard satırı
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.result,
    required this.isMe,
    required this.questionCount,
  });
  final int rank;
  final ChallengeResult result;
  final bool isMe;
  final int questionCount;

  String get _rankBadge {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rs = s % 60;
    return m > 0 ? '${m}dk ${rs}sn' : '${s}sn';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? kAccent.withValues(alpha: 0.1) : _cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? kAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _rankBadge,
              style: TextStyle(
                fontSize: rank <= 3 ? 20 : 14,
                color: rank <= 3 ? null : _cMuted,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AviationCallsignService.fromUserId(result.userId),
                      style: TextStyle(
                        color: isMe ? kAccent : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          '(sen)',
                          style: TextStyle(color: kAccent, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.score}/$questionCount doğru  •  ${_formatMs(result.totalMs)}',
                  style: const TextStyle(color: _cMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Doğruluk yüzdesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _scoreColor(result.score, questionCount)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '%${(result.accuracy * 100).round()}',
              style: TextStyle(
                color: _scoreColor(result.score, questionCount),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score, int total) {
    final ratio = total > 0 ? score / total : 0.0;
    if (ratio >= 0.8) return _cCorrect;
    if (ratio >= 0.5) return _cGold;
    return _cWrong;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sınav ekranı
// ─────────────────────────────────────────────────────────────────────────────

class ChallengeExamScreen extends StatefulWidget {
  const ChallengeExamScreen({
    super.key,
    required this.challenge,
    required this.questions,
    required this.userId,
    required this.pilotName,
  });
  final Challenge challenge;
  final List<SkyFightQuestion> questions;
  final String userId;
  final String pilotName;

  @override
  State<ChallengeExamScreen> createState() => _ChallengeExamScreenState();
}

class _ChallengeExamScreenState extends State<ChallengeExamScreen> {
  int _qIndex = 0;
  int _score = 0;
  int _totalMs = 0;
  bool _answered = false;
  String? _selected;
  bool _finished = false;
  bool _submitting = false;
  bool _resultSaved = false;

  // Süre sayacı (soru başına 20 saniye)
  int _secondsLeft = 20;
  Timer? _timer;
  int _qStartMs = 0;

  SkyFightQuestion get _q => widget.questions[_qIndex];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sınavı bırak?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Çıkarsan mevcut doğru sayın kaydedilir, cevaplanmayan sorular yanlış sayılır ve bu hafta tekrar giremezsin.',
          style: TextStyle(color: _cMuted, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Devam et', style: TextStyle(color: _cMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cWrong),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sınavı bitir'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _handleLeaveRequest() async {
    if (_finished || _submitting) return;
    final leave = await _confirmLeave();
    if (!leave || !mounted) return;
    await _finish(leftEarly: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 20;
    _qStartMs = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (_answered) return;
    _totalMs += DateTime.now().millisecondsSinceEpoch - _qStartMs;
    setState(() => _answered = true);
    _nextAfterDelay();
  }

  void _select(String key) {
    if (_answered) return;
    _timer?.cancel();
    final elapsed = DateTime.now().millisecondsSinceEpoch - _qStartMs;
    _totalMs += elapsed;
    setState(() {
      _answered = true;
      _selected = key;
      if (key == _q.correct) _score++;
    });
    _nextAfterDelay();
  }

  void _nextAfterDelay() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_qIndex < widget.questions.length - 1) {
        setState(() {
          _qIndex++;
          _answered = false;
          _selected = null;
        });
        _startTimer();
      } else {
        _finish();
      }
    });
  }

  Future<void> _finish({bool leftEarly = false}) async {
    if (_finished || _submitting) return;
    _timer?.cancel();
    setState(() {
      _finished = true;
      _submitting = true;
    });

    if (!_answered) {
      _totalMs += DateTime.now().millisecondsSinceEpoch - _qStartMs;
    }

    try {
      await ChallengeService.submitResult(
        challengeId: widget.challenge.id,
        userId: widget.userId,
        score: _score,
        totalQuestions: widget.questions.length,
        totalMs: _totalMs,
      );
      _resultSaved = true;
      await _clearChallengeInProgress(widget.challenge.id);
    } catch (_) {
      // Ağ / Firestore hatasında yerel kilit korunur. Ana ekran veya sonraki
      // açılış denemeyi tekrar kaydeder; kullanıcı yeniden sınava giremez.
      _resultSaved = false;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    _showResult(leftEarly: leftEarly);
  }

  void _showResult({bool leftEarly = false}) {
    final total = widget.questions.length;
    final accuracy = total > 0 ? _score / total : 0.0;
    final mins = _totalMs ~/ 60000;
    final secs = (_totalMs % 60000) ~/ 1000;
    final timeStr = mins > 0 ? '${mins}dk ${secs}sn' : '${secs}sn';

    Color color;
    String emoji;
    if (leftEarly) {
      color = _cGold;
      emoji = '⚠️';
    } else if (accuracy >= 0.8) {
      color = _cCorrect;
      emoji = '🏆';
    } else if (accuracy >= 0.5) {
      color = _cGold;
      emoji = '👍';
    } else {
      color = _cWrong;
      emoji = '📚';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          leftEarly ? '$emoji Sınav sonlandırıldı' : '$emoji Pratik tamamlandı',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              '$_score / $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const Text(
              'doğru cevap',
              style: TextStyle(color: _cMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    label: 'Doğruluk',
                    value: '%${(accuracy * 100).round()}',
                    color: color),
                _StatChip(label: 'Süre', value: timeStr, color: _cMuted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              leftEarly
                  ? (_resultSaved
                      ? 'Cevaplanmayan sorular yanlış sayıldı. Bu hafta tekrar giremezsin.'
                      : 'Denemen sonlandırıldı. Bağlantı kurulunca kaydedilecek; tekrar giremezsin.')
                  : (_resultSaved
                      ? 'Sonucun sıralamaya kaydedildi.'
                      : 'Sonucun bağlantı kurulunca sıralamaya kaydedilecek.'),
              style: const TextStyle(color: _cMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final result = ChallengeResult(
                id: '',
                challengeId: widget.challenge.id,
                userId: widget.userId,
                pilotName: widget.pilotName,
                score: _score,
                totalMs: _totalMs,
                accuracy: accuracy,
                submittedAt: DateTime.now(),
              );
              if (!leftEarly) {
                await AppReviewService.tryShowAfterCompletion(context);
              }
              if (mounted) Navigator.pop(context, result);
            },
            child: const Text(
              'Sıralamaya Dön',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Timer rengi
  Color get _timerColor {
    if (_secondsLeft > 10) return _cCorrect;
    if (_secondsLeft > 5) return _cGold;
    return _cWrong;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _finished || _submitting) return;
        await _handleLeaveRequest();
      },
      child: Scaffold(
        backgroundColor: kBgDark,
        appBar: AppBar(
          backgroundColor: kBgCard,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: _cMuted),
            tooltip: 'Sınavı bırak',
            onPressed: _finished || _submitting ? null : _handleLeaveRequest,
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildAeroTestAppBarTitle(
                      widget.challenge.label,
                      subtitleFontSize: 13,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Soru ${_qIndex + 1} / ${widget.questions.length}',
                      style: const TextStyle(color: _cMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Geri sayım
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _secondsLeft / 20,
                      strokeWidth: 3.5,
                      backgroundColor: const Color(0xFF253354),
                      valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
                    ),
                    Text(
                      '$_secondsLeft',
                      style: TextStyle(
                        color: _timerColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // İlerleme çubuğu
              LinearProgressIndicator(
                value: (_qIndex + 1) / widget.questions.length,
                backgroundColor: const Color(0xFF253354),
                valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                minHeight: 3,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Soru
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _cCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Text(
                          _q.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Şıklar
                      ..._q.options.entries.map((e) {
                        final key = e.key;
                        final val = e.value;
                        Color border = Colors.white.withValues(alpha: 0.08);
                        Color bg = _cCard;
                        Color text = Colors.white;

                        if (_answered) {
                          if (key == _q.correct) {
                            border = _cCorrect;
                            bg = _cCorrect.withValues(alpha: 0.15);
                            text = _cCorrect;
                          } else if (key == _selected &&
                              _selected != _q.correct) {
                            border = _cWrong;
                            bg = _cWrong.withValues(alpha: 0.12);
                            text = _cWrong;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: _answered ? null : () => _select(key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: border.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        key,
                                        style: TextStyle(
                                          color: text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      val,
                                      style:
                                          TextStyle(color: text, fontSize: 14),
                                    ),
                                  ),
                                  if (_answered && key == _q.correct)
                                    const Icon(Icons.check_rounded,
                                        color: _cCorrect, size: 18),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Önceki dönem şampiyonu kartı ─────────────────────────────────────────────

class _PreviousWinnerCard extends StatelessWidget {
  const _PreviousWinnerCard({
    required this.winner,
    required this.type,
    required this.isMe,
  });
  final ChallengeResult winner;
  final String type;
  final bool isMe;

  String get _periodLabel =>
      type == 'daily' ? 'Dünkü Günlük Sınav' : 'Geçen Hafta Şampiyonu';

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rs = s % 60;
    return m > 0 ? '${m}dk ${rs}sn' : '${s}sn';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD60A).withValues(alpha: 0.12),
            const Color(0xFF1C2541),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFFD60A).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _periodLabel,
                  style: const TextStyle(color: _cMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      AviationCallsignService.fromUserId(winner.userId),
                      style: TextStyle(
                        color: isMe ? kAccent : _cGold,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isMe)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          '(sen)',
                          style: TextStyle(color: kAccent, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${winner.score} doğru  •  %${(winner.accuracy * 100).round()}  •  ${_formatMs(winner.totalMs)}',
                  style: const TextStyle(color: _cMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _cGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '#1',
              style: TextStyle(
                color: _cGold,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yardımcı widget ───────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: _cMuted, fontSize: 11)),
      ],
    );
  }
}
