import 'package:flutter/material.dart';
import '../models/soru_model.dart';
import '../services/daily_limit_service.dart';
import '../services/soru_son_gorulen_service.dart';
import '../services/premium_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/limit_exceeded_dialog.dart';
import '../widgets/scrollable_paragraf_card.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cCorrect  = Color(0xFF4CAF50);
const _cWrong    = Color(0xFFF44336);
const _cTactic   = Color(0xFF233056);
const _cGold     = Color(0xFFFFD60A);
const _cMuted    = Color(0xFFA1B5D8);
const _cOptionBg = Color(0xFF253354);

// ─── Pratik Ekranı ────────────────────────────────────────────────────────────

class KonuPratikScreen extends StatefulWidget {
  const KonuPratikScreen({
    super.key,
    required this.kategoriAdi,
    required this.sorular,
  });

  final String            kategoriAdi;
  final List<SoruModel>   sorular;

  @override
  State<KonuPratikScreen> createState() => _KonuPratikScreenState();
}

class _KonuPratikScreenState extends State<KonuPratikScreen> {
  int     _index   = 0;
  String? _secilen;

  bool get _answered => _secilen != null;
  SoruModel get _soru  => widget.sorular[_index];
  int        get _total => widget.sorular.length;

  // ── Şık seçme ─────────────────────────────────────────────────────────────
  Future<void> _selectOption(String k) async {
    if (_answered) return;
    setState(() => _secilen = k);

    if (k == _soru.dogruCevap) {
      YanlisService.removeYanlis(_soru.id);
    } else {
      YanlisService.addYanlis(_soru.id);
    }

    if (!await PremiumService.isPremiumUser()) {
      await DailyLimitService.recordKonuAnswered();
      final rem = await DailyLimitService.konuRemaining();
      if (!mounted) return;
      if (rem <= 0) {
        final r = await showDailyLimitExceededDialog(context);
        if (!mounted) return;
        if (r != LimitExceededResult.premium) {
          Navigator.pop(context);
        }
      }
    }
  }

