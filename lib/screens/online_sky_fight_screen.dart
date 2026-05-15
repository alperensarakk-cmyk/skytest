import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sky_fight_question.dart';
import '../models/online_match.dart';
import '../services/online_match_service.dart';
import '../theme/app_theme.dart';

const _cGold    = Color(0xFFFFD60A);
const _cMuted   = Color(0xFFA1B5D8);
const _cCard    = Color(0xFF1C2541);
const _cPurple  = Color(0xFF6C63FF);
const _cCorrect = Color(0xFF4CAF50);
const _cWrong   = Color(0xFFF44336);
const _cOnline  = Color(0xFF00C2FF);

const _kRoundSeconds = 15;

class OnlineSkyFightScreen extends StatefulWidget {
  const OnlineSkyFightScreen({
    super.key,
    required this.matchId,
    required this.userId,
    required this.isPlayer1,
    required this.questions,
  });

  final String matchId;
  final String userId;
  final bool isPlayer1;
  final List<SkyFightQuestion> questions;

  @override
  State<OnlineSkyFightScreen> createState() => _OnlineSkyFightScreenState();
}

class _OnlineSkyFightScreenState extends State<OnlineSkyFightScreen>
    with TickerProviderStateMixin {
  // ── Oyun durumu ───────────────────────────────────────────────────────────
  int _roundIdx       = 0;
  int _myHp           = 100;
  int _opponentHp     = 100;
  bool _answered      = false;
  String? _myAnswer;
  String? _opponentAnswer;
  bool _gameOver      = false;
  bool _waitingForOpponent = false;

  // ── Geri sayım ────────────────────────────────────────────────────────────
  int    _secondsLeft   = _kRoundSeconds;
  Timer? _countdownTimer;
  Timer? _nextRoundTimer;

  // ── Firestore dinleyiciler ────────────────────────────────────────────────
  StreamSubscription<OnlineMatch>? _matchSub;
  StreamSubscription<RoundData?>?  _roundSub;
  RoundData? _lastRoundData;

  // ── Animasyonlar ──────────────────────────────────────────────────────────
  late AnimationController _myPunchCtrl;
  late AnimationController _opPunchCtrl;
  late Animation<Offset>   _myPunchAnim;
  late Animation<Offset>   _opPunchAnim;

  late AnimationController _myHpShakeCtrl;
  late AnimationController _opHpShakeCtrl;
  late Animation<double>   _myHpShake;
  late Animation<double>   _opHpShake;

  bool _showMyDmg  = false;
  bool _showOpDmg  = false;
  late AnimationController _myDmgCtrl;
  late AnimationController _opDmgCtrl;
  late Animation<double>   _myDmgFade;
  late Animation<double>   _opDmgFade;

  int _lastMyDmg = 0;
  int _lastOpDmg = 0;

  // ── Yardımcılar ───────────────────────────────────────────────────────────

  SkyFightQuestion get _question => widget.questions[_roundIdx];

  String get _opponentLabel {
    final opp = widget.isPlayer1 ? 'p2' : 'p1';
    return 'Pilot #$opp';
  }

  Color get _timerColor {
    if (_secondsLeft > 8) return _cCorrect;
    if (_secondsLeft > 4) return _cGold;
    return _cWrong;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _listenMatch();
    _listenRound(0);
    _startCountdown(DateTime.now().add(const Duration(seconds: _kRoundSeconds + 2)));
  }

  // ── Firestore dinleyiciler ────────────────────────────────────────────────

  void _listenMatch() {
    _matchSub = OnlineMatchService.watchMatch(widget.matchId).listen((match) {
      if (!mounted) return;
      setState(() {
        _myHp       = widget.isPlayer1 ? match.p1Hp : match.p2Hp;
        _opponentHp = widget.isPlayer1 ? match.p2Hp : match.p1Hp;
      });

      if (match.isFinished && !_gameOver) {
        _gameOver = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showResultDialog(match.winner);
        });
      }

      // Tur ilerlediyse (diğer client çözdü) → sonraki turu başlat.
      if (match.round > _roundIdx && !match.isFinished) {
        _advanceToRound(match.round);
      }
    });
  }

  void _listenRound(int idx) {
    _roundSub?.cancel();
    _roundSub = OnlineMatchService.watchRound(widget.matchId, idx)
        .listen((data) {
      if (!mounted || data == null) return;

      // Rakibin cevabını güncelle (sadece tur bitmemişse)
      if (!_answered && !data.resolved) {
        final opAns = widget.isPlayer1 ? data.p2Answer : data.p1Answer;
        if (opAns != null && _opponentAnswer == null) {
          setState(() {
            _opponentAnswer = opAns;
            _waitingForOpponent = false;
          });
        }
      }

      _lastRoundData = data;

      // Her iki taraf da cevapladıysa veya süre dolduysa → çöz.
      if (!data.resolved && data.bothAnswered) {
        _resolveRound(data);
      }
    });
  }

  // ── Geri sayım ────────────────────────────────────────────────────────────

  void _startCountdown(DateTime deadline) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final left = deadline.difference(DateTime.now()).inSeconds;
      setState(() => _secondsLeft = left.clamp(0, _kRoundSeconds));
      if (left <= 0) {
        t.cancel();
        _onLocalTimeout();
      }
    });
  }

  void _onLocalTimeout() {
    if (_answered || _gameOver) return;
    // Cevap vermeden süre doldu → null cevap ile çöz.
    _resolveRound(_lastRoundData);
  }

  // ── Kullanıcı cevabı ──────────────────────────────────────────────────────

  Future<void> _userSelect(String key) async {
    if (_answered || _gameOver) return;

    _countdownTimer?.cancel();
    final elapsed = (_kRoundSeconds - _secondsLeft) * 1000;

    setState(() {
      _answered  = true;
      _myAnswer  = key;
      _waitingForOpponent = _opponentAnswer == null;
    });

    await OnlineMatchService.submitAnswer(
      matchId: widget.matchId,
      roundIdx: _roundIdx,
      isPlayer1: widget.isPlayer1,
      answer: key,
      timeMs: elapsed,
    );

    // Eğer rakip zaten cevapladıysa, hemen çöz.
    if (_lastRoundData != null) {
      final opAns = widget.isPlayer1
          ? _lastRoundData!.p2Answer
          : _lastRoundData!.p1Answer;
      if (opAns != null) {
        setState(() {
          _opponentAnswer = opAns;
          _waitingForOpponent = false;
        });
        _resolveRound(_lastRoundData);
      }
    }
  }

  // ── Tur çözümü ────────────────────────────────────────────────────────────

  void _resolveRound(RoundData? data) {
    if (_answered && _waitingForOpponent && _opponentAnswer == null) return;

    final myAns  = _myAnswer;
    final opAns  = _opponentAnswer;
    final correct = _question.correct;

    final myCorrect = myAns == correct;
    final opCorrect = opAns == correct;

    // p1 ve p2 perspektifinden hasar hesapla.
    int p1DmgReceived = 0;
    int p2DmgReceived = 0;

    final iAmp1 = widget.isPlayer1;

    if (myCorrect && opCorrect) {
      // Hız karşılaştırması
      final myMs  = data != null
          ? (iAmp1 ? data.p1Ms : data.p2Ms) ?? 99999
          : 99999;
      final opMs  = data != null
          ? (iAmp1 ? data.p2Ms : data.p1Ms) ?? 99999
          : 99999;

      if (myMs <= opMs) {
        // Ben daha hızlım → rakibe hasar
        if (iAmp1) p2DmgReceived = 10; else p1DmgReceived = 10;
      } else {
        // Rakip daha hızlı → bana hasar
        if (iAmp1) p1DmgReceived = 10; else p2DmgReceived = 10;
      }
    } else if (myCorrect) {
      if (iAmp1) p2DmgReceived = 10; else p1DmgReceived = 10;
    } else if (opCorrect) {
      if (iAmp1) p1DmgReceived = 10; else p2DmgReceived = 10;
    }

    // UI hasar
    final myDmg = iAmp1 ? p1DmgReceived : p2DmgReceived;
    final opDmg = iAmp1 ? p2DmgReceived : p1DmgReceived;

    setState(() {
      _answered        = true;
      _waitingForOpponent = false;
      _lastMyDmg       = myDmg;
      _lastOpDmg       = opDmg;
    });

    _playDamageAnims(myDmg, opDmg);

    // Transaction ile Firestore güncelle (sadece bir kez çalışır).
    OnlineMatchService.resolveRound(
      matchId: widget.matchId,
      roundIdx: _roundIdx,
      totalRounds: widget.questions.length,
      p1DmgReceived: p1DmgReceived,
      p2DmgReceived: p2DmgReceived,
    );

    // Sonraki tura geç (matchSub üzerinden de gelecek ama yerel olarak da başlat).
    if (!_gameOver) {
      final nextIdx = _roundIdx + 1;
      if (nextIdx < widget.questions.length) {
        _nextRoundTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted) _advanceToRound(nextIdx);
        });
      }
    }
  }

  void _advanceToRound(int idx) {
    if (idx >= widget.questions.length || _gameOver) return;
    if (idx <= _roundIdx && _answered) return; // Aynı turu tekrar başlatma

    _nextRoundTimer?.cancel();
    setState(() {
      _roundIdx        = idx;
      _answered        = false;
      _myAnswer        = null;
      _opponentAnswer  = null;
      _waitingForOpponent = false;
      _secondsLeft     = _kRoundSeconds;
      _lastMyDmg       = 0;
      _lastOpDmg       = 0;
    });

    _listenRound(idx);
    _startCountdown(
      DateTime.now().add(const Duration(seconds: _kRoundSeconds + 2)),
    );
  }

  // ── Animasyonlar ──────────────────────────────────────────────────────────

  void _initAnimations() {
    _myPunchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opPunchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _myPunchAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(0.6, 0)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.6, 0), end: Offset.zero),
          weight: 50),
    ]).animate(CurvedAnimation(parent: _myPunchCtrl, curve: Curves.easeInOut));

    _opPunchAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.6, 0)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.6, 0), end: Offset.zero),
          weight: 50),
    ]).animate(CurvedAnimation(parent: _opPunchCtrl, curve: Curves.easeInOut));

    _myHpShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _opHpShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _myHpShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),  weight: 25),
    ]).animate(_myHpShakeCtrl);

    _opHpShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),  weight: 25),
    ]).animate(_opHpShakeCtrl);

    _myDmgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _opDmgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _myDmgFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _myDmgCtrl, curve: Curves.easeIn));
    _opDmgFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _opDmgCtrl, curve: Curves.easeIn));
  }

  void _playDamageAnims(int myDmg, int opDmg) {
    if (opDmg > 0) {
      _myPunchCtrl.forward(from: 0);
      _opHpShakeCtrl.forward(from: 0);
      setState(() => _showOpDmg = true);
      _opDmgCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showOpDmg = false);
      });
    }
    if (myDmg > 0) {
      _opPunchCtrl.forward(from: 0);
      _myHpShakeCtrl.forward(from: 0);
      setState(() => _showMyDmg = true);
      _myDmgCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showMyDmg = false);
      });
    }
  }

  // ── Sonuç ─────────────────────────────────────────────────────────────────

  void _showResultDialog(String? winner) {
    final iWon = (winner == 'p1' && widget.isPlayer1) ||
        (winner == 'p2' && !widget.isPlayer1);
    final isDraw = winner == 'draw';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isDraw ? '🤝 Berabere!' : (iWon ? '🏆 Zafer!' : '💀 Yenildin!'),
          style: TextStyle(
            color: isDraw ? _cGold : (iWon ? _cCorrect : _cWrong),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _HpResultRow(label: 'Sen', hp: _myHp, color: kAccent),
            const SizedBox(height: 8),
            _HpResultRow(
                label: _opponentLabel, hp: _opponentHp, color: _cOnline),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Lobiye Dön',
                style: TextStyle(color: _cMuted, fontSize: 14)),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: _cPurple),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/sky_fight');
            },
            child: const Text('Tekrar Oyna',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nextRoundTimer?.cancel();
    _matchSub?.cancel();
    _roundSub?.cancel();
    _myPunchCtrl.dispose();
    _opPunchCtrl.dispose();
    _myHpShakeCtrl.dispose();
    _opHpShakeCtrl.dispose();
    _myDmgCtrl.dispose();
    _opDmgCtrl.dispose();
    OnlineMatchService.cleanup(widget.userId);
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── HP barları ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Benim HP'm
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _myHpShake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_myHpShake.value, 0),
                        child: child,
                      ),
                      child: _HpBar(
                        label: 'Sen',
                        hp: _myHp,
                        color: kAccent,
                        showDmg: _showMyDmg,
                        dmgFade: _myDmgFade,
                        dmg: _lastMyDmg,
                        reversed: false,
                      ),
                    ),
                  ),
                  // Geri sayım
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _CountdownBadge(
                      seconds: _secondsLeft,
                      total: _kRoundSeconds,
                      color: _timerColor,
                    ),
                  ),
                  // Rakip HP
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _opHpShake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_opHpShake.value, 0),
                        child: child,
                      ),
                      child: _HpBar(
                        label: _opponentLabel,
                        hp: _opponentHp,
                        color: _cOnline,
                        showDmg: _showOpDmg,
                        dmgFade: _opDmgFade,
                        dmg: _lastOpDmg,
                        reversed: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Uçaklar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SlideTransition(
                    position: _myPunchAnim,
                    child: const _PlaneIcon(color: kAccent,   flip: false),
                  ),
                  // Online rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cOnline.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _cOnline.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      '🔴 CANLI',
                      style: TextStyle(
                        color: _cOnline,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _opPunchAnim,
                    child:
                        const _PlaneIcon(color: _cOnline, flip: true),
                  ),
                ],
              ),
            ),

            // ── İlerleme ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Soru ${_roundIdx + 1} / ${widget.questions.length}',
                    style: const TextStyle(color: _cMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_waitingForOpponent)
                    const Row(
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _cMuted,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Rakip bekleniyor...',
                          style: TextStyle(color: _cMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  if (_answered && !_waitingForOpponent && _myAnswer != null)
                    Icon(
                      _myAnswer == _question.correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _myAnswer == _question.correct
                          ? _cCorrect
                          : _cWrong,
                      size: 18,
                    ),
                  if (_answered && _myAnswer == null)
                    const Icon(Icons.timer_off_rounded,
                        color: _cMuted, size: 18),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                value: (_roundIdx + 1) / widget.questions.length,
                backgroundColor: const Color(0xFF253354),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(kAccent),
                minHeight: 3,
              ),
            ),

            // ── Soru & Şıklar ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Text(
                        _question.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    ...(_question.options.entries.map((e) {
                      final key = e.key;
                      final val = e.value;
                      Color borderColor =
                          Colors.white.withValues(alpha: 0.08);
                      Color bgColor    = _cCard;
                      Color textColor  = Colors.white;

                      if (_answered) {
                        if (key == _question.correct) {
                          borderColor = _cCorrect;
                          bgColor = _cCorrect.withValues(alpha: 0.15);
                          textColor = _cCorrect;
                        } else if (key == _myAnswer &&
                            _myAnswer != _question.correct) {
                          borderColor = _cWrong;
                          bgColor = _cWrong.withValues(alpha: 0.12);
                          textColor = _cWrong;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: _answered
                              ? null
                              : () => _userSelect(key),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderColor
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(7),
                                  ),
                                  child: Center(
                                    child: Text(
                                      key,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    val,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (_answered &&
                                    key == _question.correct)
                                  const Icon(Icons.check_rounded,
                                      color: _cCorrect, size: 18),
                                if (_answered &&
                                    key == _opponentAnswer &&
                                    key != _question.correct)
                                  Icon(
                                    Icons.person_rounded,
                                    color: _cOnline
                                        .withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })),

                    // Tur sonucu banner
                    if (_answered && !_waitingForOpponent)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4, bottom: 8),
                        child: _RoundResultBanner(
                          myAnswer: _myAnswer,
                          opponentAnswer: _opponentAnswer,
                          correct: _question.correct,
                          myDmg: _lastMyDmg,
                          opDmg: _lastOpDmg,
                          opponentLabel: _opponentLabel,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({
    required this.seconds,
    required this.total,
    required this.color,
  });
  final int seconds;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: seconds / total,
            strokeWidth: 4,
            backgroundColor: const Color(0xFF253354),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$seconds',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.label,
    required this.hp,
    required this.color,
    required this.showDmg,
    required this.dmgFade,
    required this.dmg,
    required this.reversed,
  });

  final String label;
  final int hp;
  final Color color;
  final bool showDmg;
  final Animation<double> dmgFade;
  final int dmg;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: reversed
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hp / 100,
                minHeight: 10,
                backgroundColor: const Color(0xFF253354),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 2),
            Text('$hp HP',
                style:
                    const TextStyle(color: _cMuted, fontSize: 10)),
          ],
        ),
        if (showDmg && dmg > 0)
          Positioned(
            top: -20,
            left: reversed ? null : 4,
            right: reversed ? 4 : null,
            child: FadeTransition(
              opacity: dmgFade,
              child: Text(
                '-$dmg HP',
                style: const TextStyle(
                  color: _cWrong,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlaneIcon extends StatelessWidget {
  const _PlaneIcon({required this.color, required this.flip});
  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3), blurRadius: 14),
          ],
        ),
        child: Icon(Icons.flight_rounded, color: color, size: 28),
      ),
    );
  }
}

