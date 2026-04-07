import 'dart:math';
import 'package:flutter/material.dart';
import '../models/kelime_model.dart';
import '../services/kelime_mcq_options.dart';
import '../services/kelime_istatistik_service.dart';
import '../services/kelime_service.dart';
import '../services/kelime_yanlis_service.dart';
import '../theme/app_theme.dart';

// ─── Renkler ──────────────────────────────────────────────────────────────────
const _cCorrect  = Color(0xFF4CAF50);
const _cWrong    = Color(0xFFF44336);
const _cMuted    = Color(0xFFA1B5D8);
const _cGold     = Color(0xFFFFD60A);
const _cOptionBg = Color(0xFF253354);
const _cTactic   = Color(0xFF233056);
const _cPurple   = Color(0xFF6C63FF);

// ─────────────────────────────────────────────────────────────────────────────

class KelimeYanlislarimScreen extends StatefulWidget {
  const KelimeYanlislarimScreen({super.key});

  @override
  State<KelimeYanlislarimScreen> createState() =>
      _KelimeYanlislarimScreenState();
}

class _KelimeYanlislarimScreenState extends State<KelimeYanlislarimScreen> {
  List<KelimeModel>? _yanlis;
  List<KelimeModel>? _tumKelimeler;
  int          _index    = 0;
  String?      _secilen;
  List<String> _secenekler = [];
  bool         _loading    = true;

  // Oturumda her kelime için doğru cevap sayısı (2 olunca silinir)
  final Map<int, int> _correctCount = {};

  bool        get _answered => _secilen != null;
  KelimeModel get _kelime   => _yanlis![_index];
  bool        get _dogruMu  => _secilen == _kelime.turkce;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tumKelimeler = await KelimeService.loadAll();
    final ids          = await KelimeYanlisService.getYanlisIdsAsync();
    final idSet        = ids.toSet();
    final yanlisList   = tumKelimeler
        .where((k) => idSet.contains(k.id))
        .toList()
      ..shuffle();

