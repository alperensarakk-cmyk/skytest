import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/challenge.dart';
import '../models/sky_fight_question.dart';
import '../services/challenge_service.dart';
import '../services/sky_fight_service.dart';
import '../theme/app_theme.dart';

const _cGold    = Color(0xFFFFD60A);
const _cMuted   = Color(0xFFA1B5D8);
const _cCard    = Color(0xFF1C2541);
const _cCorrect = Color(0xFF4CAF50);
const _cWrong   = Color(0xFFF44336);
const _cGreen   = Color(0xFF083D5A);
const _kPilotNameKey = 'skyfight_pilot_name';

const _kBannedWords = <String>[
  // Türkçe
  'amk','bok','göt','orospu','piç','sik','oç','yarrak','pezevenk',
  'ibne','götveren','ananı','ananısikeyim','bok','şerefsiz','kahpe',
  // İngilizce
  'fuck','shit','bitch','ass','dick','cock','pussy','cunt','nigger',
  'faggot','whore','bastard',
];

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
  String  _pilotName = '';
  bool    _needsName = false;

  final _weekly = ChallengeService.thisWeekly();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid   = await SkyFightService.ensureSignedIn();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPilotNameKey) ?? '';
    // "Pilot #XXXX" otomatik isimler veya boş → kullanıcı seçmemiş sayılır
    final hasCustom = saved.isNotEmpty && !saved.startsWith('Pilot #');
    if (mounted) {
      setState(() {
        _userId    = uid;
        _pilotName = hasCustom ? saved : '';
        _needsName = !hasCustom;
      });
      if (_needsName) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showNamePicker(canDismiss: false),
        );
      }
    }
  }

  Future<void> _showNamePicker({bool canDismiss = true}) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: canDismiss,
      enableDrag: canDismiss,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NicknameSheet(
        initial: _pilotName,
        onSaved: (name) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kPilotNameKey, name);
          if (mounted) setState(() { _pilotName = name; _needsName = false; });
        },
      ),
    );
  }

  Future<void> _editPilotName() => _showNamePicker();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Haftalık Test',
            subtitleFontSize: 18),
      ),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : Column(
              children: [
                // ── Pilot şeridi ─────────────────────────────────────────
                GestureDetector(
                  onTap: _editPilotName,
                  child: Container(
                    color: kBgCard,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              const Color(0xFF0D1B2A),
                          child: Text(
                            (_pilotName.isEmpty ? '?' : _pilotName[0])
                                .toUpperCase(),
                            style: const TextStyle(
                              color: _cGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Kullanıcı Adı',
                                style: TextStyle(
                                    color: _cMuted, fontSize: 11),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _pilotName.isEmpty
                                    ? 'Belirtilmedi'
                                    : _pilotName,
                                style: TextStyle(
                                  color: _pilotName.isEmpty
                                      ? _cMuted
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B2A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: kAccent.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 13, color: kAccent),
                              SizedBox(width: 5),
                              Text(
                                'Değiştir',
                                style: TextStyle(
                                  color: kAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── İçerik ──────────────────────────────────────────────
                Expanded(
                  child: _ChallengeTab(
                    challenge: _weekly,
                    userId: _userId!,
                    pilotName: _pilotName,
                    onRequestName: () => _showNamePicker(canDismiss: false),
                  ),
                ),
              ],
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
    required this.onRequestName,
  });
  final Challenge challenge;
  final String userId;
  final String pilotName;
  final Future<void> Function() onRequestName;

  @override
  State<_ChallengeTab> createState() => _ChallengeTabState();
}

class _ChallengeTabState extends State<_ChallengeTab> {
  bool _loading = true;
  ChallengeResult? _myResult;
  ChallengeResult? _prevWinner;
  List<ChallengeResult> _board = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ChallengeService.myResult(widget.challenge.id, widget.userId),
        ChallengeService.leaderboard(widget.challenge.id),
        ChallengeService.previousWinner(widget.challenge.type),
      ]);
      if (mounted) {
        setState(() {
          _myResult   = results[0] as ChallengeResult?;
          _board      = results[1] as List<ChallengeResult>;
          _prevWinner = results[2] as ChallengeResult?;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChallenge() async {
    // Kullanıcı adı seçilmemişse önce picker aç
    if (widget.pilotName.isEmpty) {
      await widget.onRequestName();
      return; // picker kapandıktan sonra kullanıcı tekrar başlat'a basar
    }

    // Zaten tamamlandıysa girme
    if (_myResult != null) return;

    // Firestore'dan bir kez daha kontrol et (race condition önlemi)
    final existing = await ChallengeService.myResult(
        widget.challenge.id, widget.userId);
    if (existing != null) {
      if (mounted) setState(() => _myResult = existing);
      return;
    }

    final questions = await ChallengeService.fetchQuestions(
        widget.challenge.questionIds);
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

    if (result != null && mounted) {
      setState(() {
        _myResult = result;
      });
      _load(); // leaderboard'u yenile
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: kAccent));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: kAccent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Önceki dönem şampiyonu ────────────────────────────────────
          if (_prevWinner != null)
            _PreviousWinnerCard(
              winner: _prevWinner!,
              type: widget.challenge.type,
              isMe: _prevWinner!.userId == widget.userId,
            ),
          if (_prevWinner != null) const SizedBox(height: 12),

          // ── Başlık kartı ─────────────────────────────────────────────
          _ChallengeHeaderCard(
            challenge: widget.challenge,
            myResult: _myResult,
            onStart: (_myResult == null && !_loading) ? _startChallenge : null,
          ),
          const SizedBox(height: 20),

          // ── Leaderboard başlığı ───────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.leaderboard_rounded,
                  color: _cGold, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Sıralama',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_board.length} katılımcı',
                style: const TextStyle(color: _cMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_board.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      color: _cMuted, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Henüz kimse katılmadı.\nİlk sen ol!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _cMuted, fontSize: 14),
                  ),
                ],
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
    required this.challenge,
    required this.myResult,
    required this.onStart,
  });
  final Challenge challenge;
  final ChallengeResult? myResult;
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
    final total = challenge.questionIds.length;
    final done  = myResult != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF083D5A), Color(0xFF0B2B45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _cCorrect.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _remainingText(),
              style: TextStyle(
                color: _cGold.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bakım bilgilerini diğer kullanıcılar karşısında test et.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 16),

          if (done) ...[
            // Sonuç göster
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: _cCorrect, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Tamamladın: ${myResult!.score}/$total doğru',
                  style: const TextStyle(
                      color: _cCorrect,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _formatMs(myResult!.totalMs),
                  style: const TextStyle(color: _cMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: myResult!.score / total,
                minHeight: 8,
                backgroundColor: const Color(0xFF253354),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(_cCorrect),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _cCorrect,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white),
                label: const Text(
                  'Yarışmaya Katıl',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rs = s % 60;
    return m > 0 ? '${m}dk ${rs}sn' : '${s}sn';
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
        color: isMe
            ? kAccent.withValues(alpha: 0.1)
            : _cCard,
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
                      result.pilotName,
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
                          style: TextStyle(
                              color: kAccent, fontSize: 11),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
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
  int     _qIndex     = 0;
  int     _score      = 0;
  int     _totalMs    = 0;
  bool    _answered   = false;
  String? _selected;
  bool    _finished   = false;

  // Süre sayacı (soru başına 20 saniye)
  int    _secondsLeft = 20;
  Timer? _timer;
  int    _qStartMs    = 0;

  SkyFightQuestion get _q => widget.questions[_qIndex];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 20;
    _qStartMs    = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
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

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _finished = true);

    try {
      await ChallengeService.submitResult(
        challengeId: widget.challenge.id,
        userId: widget.userId,
        pilotName: widget.pilotName,
        score: _score,
        totalQuestions: widget.questions.length,
        totalMs: _totalMs,
      );
    } catch (_) {
      // Kayıt başarısız olsa bile sonuç ekranı gösterilsin.
    }

    if (!mounted) return;
    _showResult();
  }

  void _showResult() {
    final total    = widget.questions.length;
    final accuracy = total > 0 ? _score / total : 0.0;
    final mins     = _totalMs ~/ 60000;
    final secs     = (_totalMs % 60000) ~/ 1000;
    final timeStr  = mins > 0 ? '${mins}dk ${secs}sn' : '${secs}sn';

    Color color;
    String emoji;
    if (accuracy >= 0.8) { color = _cCorrect; emoji = '🏆'; }
    else if (accuracy >= 0.5) { color = _cGold;    emoji = '👍'; }
    else { color = _cWrong;   emoji = '📚'; }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$emoji Pratik tamamlandı',
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
            Text(
              'doğru cevap',
              style: const TextStyle(color: _cMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                    label: 'Doğruluk',
                    value: '%${(accuracy * 100).round()}',
                    color: color),
                _StatChip(
                    label: 'Süre',
                    value: timeStr,
                    color: _cMuted),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sonucun sıralamaya kaydedildi.',
              style: TextStyle(color: _cMuted, fontSize: 12),
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
            onPressed: () {
              Navigator.pop(context); // dialog
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
              Navigator.pop(context, result); // exam screen
            },
            child: const Text(
              'Sıralamaya Dön',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
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
    if (_secondsLeft > 5)  return _cGold;
    return _cWrong;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        automaticallyImplyLeading: false,
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
                    style: const TextStyle(
                        color: _cMuted, fontSize: 11),
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_timerColor),
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
                      Color bg     = _cCard;
                      Color text   = Colors.white;

                      if (_answered) {
                        if (key == _q.correct) {
                          border = _cCorrect;
                          bg     = _cCorrect.withValues(alpha: 0.15);
                          text   = _cCorrect;
                        } else if (key == _selected &&
                            _selected != _q.correct) {
                          border = _cWrong;
                          bg     = _cWrong.withValues(alpha: 0.12);
                          text   = _cWrong;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: _answered ? null : () => _select(key),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: border, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color:
                                        border.withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
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
                                    style: TextStyle(
                                        color: text, fontSize: 14),
                                  ),
                                ),
                                if (_answered &&
                                    key == _q.correct)
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
      type == 'daily' ? 'Dünkü Günlük Sınav' : 'Geçen Hafta';

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
        border: Border.all(
            color: const Color(0xFFFFD60A).withValues(alpha: 0.35)),
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
                      winner.pilotName,
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
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: _cMuted, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nickname seçim bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NicknameSheet extends StatefulWidget {
  const _NicknameSheet({required this.initial, required this.onSaved});
  final String initial;
  final Future<void> Function(String) onSaved;

  @override
  State<_NicknameSheet> createState() => _NicknameSheetState();
}

class _NicknameSheetState extends State<_NicknameSheet> {
  late final TextEditingController _ctrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) {
      setState(() => _error = 'Lütfen bir isim gir.');
      return;
    }
    final lower = v.toLowerCase();
    if (_kBannedWords.any((w) => lower.contains(w))) {
      setState(() => _error = 'Bu isim uygun değil, başka bir isim seç.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await widget.onSaved(v);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutma çubuğu
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: _cMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kullanıcı Adı Seç',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Liderlik tablosunda bu isimle görünürsün.',
              style: TextStyle(color: _cMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLength: 14,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9 _\-]')),
              ],
              decoration: InputDecoration(
                hintText: 'Örnek: AceWrench47',
                hintStyle: const TextStyle(color: _cMuted),
                errorText: _error,
                filled: true,
                fillColor: kBgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: kAccent, width: 1.5),
                ),
                counterStyle: const TextStyle(color: _cMuted),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Devam Et',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kBgDark),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