  // ── Sonraki soru / bitir ──────────────────────────────────────────────────
  void _next() {
    if (_index >= _total - 1) {
      _showDoneDialog();
      return;
    }
    setState(() {
      _index++;
      _secilen = null;
    });
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() {
      _index--;
      _secilen = null;
    });
  }

  void _showDoneDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _cGold, size: 24),
            SizedBox(width: 10),
            Text('Konu Tamamlandı!',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          '"${widget.kategoriAdi}" konusundaki tüm $_total soruyu tamamladın. Harika iş!',
          style: const TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog kapat
              Navigator.pop(context); // konu listesine dön
            },
            child: const Text('Konulara Dön',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Şık renk yardımcıları ─────────────────────────────────────────────────
  Color _borderColor(String k) {
    if (!_answered)                   return Colors.transparent;
    if (k == _soru.dogruCevap)        return _cCorrect;
    if (k == _secilen)                return _cWrong;
    return Colors.transparent;
  }

  Color _bgColor(String k) {
    if (!_answered)                   return _cOptionBg;
    if (k == _soru.dogruCevap)        return _cCorrect.withValues(alpha: 0.12);
    if (k == _secilen)                return _cWrong.withValues(alpha: 0.10);
    return _cOptionBg;
  }

  IconData? _trailingIcon(String k) {
    if (!_answered)                   return null;
    if (k == _soru.dogruCevap)        return Icons.check_circle_rounded;
    if (k == _secilen)                return Icons.cancel_rounded;
    return null;
  }

  Color _trailingColor(String k) =>
      k == _soru.dogruCevap ? _cCorrect : _cWrong;

  @override
  void dispose() {
    if (widget.sorular.isNotEmpty) {
      SoruSonGorulenService.recordSessionIds(
        widget.sorular.take(_index + 1).map((s) => s.id),
      );
    }
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.sorular.isEmpty) {
      return Scaffold(
        backgroundColor: kBgDark,
        appBar: AppBar(
          backgroundColor: kBgCard,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.kategoriAdi,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu oturum için soru bulunamadı.\nLütfen konu seçimini veya veri dosyasını kontrol edin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _cMuted, fontSize: 15, height: 1.5),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.kategoriAdi,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // İnce ilerleme çizgisi
          LinearProgressIndicator(
            value: _total > 0 ? (_index + 1) / _total : null,
            backgroundColor: const Color(0xFF253354),
            valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
            minHeight: 3,
          ),

          // İçerik
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_soru.paragraf.isNotEmpty &&
                      !_soru.paragrafSoruMetniyleOzdes) ...[
                    ScrollableParagrafCard(
                      key: ValueKey(_soru.id),
                      paragraf: _soru.paragraf,
                    ),
                    const SizedBox(height: 16),
                  ],
                  // ── Soru Kartı ────────────────────────────────────────
                  _SoruMetniVeyaYonlendirme(soru: _soru),
                  const SizedBox(height: 16),

                  // ── Şıklar ────────────────────────────────────────────
                  ...['a', 'b', 'c', 'd'].map((k) {
                    final text = _soru.secenekler[k];
                    if (text == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionCard(
                        label:       k.toUpperCase(),
                        text:        text,
                        borderColor: _borderColor(k),
                        bgColor:     _bgColor(k),
                        icon:        _trailingIcon(k),
                        iconColor:   _trailingColor(k),
                        onTap: _answered ? null : () => _selectOption(k),
                      ),
                    );
                  }),

                  // ── Analiz Paneli ─────────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOut,
                    child: _answered
                        ? _AnalysisPanel(soru: _soru)
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Önceki / Sonraki ─────────────────────────────────────────────────
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
                      child: _PrevKonuButton(onTap: _prev),
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

// ─── Alt Widgetlar ────────────────────────────────────────────────────────────

class _SoruMetniVeyaYonlendirme extends StatelessWidget {
  const _SoruMetniVeyaYonlendirme({required this.soru});
  final SoruModel soru;

  @override
  Widget build(BuildContext context) {
    if (soru.soruMetniParagrafinClozeVeyaBenzeri) {
      return _QuestionCard(
        text: SoruModel.clozeYonlendirmeMetni,
        muted: true,
      );
    }
    return _QuestionCard(text: soru.soruMetni);
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.text, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        style: TextStyle(
          color: muted ? _cMuted : Colors.white,
          fontSize: muted ? 14 : 16,
          height: 1.65,
          fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
        ),
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

  final String     label;
  final String     text;
  final Color      borderColor;
  final Color      bgColor;
  final IconData?  icon;
  final Color      iconColor;
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
                // Harf baloncuğu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: kAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Şık metni
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                // Doğru/yanlış ikonu
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
  const _AnalysisPanel({required this.soru});
  final SoruModel soru;

  @override
  Widget build(BuildContext context) {
    final dogruMetin =
        '${soru.dogruCevap.toUpperCase()}. ${soru.secenekler[soru.dogruCevap] ?? ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // ── 1. Doğru Cevap & Açıklama ─────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1F12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cCorrect.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _cCorrect, size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Doğru Cevap & Açıklama',
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
              // Doğru şık metni
              Text(
                dogruMetin,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              // Neden doğru açıklaması
              Text(
                soru.nedenDogru,
                style: const TextStyle(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── 2. Yanlış Şıklar Açıklaması ──────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: kBgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Color(0xFF8DA5C8), size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Neden Yanlış?',
                    style: TextStyle(
                      color: Color(0xFF8DA5C8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                soru.yanlislar,
                style: const TextStyle(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── 3. Taktik Kutusu ──────────────────────────────────────────
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
                  soru.tip,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Önceki Soru Butonu (Sonraki ile aynı boyut / stil ailesi) ────────────────

class _PrevKonuButton extends StatelessWidget {
  const _PrevKonuButton({required this.onTap});
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
              'Önceki Soru',
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

// ─── Sonraki Soru Butonu ──────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onTap});
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF48CAE4), Color(0xFF0096C7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF48CAE4).withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'Konuyu Tamamla  ✓' : 'Sonraki Soru',
              style: const TextStyle(
                color: Color(0xFF0B132B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            if (!isLast) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0B132B), size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