    if (!mounted) return;
    setState(() {
      _tumKelimeler = tumKelimeler;
      _yanlis       = yanlisList;
      _loading      = false;
    });
    if (yanlisList.isNotEmpty) _buildOptions();
  }

  void _buildOptions() {
    if (_yanlis == null || _yanlis!.isEmpty || _tumKelimeler == null) return;
    final rng = Random();
    setState(() {
      _secenekler = buildKelimeMcqTurkceOptions(
        _kelime,
        _tumKelimeler!,
        random: rng,
      );
    });
  }

  void _selectOption(String opt) {
    if (_answered) return;
    final dogruMu = opt == _kelime.turkce;
    if (dogruMu) {
      final newCount = (_correctCount[_kelime.id] ?? 0) + 1;
      _correctCount[_kelime.id] = newCount;
      // 2. doğruda SharedPreferences'tan da sil
      if (newCount >= 2) {
        KelimeYanlisService.removeYanlis(_kelime.id);
      }
    }
    KelimeIstatistikService.recordAnswer(
        modul: _kelime.modul, correct: dogruMu);
    setState(() => _secilen = opt);
  }

  void _next() {
    if (_secilen == null) return;
    final dogruMu = _secilen == _kelime.turkce;
    final count   = _correctCount[_kelime.id] ?? 0;

    if (dogruMu && count >= 2) {
      // 2 kez doğru → listeden çıkar
      final updated = List<KelimeModel>.from(_yanlis!)..removeAt(_index);
      if (updated.isEmpty) {
        setState(() { _yanlis = updated; _secilen = null; });
        return;
      }
      final newIndex = _index >= updated.length ? updated.length - 1 : _index;
      setState(() { _yanlis = updated; _index = newIndex; _secilen = null; });
    } else {
      // 1 kez doğru veya yanlış → kelimenin sonuna taşı
      final updated = List<KelimeModel>.from(_yanlis!);
      final moved   = updated.removeAt(_index);
      updated.add(moved);
      final newIndex = _index >= updated.length ? 0 : _index;
      setState(() { _yanlis = updated; _index = newIndex; _secilen = null; });
    }
    _buildOptions();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Listeyi Temizle',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tüm yanlış kelimeler listeden silinecek. Emin misin?',
          style: TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: _cMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Temizle',
                style: TextStyle(color: _cWrong, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await KelimeYanlisService.clearAll();
      if (!mounted) return;
      setState(() { _yanlis = []; _secilen = null; });
    }
  }

  // ── Renk yardımcıları ─────────────────────────────────────────────────────
  Color _borderColor(String opt) {
    if (!_answered)            return Colors.transparent;
    if (opt == _kelime.turkce) return _cCorrect;
    if (opt == _secilen)       return _cWrong;
    return Colors.transparent;
  }

  Color _bgColor(String opt) {
    if (!_answered)            return _cOptionBg;
    if (opt == _kelime.turkce) return _cCorrect.withValues(alpha: 0.12);
    if (opt == _secilen)       return _cWrong.withValues(alpha: 0.10);
    return _cOptionBg;
  }

  IconData? _trailingIcon(String opt) {
    if (!_answered)            return null;
    if (opt == _kelime.turkce) return Icons.check_circle_rounded;
    if (opt == _secilen)       return Icons.cancel_rounded;
    return null;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
        title: const Text(
          'Yanlış Kelimelerim',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_yanlis != null && _yanlis!.isNotEmpty)
            IconButton(
              tooltip: 'Listeyi Temizle',
              icon: const Icon(Icons.delete_sweep_rounded, color: _cMuted),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : (_yanlis == null || _yanlis!.isEmpty)
              ? _EmptyState()
              : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    final labels = ['A', 'B', 'C', 'D'];
    return Column(
      children: [
        LinearProgressIndicator(
          value: 0,
          backgroundColor: const Color(0xFF253354),
          valueColor: const AlwaysStoppedAnimation<Color>(_cPurple),
          minHeight: 3,
        ),
        Container(
          color: kBgCard,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.replay_circle_filled_rounded,
                  color: _cWrong, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_yanlis!.length} kelime tekrar bekliyor',
                style: const TextStyle(color: _cMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WordCard(kelime: _kelime),
                const SizedBox(height: 16),
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
    );
  }

  Widget? _buildBottomBar() {
    if (_loading || _yanlis == null || _yanlis!.isEmpty || !_answered) {
      return null;
    }
    final count = _correctCount[_kelime.id] ?? 0;

    final List<Color> gradColors;
    final IconData    barIcon;
    final String      barText;

    if (_dogruMu && count >= 2) {
      gradColors = [const Color(0xFF4CAF50), const Color(0xFF2E7D32)];
      barIcon    = Icons.check_circle_outline_rounded;
      barText    = 'Öğrenildi! Listeden Çıkarıldı';
    } else if (_dogruMu && count == 1) {
      gradColors = [const Color(0xFFFF8F00), const Color(0xFFE65100)];
      barIcon    = Icons.replay_rounded;
      barText    = 'Doğru! 1 kez daha doğru bil →';
    } else {
      gradColors = [const Color(0xFFE53935), const Color(0xFFB71C1C)];
      barIcon    = Icons.arrow_forward_rounded;
      barText    = 'Sonraki Kelime';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GestureDetector(
          onTap: _next,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(barIcon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  barText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Boş Durum ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _cCorrect.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded,
                  color: _cCorrect, size: 42),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tebrikler!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tüm yanlış kelimelerini düzelttin! 🎉\nHarika bir çalışma yaptın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _cMuted, fontSize: 14, height: 1.6),
            ),
          ],
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
        border: const Border(left: BorderSide(color: _cWrong, width: 3)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _cWrong.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(kelime.modul,
                style: const TextStyle(
                    color: _cWrong,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Text(
            kelime.ingilizce,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2),
          ),
          const SizedBox(height: 10),
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
        if (kelime.ornekCumle != null) ...[
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
                const Row(
                  children: [
                    Icon(Icons.format_quote_rounded,
                        color: _cCorrect, size: 17),
                    SizedBox(width: 7),
                    Text('Örnek Kullanım',
                        style: TextStyle(
                            color: _cCorrect,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(kelime.ornekCumle!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (kelime.ipucu != null)
          Container(
            decoration: BoxDecoration(
              color: _cTactic,
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: _cGold, width: 3)),
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
                  child: Text(kelime.ipucu!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.65)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
