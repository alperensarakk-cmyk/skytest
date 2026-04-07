import 'package:flutter/material.dart';
import '../models/soru_model.dart';
import '../services/soru_yukleme_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scrollable_paragraf_card.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cCorrect  = Color(0xFF4CAF50);
const _cWrong    = Color(0xFFF44336);
const _cTactic   = Color(0xFF233056);
const _cGold     = Color(0xFFFFD60A);
const _cMuted    = Color(0xFFA1B5D8);
const _cOptionBg = Color(0xFF253354);
const _cRed      = Color(0xFFFF6B6B);

// ─────────────────────────────────────────────────────────────────────────────

class YanlislarimScreen extends StatefulWidget {
  const YanlislarimScreen({super.key});

  @override
  State<YanlislarimScreen> createState() => _YanlislarimScreenState();
}

class _YanlislarimScreenState extends State<YanlislarimScreen> {
  List<SoruModel>? _sorular;
  int              _index   = 0;
  String?          _secilen;
  bool get _answered => _secilen != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ids = await YanlisService.getYanlisIdsAsync();

    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _sorular = []);
      return;
    }

    final all = await SoruYuklemeService.tumSorulariYukle();

    final idSet   = ids.toSet();
    final matched = ids
        .map((id) {
          final found = all.where((s) => s.id == id);
          return found.isEmpty ? null : found.first;
        })
        .whereType<SoruModel>()
        .where((s) => idSet.contains(s.id))
        .toList();

    if (!mounted) return;
    setState(() {
      _sorular = matched;
      _index   = 0;
      _secilen = null;
    });
  }

  SoruModel get _soru  => _sorular![_index];
  int        get _total => _sorular!.length;

  // ── Şık seçimi ────────────────────────────────────────────────────────────
  void _selectOption(String k) {
    if (_answered) return;
    setState(() => _secilen = k);

    if (k == _soru.dogruCevap) {
      // Doğru yapıldı → SharedPreferences'tan kaldır
      YanlisService.removeYanlis(_soru.id);
    }
  }

  // ── Sonraki ───────────────────────────────────────────────────────────────
  void _next() {
    if (_sorular == null) return;
    final wasCorrect = _secilen == _soru.dogruCevap;

    if (wasCorrect) {
      // UI listesinden de kaldır
      final updated = List<SoruModel>.from(_sorular!)
        ..removeWhere((s) => s.id == _soru.id);

      if (updated.isEmpty) {
        setState(() => _sorular = []);
        return;
      }
      setState(() {
        _sorular = updated;
        _index   = _index.clamp(0, updated.length - 1);
        _secilen = null;
      });
    } else {
      // Yanlış → sonraki (son sorudaysa başa dön)
      setState(() {
        _index   = (_index + 1) % _total;
        _secilen = null;
      });
    }
  }

  // ── Renk yardımcıları ─────────────────────────────────────────────────────
  Color _borderColor(String k) {
    if (!_answered)                return Colors.transparent;
    if (k == _soru.dogruCevap)    return _cCorrect;
    if (k == _secilen)             return _cWrong;
    return Colors.transparent;
  }

  Color _bgColor(String k) {
    if (!_answered)                return _cOptionBg;
    if (k == _soru.dogruCevap)    return _cCorrect.withValues(alpha: 0.12);
    if (k == _secilen)             return _cWrong.withValues(alpha: 0.10);
    return _cOptionBg;
  }

  IconData? _trailingIcon(String k) {
    if (!_answered)                return null;
    if (k == _soru.dogruCevap)    return Icons.check_circle_rounded;
    if (k == _secilen)             return Icons.cancel_rounded;
    return null;
  }

  Color _trailingColor(String k) =>
      k == _soru.dogruCevap ? _cCorrect : _cWrong;

  // ── Tümünü temizle ────────────────────────────────────────────────────────
  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Listeyi Temizle',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_sorular?.length ?? 0} yanlış soru listeden silinecek. Bu işlem geri alınamaz.',
          style: const TextStyle(color: _cMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç', style: TextStyle(color: _cMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Temizle',
              style: TextStyle(color: _cRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await YanlisService.clearAll();
    if (!mounted) return;
    setState(() {
      _sorular = [];
      _index   = 0;
      _secilen = null;
    });
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEmpty   = _sorular != null && _sorular!.isEmpty;
    final isCorrect = _answered && _secilen == (_sorular?.isEmpty == false ? _soru.dogruCevap : '');
    final hasItems  = _sorular != null && _sorular!.isNotEmpty;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Yanlışlarım',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (hasItems)
            IconButton(
              tooltip: 'Listeyi Temizle',
              icon: const Icon(Icons.delete_sweep_rounded, color: _cRed),
              onPressed: _clearAll,
            ),
        ],
      ),

      // ── Sabit Alt Buton ──────────────────────────────────────────────────
      bottomNavigationBar: (!isEmpty && _sorular != null)
          ? _buildNextBar(isCorrect)
          : null,

      body: _buildBody(),
    );
  }

  Widget _buildNextBar(bool isCorrect) {
    if (_sorular == null || _sorular!.isEmpty) return const SizedBox.shrink();

    String label;
    if (!_answered) {
      label = 'Sonraki Soru';
    } else if (isCorrect) {
      label = 'Doğru! Devam →  ✓';
    } else {
      label = 'Yanlış — Sonraki →';
    }

    return AnimatedSlide(
      offset: _answered ? Offset.zero : const Offset(0, 1.2),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _answered ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: GestureDetector(
              onTap: _next,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isCorrect
                        ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                        : [const Color(0xFFFF6B6B), const Color(0xFFB71C1C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isCorrect ? _cCorrect : _cRed)
                          .withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_sorular == null) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    if (_sorular!.isEmpty) {
      return _EmptyState(onBack: () => Navigator.pop(context));
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_index + 1) / _total,
          backgroundColor: const Color(0xFF253354),
          valueColor: const AlwaysStoppedAnimation<Color>(_cRed),
          minHeight: 3,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sayaç rozeti
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D1515),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay_circle_filled_rounded,
                              color: _cRed, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            '$_total soru kaldı',
                            style: const TextStyle(color: _cRed, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text('${_index + 1} / $_total',
                        style: const TextStyle(color: _cMuted, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 14),

                if (_soru.paragraf.isNotEmpty &&
                    !_soru.paragrafSoruMetniyleOzdes) ...[
                  ScrollableParagrafCard(
                    key: ValueKey(_soru.id),
                    paragraf: _soru.paragraf,
                  ),
                  const SizedBox(height: 14),
                ],
                _SoruMetniVeyaYonlendirme(soru: _soru),
                const SizedBox(height: 14),

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
    );
  }
}

// ─── Boş Liste ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'Tebrikler!',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tüm yanlışlarını düzelttın.\nBu listenin boş kalması hedef! 💪',
              textAlign: TextAlign.center,
              style: TextStyle(color: _cMuted, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF48CAE4), Color(0xFF0096C7)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Ana Sayfaya Dön',
                  style: TextStyle(
                    color: Color(0xFF0B132B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Soru Kartı ───────────────────────────────────────────────────────────────

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
        color: const Color(0xFF1C2541),
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
                Container(
                  width: 32, height: 32,
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
              const Row(children: [
                Icon(Icons.check_circle_rounded, color: _cCorrect, size: 17),
                SizedBox(width: 7),
                Text('Doğru Cevap & Açıklama',
                    style: TextStyle(color: _cCorrect, fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(dogruMetin,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.45)),
              const SizedBox(height: 8),
              Text(soru.nedenDogru,
                  style: const TextStyle(color: _cMuted, fontSize: 13, height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.cancel_outlined, color: Color(0xFF8DA5C8), size: 16),
                SizedBox(width: 7),
                Text('Neden Yanlış?',
                    style: TextStyle(
                        color: Color(0xFF8DA5C8), fontWeight: FontWeight.w600, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Text(soru.yanlislar,
                  style: const TextStyle(color: _cMuted, fontSize: 13, height: 1.65)),
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                child: Text(soru.tip,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.65)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
