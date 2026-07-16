import 'dart:math';
import 'package:flutter/material.dart';
import '../models/kelime_model.dart';
import '../services/app_review_service.dart';
import '../services/calisma_istatistik_service.dart';
import '../services/kelime_mcq_options.dart';
import '../services/kelime_istatistik_service.dart';
import '../services/kelime_session_service.dart';
import '../services/kelime_yanlis_service.dart';
import '../theme/app_theme.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cCorrect   = Color(0xFF4CAF50);
const _cWrong     = Color(0xFFF44336);
const _cMuted     = Color(0xFFA1B5D8);
const _cGold      = Color(0xFFFFD60A);
const _cOptionBg  = Color(0xFF253354);
const _cTactic    = Color(0xFF233056);
const _cPurple    = Color(0xFF6C63FF);

// ─────────────────────────────────────────────────────────────────────────────

class KelimePratikScreen extends StatefulWidget {
  const KelimePratikScreen({
    super.key,
    required this.kelimeler,
    required this.tumKelimeler,
    this.isSessionMode = false,
    this.sessionMod = KelimeZorlukModu.kolay,
  });

  final List<KelimeModel> kelimeler;
  final List<KelimeModel> tumKelimeler;
  final bool isSessionMode;
  final KelimeZorlukModu sessionMod;

  @override
  State<KelimePratikScreen> createState() => _KelimePratikScreenState();
}

class _KelimePratikScreenState extends State<KelimePratikScreen> {
  int     _index    = 0;
  String? _secilen;
  List<String> _secenekler = [];
  bool    _reviewMilestoneQueued = false;
  late final DateTime _sessionStart;
  bool    _oturumKaydedildi = false;
  int     _dogruSayisi = 0;