class _RoundResultBanner extends StatelessWidget {
  const _RoundResultBanner({
    required this.myAnswer,
    required this.opponentAnswer,
    required this.correct,
    required this.myDmg,
    required this.opDmg,
    required this.opponentLabel,
  });

  final String? myAnswer;
  final String? opponentAnswer;
  final String correct;
  final int myDmg;
  final int opDmg;
  final String opponentLabel;

  @override
  Widget build(BuildContext context) {
    final myCorrect = myAnswer == correct;
    final opCorrect = opponentAnswer == correct;
    final timedOut  = myAnswer == null;

    String msg;
    Color  color;
    IconData icon;

    if (timedOut && opCorrect) {
      msg  = 'Süre doldu! $opponentLabel doğru cevapladı → -$myDmg HP';
      color = _cWrong;
      icon  = Icons.timer_off_rounded;
    } else if (timedOut) {
      msg  = 'Süre doldu! İkisi de yanlış — hasar yok';
      color = _cMuted;
      icon  = Icons.timer_off_rounded;
    } else if (myCorrect && opCorrect) {
      if (opDmg > 0) {
        msg  = 'Daha hızlısın! Rakibe -$opDmg HP vurdun';
        color = _cCorrect;
        icon  = Icons.bolt_rounded;
      } else {
        msg  = 'Rakip daha hızlıydı! -$myDmg HP aldın';
        color = _cWrong;
        icon  = Icons.bolt_rounded;
      }
    } else if (myCorrect) {
      msg  = 'Doğru! Rakibe -$opDmg HP vurdun';
      color = _cCorrect;
      icon  = Icons.check_circle_rounded;
    } else if (opCorrect) {
      msg  = 'Yanlış! -$myDmg HP aldın';
      color = _cWrong;
      icon  = Icons.cancel_rounded;
    } else {
      msg  = 'İkisi de yanlış — hasar yok';
      color = _cMuted;
      icon  = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (opponentAnswer != null) ...[
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.person_rounded,
                    color: _cMuted, size: 12),
                const SizedBox(width: 4),
                Text(
                  '$opponentAnswer ${opCorrect ? "✓" : "✗"}',
                  style: TextStyle(
                    color: opCorrect ? _cCorrect : _cWrong,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HpResultRow extends StatelessWidget {
  const _HpResultRow(
      {required this.label, required this.hp, required this.color});
  final String label;
  final int hp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        const Spacer(),
        Text('$hp HP',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }
}
