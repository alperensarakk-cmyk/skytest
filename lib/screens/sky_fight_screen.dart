import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sky_fight_question.dart';
import '../models/ghost_record.dart';
import '../services/ai_pilot_service.dart';
import '../services/sky_fight_service.dart';
import '../services/ghost_service.dart';
import '../theme/app_theme.dart';

const _cGold   = Color(0xFFFFD60A);
const _cMuted  = Color(0xFFA1B5D8);
const _cCard   = Color(0xFF1C2541);
const _cPurple = Color(0xFF6C63FF);
const _cCorrect = Color(0xFF4CAF50);
const _cWrong   = Color(0xFFF44336);

const _kRoundSeconds = 15;

class SkyFightScreen extends StatefulWidget {
  const SkyFightScreen({
    super.key,
    required this.userId,
    required this.questions,
    this.ghostRecord,  // null → AI modu
    this.pilotName,    // oyuncunun kendi ismi (ghost kaydı için)
  });

  final String userId;
  final List<SkyFightQuestion> questions;
  final GhostRecord? ghostRecord;
  final String? pilotName;

  @override
  State<SkyFightScreen> createState() => _SkyFightScreenState();
}

class _SkyFightScreenState extends State<SkyFightScreen>
    with TickerProviderStateMixin {
  // ── Oyun durumu ──────────────────────────────────────────────────────────────
  int _qIndex       = 0;
  int _userHp       = 100;
  int _aiHp         = 100;
  bool _answered    = false;
  String? _userAnswer;
  String? _aiAnswer;
  bool _gameOver    = false;

  final List<String?> _userAnswers = [];
  final List<int?>    _userTimesMs = [];

  int _questionStartMs = 0;

  // ── Geri sayım ───────────────────────────────────────────────────────────────
  int    _secondsLeft     = _kRoundSeconds;
  Timer? _countdownTimer;
  Timer? _aiTimer;

  // ── Animasyonlar ─────────────────────────────────────────────────────────────
  late AnimationController _userPunchCtrl;
  late AnimationController _aiPunchCtrl;
  late Animation<Offset>   _userPunchAnim;
  late Animation<Offset>   _aiPunchAnim;

  late AnimationController _userHpShakeCtrl;
  late AnimationController _aiHpShakeCtrl;
  late Animation<double>   _userHpShake;
  late Animation<double>   _aiHpShake;

  bool _showUserDmg = false;
  bool _showAiDmg   = false;
  late AnimationController _userDmgCtrl;
  late AnimationController _aiDmgCtrl;
  late Animation<double>   _userDmgFade;
  late Animation<double>   _aiDmgFade;

  int _lastUserDmg = 0;
  int _lastAiDmg   = 0;

  SkyFightQuestion get _question => widget.questions[_qIndex];

  bool get _isGhostMode => widget.ghostRecord != null;

  String get _opponentLabel =>
      widget.ghostRecord?.pilotName ?? 'AI Pilot';

  Color get _opponentColor =>
      _isGhostMode ? const Color(0xFF00E5FF) : _cPurple;

  // ── Geri sayım rengi ─────────────────────────────────────────────────────────
  Color get _timerColor {
    if (_secondsLeft > 8) return _cCorrect;
    if (_secondsLeft > 4) return _cGold;
    return _cWrong;
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startQuestion();
  }

  void _initAnimations() {
    _userPunchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _aiPunchCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _userPunchAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(0.6, 0)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.6, 0), end: Offset.zero),
          weight: 50),
    ]).animate(CurvedAnimation(parent: _userPunchCtrl, curve: Curves.easeInOut));

    _aiPunchAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: const Offset(-0.6, 0)),
          weight: 50),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.6, 0), end: Offset.zero),
          weight: 50),
    ]).animate(CurvedAnimation(parent: _aiPunchCtrl, curve: Curves.easeInOut));

    _userHpShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _aiHpShakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _userHpShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),  weight: 25),
    ]).animate(_userHpShakeCtrl);

    _aiHpShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),  weight: 25),
    ]).animate(_aiHpShakeCtrl);

    _userDmgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _aiDmgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _userDmgFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _userDmgCtrl, curve: Curves.easeIn));
    _aiDmgFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _aiDmgCtrl, curve: Curves.easeIn));
  }

  void _startQuestion() {
    _answered        = false;
    _userAnswer      = null;
    _aiAnswer        = null;
    _secondsLeft     = _kRoundSeconds;
    _questionStartMs = DateTime.now().millisecondsSinceEpoch;

    // Geri sayım
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _onTimeout();
      }
    });

    // Rakip zamanlayıcısı (ghost veya AI)
    final delay = _opponentDelay();
    _aiTimer = Timer(Duration(milliseconds: delay), _aiRespond);
  }

  void _onTimeout() {
    if (_answered) return;
    if (_aiAnswer == null) {
      _aiAnswer = _opponentAnswer();
    }
    _resolveRound(timedOut: true);
  }

  int _opponentDelay() {
    final ghost = widget.ghostRecord;
    if (ghost != null && _qIndex < ghost.rounds.length) {
      return ghost.rounds[_qIndex].timeMs.clamp(300, 14500);
    }
    return AiPilotService.responseDelayMs(_qIndex);
  }

  String? _opponentAnswer() {
    final ghost = widget.ghostRecord;
    if (ghost != null && _qIndex < ghost.rounds.length) {
      return ghost.rounds[_qIndex].answer;
    }
    final keys = _question.options.keys.toList();
    return AiPilotService.answer(_qIndex, _question.correct, keys);
  }

  void _aiRespond() {
    if (_answered || !mounted) return;
    _aiAnswer = _opponentAnswer();
    if (!_answered) _resolveRound();
  }

  Future<void> _userSelect(String key) async {
    if (_answered) return;
    _countdownTimer?.cancel();
    _aiTimer?.cancel();

    final elapsed = DateTime.now().millisecondsSinceEpoch - _questionStartMs;
    _userAnswer = key;
    _userTimesMs.add(elapsed);
    _userAnswers.add(key);

    if (_aiAnswer == null) {
      _aiAnswer = _opponentAnswer();
    }

    _resolveRound();
  }

  void _resolveRound({bool timedOut = false}) {
    if (_answered) return;
    setState(() => _answered = true);

    final userCorrect = _userAnswer != null && _userAnswer == _question.correct;
    final aiCorrect   = _aiAnswer   != null && _aiAnswer   == _question.correct;

    int userDmg = 0;
    int aiDmg   = 0;

    if (userCorrect && aiCorrect) {
      // İkisi de doğru → daha hızlı olan vurur
      final userMs = _userTimesMs.isNotEmpty
          ? (_userTimesMs.last ?? 9999999)
          : 9999999;
      final aiMs = _opponentDelay();
      if (userMs <= aiMs) {
        aiDmg = 10;
      } else {
        userDmg = 10;
      }
    } else if (userCorrect && !aiCorrect) {
      // Sadece kullanıcı doğru (AI yanlış veya süre doldu)
      aiDmg = 10;
    } else if (!userCorrect && aiCorrect) {
      // Sadece AI doğru (kullanıcı yanlış veya süre doldu)
      userDmg = 10;
    }
    // Her ikisi de yanlış/boş → hasar yok

    setState(() {
      _userHp      = (_userHp - userDmg).clamp(0, 100);
      _aiHp        = (_aiHp   - aiDmg).clamp(0, 100);
      _lastUserDmg = userDmg;
      _lastAiDmg   = aiDmg;
    });

    if (aiDmg > 0) {
      _userPunchCtrl.forward(from: 0);
      _aiHpShakeCtrl.forward(from: 0);
      setState(() => _showAiDmg = true);
      _aiDmgCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showAiDmg = false);
      });
    }
    if (userDmg > 0) {
      _aiPunchCtrl.forward(from: 0);
      _userHpShakeCtrl.forward(from: 0);
      setState(() => _showUserDmg = true);
      _userDmgCtrl.forward(from: 0).then((_) {
        if (mounted) setState(() => _showUserDmg = false);
      });
    }

    // Kayıt
    if (!timedOut && _userAnswer != null) {
      // zaten _userAnswers'a eklendi
    } else if (timedOut) {
      _userAnswers.add(null);
      _userTimesMs.add(null);
    }

    if (_userHp <= 0 || _aiHp <= 0) {
      Future.delayed(const Duration(milliseconds: 1200), _endGame);
      return;
    }

    if (_qIndex < widget.questions.length - 1) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        setState(() {
          _qIndex++;
          _startQuestion();
        });
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1800), _endGame);
    }
  }

  Future<void> _endGame() async {
    if (!mounted || _gameOver) return;
    setState(() => _gameOver = true);

    while (_userAnswers.length < widget.questions.length) {
      _userAnswers.add(null);
      _userTimesMs.add(null);
    }

    await SkyFightService.logMatchResult(
      userId: widget.userId,
      questions: widget.questions,
      userAnswers: _userAnswers,
      userTimesMs: _userTimesMs,
      userScore: _aiHp <= 0 ? 1 : (_userHp <= 0 ? 0 : -1),
      opponentScore: _userHp <= 0 ? 1 : (_aiHp <= 0 ? 0 : -1),
    );

    // Bu maçı ghost olarak kaydet (arka planda).
    GhostService.save(
      userId: widget.userId,
      pilotName: widget.pilotName,
      questions: widget.questions,
      answers: _userAnswers,
      timesMs: _userTimesMs,
      finalHp: _userHp,
    );

    if (!mounted) return;
    _showResultDialog();
  }

  void _showResultDialog() {
    final win  = _userHp > _aiHp;
    final draw = _userHp == _aiHp;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          draw ? '🤝 Berabere!' : (win ? '🏆 Zafer!' : '💀 Yenildin!'),
          style: TextStyle(
            color: draw ? _cGold : (win ? _cCorrect : _cWrong),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _HpResultRow(label: 'Sen',      hp: _userHp, color: kAccent),
            const SizedBox(height: 8),
            _HpResultRow(label: _opponentLabel, hp: _aiHp, color: _opponentColor),
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
            style: FilledButton.styleFrom(backgroundColor: _cPurple),
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
    _aiTimer?.cancel();
    _userPunchCtrl.dispose();
    _aiPunchCtrl.dispose();
    _userHpShakeCtrl.dispose();
    _aiHpShakeCtrl.dispose();
    _userDmgCtrl.dispose();
    _aiDmgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── HP barları ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _userHpShake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_userHpShake.value, 0),
                        child: child,
                      ),
                      child: _HpBar(
                        label: 'Sen',
                        hp: _userHp,
                        color: kAccent,
                        showDmg: _showUserDmg,
                        dmgFade: _userDmgFade,
                        dmg: _lastUserDmg,
                        reversed: false,
                      ),
                    ),
                  ),
                  // ── Geri sayım ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _CountdownBadge(
                      seconds: _secondsLeft,
                      total: _kRoundSeconds,
                      color: _timerColor,
                    ),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _aiHpShake,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(_aiHpShake.value, 0),
                        child: child,
                      ),
                      child: _HpBar(
                        label: _opponentLabel,
                        hp: _aiHp,
                        color: _opponentColor,
                        showDmg: _showAiDmg,
                        dmgFade: _aiDmgFade,
                        dmg: _lastAiDmg,
                        reversed: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Uçak animasyonları ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SlideTransition(
                    position: _userPunchAnim,
                    child: const _PlaneIcon(color: kAccent,   flip: false),
                  ),
                  SlideTransition(
                    position: _aiPunchAnim,
                    child: _PlaneIcon(color: _opponentColor, flip: true),
                  ),
                ],
              ),
            ),

            // ── İlerleme çubuğu ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Soru ${_qIndex + 1} / ${widget.questions.length}',
                    style: const TextStyle(color: _cMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_answered && _userAnswer != null)
                    Icon(
                      _userAnswer == _question.correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _userAnswer == _question.correct
                          ? _cCorrect
                          : _cWrong,
                      size: 18,
                    ),
                  if (_answered && _userAnswer == null)
                    const Icon(Icons.timer_off_rounded,
                        color: _cMuted, size: 18),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                value: (_qIndex + 1) / widget.questions.length,
                backgroundColor: const Color(0xFF253354),
                valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                minHeight: 3,
              ),
            ),

            // ── Soru & şıklar ────────────────────────────────────────────────────
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
                            color: Colors.white.withValues(alpha: 0.06)),
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
                      Color borderColor = Colors.white.withValues(alpha: 0.08);
                      Color bgColor    = const Color(0xFF1C2541);
                      Color textColor  = Colors.white;

                      if (_answered) {
                        if (key == _question.correct) {
                          borderColor = _cCorrect;
                          bgColor     = _cCorrect.withValues(alpha: 0.15);
                          textColor   = _cCorrect;
                        } else if (key == _userAnswer &&
                            _userAnswer != _question.correct) {
                          borderColor = _cWrong;
                          bgColor     = _cWrong.withValues(alpha: 0.12);
                          textColor   = _cWrong;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: _answered ? null : () => _userSelect(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: borderColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(7),
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
                                if (_answered && key == _question.correct)
                                  const Icon(Icons.check_rounded,
                                      color: _cCorrect, size: 18),
                                if (_answered &&
                                    key == _aiAnswer &&
                                    key != _question.correct)
                                  const Icon(Icons.smart_toy_rounded,
                                      color: _cPurple, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    })),

                    // Sonuç mesajı
                    if (_answered)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: _RoundResultBanner(
                          userAnswer: _userAnswer,
                          aiAnswer: _aiAnswer,
                          correct: _question.correct,
                          userDmg: _lastUserDmg,
                          aiDmg: _lastAiDmg,
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

// ── Geri sayım rozeti ─────────────────────────────────────────────────────────

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
    final progress = seconds / total;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
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

// ── Tur sonucu banner ─────────────────────────────────────────────────────────

class _RoundResultBanner extends StatelessWidget {
  const _RoundResultBanner({
    required this.userAnswer,
    required this.aiAnswer,
    required this.correct,
    required this.userDmg,
    required this.aiDmg,
  });

  final String? userAnswer;
  final String? aiAnswer;
  final String  correct;
  final int     userDmg;
  final int     aiDmg;

  @override
  Widget build(BuildContext context) {
    final userCorrect = userAnswer == correct;
    final aiCorrect   = aiAnswer   == correct;
    final timedOut    = userAnswer == null;

    String msg;
    Color  color;
    IconData icon;

    if (timedOut && aiCorrect) {
      msg   = 'Süre doldu! AI doğru cevapladı → -$userDmg HP';
      color = _cWrong;
      icon  = Icons.timer_off_rounded;
    } else if (timedOut && !aiCorrect) {
      msg   = 'Süre doldu! İkisi de yanlış — hasar yok';
      color = _cMuted;
      icon  = Icons.timer_off_rounded;
    } else if (userCorrect && aiCorrect) {
      if (aiDmg > 0) {
        msg  = 'Daha hızlısın! AI\'ya -$aiDmg HP vurdun';
        color = _cCorrect;
        icon  = Icons.bolt_rounded;
      } else {
        msg  = 'AI daha hızlıydı! -$userDmg HP aldın';
        color = _cWrong;
        icon  = Icons.bolt_rounded;
      }
    } else if (userCorrect) {
      msg   = 'Doğru! AI\'ya -$aiDmg HP vurdun';
      color = _cCorrect;
      icon  = Icons.check_circle_rounded;
    } else if (aiCorrect) {
      msg   = 'Yanlış! -$userDmg HP aldın';
      color = _cWrong;
      icon  = Icons.cancel_rounded;
    } else {
      msg   = 'İkisi de yanlış — hasar yok';
      color = _cMuted;
      icon  = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              style: TextStyle(color: color, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          // AI cevabı
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, color: _cMuted, size: 12),
              const SizedBox(width: 4),
              Text(
                'AI: ${aiAnswer ?? "—"} '
                '${aiCorrect ? "✓" : "✗"}',
                style: TextStyle(
                  color: aiCorrect ? _cCorrect : _cWrong,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── HP Bar ───────────────────────────────────────────────────────────────────

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
          crossAxisAlignment:
              reversed ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            Text(
              '$hp HP',
              style: const TextStyle(color: _cMuted, fontSize: 10),
            ),
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

// ── Uçak ikonu ───────────────────────────────────────────────────────────────

class _PlaneIcon extends StatelessWidget {
  const _PlaneIcon({required this.color, required this.flip});
  final Color color;
  final bool  flip;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14),
          ],
        ),
        child: Icon(Icons.flight_rounded, color: color, size: 32),
      ),
    );
  }
}

// ── Sonuç satırı ─────────────────────────────────────────────────────────────

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
                color: color, fontWeight: FontWeight.w600, fontSize: 14)),
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