  bool          get _answered  => _secilen != null;
  KelimeModel   get _kelime    => widget.kelimeler[_index];
  int           get _total     => widget.kelimeler.length;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _buildOptions();
  }

  Future<void> _kaydetOturum() async {
    if (_oturumKaydedildi) return;
    _oturumKaydedildi = true;
    final sn = DateTime.now().difference(_sessionStart).inSeconds;
    await CalismaIstatistikService.recordOturum(saniye: sn);
  }

  // ── 4 şık oluştur (1 doğru + 3 yanlış) ──────────────────────────────────
  void _buildOptions() {
    final rng = Random();
    setState(() {
      _secenekler = buildKelimeMcqTurkceOptions(
        _kelime,
        widget.tumKelimeler,
        random: rng,
      );
    });
  }

  // ── Şık seçme ─────────────────────────────────────────────────────────────
  Future<void> _selectOption(String opt) async {
    if (_answered) return;
    setState(() => _secilen = opt);

    final dogruMu = opt == _kelime.turkce;
    KelimeIstatistikService.recordAnswer(
      modul:   _kelime.modul,
      correct: dogruMu,
    );
    if (dogruMu) {
      _dogruSayisi++;
      KelimeYanlisService.removeYanlis(_kelime.id);
    } else {
      KelimeYanlisService.addYanlis(_kelime.id);
    }

    if (widget.isSessionMode) {
      await KelimeSessionService.recordTestAnswer(_kelime.id, dogruMu);
    }
  }

  // ── Sonraki / Bitir ───────────────────────────────────────────────────────
  Future<void> _next() async {
    final answered = _index + 1;
    final triggerAt = AppReviewService.milestoneTriggerAt(_total);
    if (answered >= triggerAt && !_reviewMilestoneQueued) {
      _reviewMilestoneQueued = true;
      await AppReviewService.tryShowAfterCompletion(context);
    }

    if (_index >= _total - 1) {
      _showDoneDialog();
      return;
    }
    setState(() {
      _index++;
      _secilen = null;
    });
    _buildOptions();
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() {
      _index--;
      _secilen = null;
    });
    _buildOptions();
  }

  void _showDoneDialog() {
    _kaydetOturum();

    final sessionMode = widget.isSessionMode;
    final zorMod = widget.sessionMod == KelimeZorlukModu.zor;
    final passed = sessionMode &&
        KelimeSessionService.canCompleteSession(
          mod: widget.sessionMod,
          correctCount: _dogruSayisi,
          total: _total,
        );
    final perfect = _dogruSayisi == _total;

    late final String title;
    late final String message;
    late final String actionLabel;

    if (!sessionMode) {
      title = 'Oturum Tamamlandı!';
      message =
          '$_total kelimeyi tamamladın. Yanlış yaptıkların "Yanlış Kelimelerim" listene eklendi.';
      actionLabel = 'Geri Dön';
    } else if (zorMod && !passed) {
      title = 'Tekrar Dene';
      message =
          '$_dogruSayisi/$_total doğru.\n\n'
          'Yeni kelimeleri görebilmek için 10/10 yapmalısın. Daha çok çalış!';
      actionLabel = 'Listeye Dön';
    } else if (perfect) {
      title = 'Tebrikler!';
      message = '$_dogruSayisi/$_total — yeni kelimelere geçebilirsin.';
      actionLabel = 'Geri Dön';
    } else {
      title = 'Oturum Tamamlandı!';
      message = '$_dogruSayisi/$_total ile oturumu tamamladın.';
      actionLabel = 'Geri Dön';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              zorMod && !passed
                  ? Icons.replay_circle_filled_rounded
                  : Icons.emoji_events_rounded,
              color: zorMod && !passed ? _cWrong : _cGold,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (!sessionMode) {
                navigator.pop();
                return;
              }
              if (zorMod && !passed) {
                await KelimeSessionService.retryHardSession();
                navigator.pop();
                return;
              }
              await KelimeSessionService.completeSession(widget.kelimeler);
              navigator.pop();
              navigator.pop();
            },
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Şık renk yardımcıları ─────────────────────────────────────────────────
  Color _borderColor(String opt) {
    if (!_answered)               return Colors.transparent;
    if (opt == _kelime.turkce)    return _cCorrect;
    if (opt == _secilen)          return _cWrong;
    return Colors.transparent;
  }

  Color _bgColor(String opt) {
    if (!_answered)               return _cOptionBg;
    if (opt == _kelime.turkce)    return _cCorrect.withValues(alpha: 0.12);
    if (opt == _secilen)          return _cWrong.withValues(alpha: 0.10);
    return _cOptionBg;
  }

  IconData? _trailingIcon(String opt) {
    if (!_answered)               return null;
    if (opt == _kelime.turkce)    return Icons.check_circle_rounded;
    if (opt == _secilen)          return Icons.cancel_rounded;
    return null;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final labels = ['A', 'B', 'C', 'D'];

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: buildAeroTestAppBarTitle('Kelime Çalışması', subtitleFontSize: 14),
      ),
      body: Column(
        children: [
          // İlerleme çizgisi
          LinearProgressIndicator(
            value: (_index + 1) / _total,
            backgroundColor: const Color(0xFF253354),
            valueColor: const AlwaysStoppedAnimation<Color>(_cPurple),
            minHeight: 3,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Kelime Kartı ──────────────────────────────────────
                  _WordCard(kelime: _kelime),
                  const SizedBox(height: 16),

                  // ── Şıklar ────────────────────────────────────────────
                  ...List.generate(_secenekler.length, (i) {
                    final opt = _secenekler[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionCard(
                        label:       labels[i],
                        text:        opt,
                        borderColor: _borderColor(opt),
                        bgColor:     _bgColor(opt),
                        icon:        _trailingIcon(opt),
                        iconColor:   opt == _kelime.turkce ? _cCorrect : _cWrong,
                        onTap:       _answered ? null : () => _selectOption(opt),
                      ),
                    );
                  }),

                  // ── Analiz Paneli ──────────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOut,
                    child: _answered
                        ? _AnalysisPanel(kelime: _kelime)
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── "Sonraki Kelime" Butonu ───────────────────────────────────────────
      bottomNavigationBar: AnimatedSlide(
        offset: _answered ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _answered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  if (_index > 0) ...[
                    Expanded(
                      child: _PrevKelimeButton(onTap: _prev),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _NextButton(
                      isLast: _index >= _total - 1,
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Kelime Kartı ─────────────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  const _WordCard({required this.kelime});
  final KelimeModel kelime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: _cPurple, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kelime.ingilizce,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          // Alt soru metni
          const Text(
            'Bu kelimenin Türkçe anlamı nedir?',
            style: TextStyle(color: _cMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Şık Kartı ────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.borderColor,
    required this.bgColor,
    required this.iconColor,
    this.icon,
    this.onTap,
  });

  final String        label;
  final String        text;
  final Color         borderColor;
  final Color         bgColor;
  final IconData?     icon;
  final Color         iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasBorder = borderColor != Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBorder ? borderColor : Colors.transparent,
          width: hasBorder ? 2.0 : 0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4)),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: iconColor, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Analiz Paneli ────────────────────────────────────────────────────────────

class _AnalysisPanel extends StatelessWidget {
  const _AnalysisPanel({required this.kelime});
  final KelimeModel kelime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // ── Örnek Cümle ───────────────────────────────────────────────
        if (kelime.ornekCumle != null) ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _cCorrect.withValues(alpha: 0.35)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        color: _cCorrect, size: 17),
                    SizedBox(width: 7),
                    Text(
                      'Örnek Kullanım',
                      style: TextStyle(
                        color: _cCorrect,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  kelime.ornekCumle!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── İpucu Kutusu ──────────────────────────────────────────────
        if (kelime.ipucu != null)
          Container(
            decoration: BoxDecoration(
              color: _cTactic,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: _cGold, width: 3),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.lightbulb_rounded, color: _cGold, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    kelime.ipucu!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.65),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Önceki Kelime Butonu ─────────────────────────────────────────────────────

class _PrevKelimeButton extends StatelessWidget {
  const _PrevKelimeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _cOptionBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: kAccent.withValues(alpha: 0.55),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back_rounded, color: kAccent, size: 20),
            SizedBox(width: 6),
            Text(
              'Önceki Kelime',
              style: TextStyle(
                color: kAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sonraki Kelime Butonu ────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onTap});
  final bool         isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _cPurple.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'Oturumu Tamamla  ✓' : 'Sonraki Kelime',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            if (!isLast) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
