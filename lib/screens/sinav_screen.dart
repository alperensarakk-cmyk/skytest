import 'dart:async';
import 'package:flutter/material.dart';
import '../models/soru_model.dart';
import '../services/daily_limit_service.dart';
import '../services/istatistik_service.dart';
import '../services/soru_secim_service.dart';
import '../services/soru_son_gorulen_service.dart';
import '../services/soru_yukleme_service.dart';
import '../services/settings_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';
import '../utils/sinav_puan_format.dart';
import '../widgets/scrollable_paragraf_card.dart';

// ─── Renk sabitleri ───────────────────────────────────────────────────────────
const _cAppBar      = Color(0xFF1C2541);
const _cCard        = Color(0xFF1C2541);
const _cSelected    = Color(0xFF48CAE4);
const _cUnselected  = Color(0xFF253354);
const _cTrackDone   = Color(0xFF48CAE4);
const _cTrackEmpty  = Color(0xFF253354);
const _cFinish      = Color(0xFFEF4444);
const _cBtnPrimary  = Color(0xFF48CAE4);
const _cBtnSecond   = Color(0xFF1C2541);

class SinavScreen extends StatefulWidget {
  const SinavScreen({super.key});

  @override
  State<SinavScreen> createState() => _SinavScreenState();
}

class _SinavScreenState extends State<SinavScreen> {
  List<SoruModel>   _sorular     = [];
  bool              _isLoading   = true;
  final Map<int, String> _cevaplar = {};
  int   _currentIndex = 0;
  int   _remainingSec = 30 * 60;
  bool  _examAutoNext = true;          // ayardan okunur
  Timer? _timer;
  Timer? _autoSonrakiTimer;
  final ScrollController _trackCtrl = ScrollController();
  bool _sessionIdsRecorded = false;

  @override
  void initState() {
    super.initState();
    _loadAndShuffle();
  }

  // ── JSON yükle + ayarları oku ─────────────────────────────────────────────
  Future<void> _loadAndShuffle() async {
    // Ayarları paralel oku
    final sorularFuture  = SoruYuklemeService.tumSorulariYukle();
    final qCountFuture   = SettingsService.getExamQuestionCount();
    final durationFuture = SettingsService.getExamDurationMin();
    final autoNextFuture = SettingsService.getExamAutoNext();

    final list      = await sorularFuture;
    final qCount    = await qCountFuture;
    final durMin    = await durationFuture;
    final autoNext  = await autoNextFuture;
    final avoid     = await SoruSonGorulenService.getAvoidSet();

    final selected = await SoruSecimService.secSinavSablonu(
      list,
      qCount,
      useRandomization: true,
      avoidRecentIds: avoid,
    );

    if (!mounted) return;

    if (selected.isEmpty) {
      setState(() {
        _sorular   = [];
        _isLoading = false;
      });
      return;
    }

    // Ücretsiz kullanıcı: günlük sınav kotası sınav başlarken düşer (geri ile çıkışta bypass olmasın).
    // Premium: DailyLimitService içinde no-op.
    await DailyLimitService.recordExamCompleted(selected.length);

    if (!mounted) return;
    setState(() {
      _sorular      = selected;
      _remainingSec = durMin * 60;
      _examAutoNext = autoNext;
      _isLoading    = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    if (!_sessionIdsRecorded && _sorular.isNotEmpty) {
      SoruSonGorulenService.recordSessionIds(
        _sorular.take(_currentIndex + 1).map((s) => s.id),
      );
    }
    _timer?.cancel();
    _autoSonrakiTimer?.cancel();
    _trackCtrl.dispose();
    super.dispose();
  }

  // ── Kronometre ────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSec <= 0) {
        _timer?.cancel();
        _showResultDialog(timeUp: true);
        return;
      }
      setState(() => _remainingSec--);
    });
  }

  String get _timerLabel {
    final m = _remainingSec ~/ 60;
    final s = _remainingSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onExamPopInvoked(bool didPop) {
    if (didPop) return;
    if (_isLoading) {
      Navigator.of(context).pop();
      return;
    }
    if (_sorular.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cAppBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sınavdan çık',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'İlerlemen kaybolur. Çıkmak istiyor musun?',
          style: TextStyle(color: Color(0xFFA1B5D8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Color(0xFF48CAE4)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cFinish),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çık'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) Navigator.of(context).pop();
    });
  }

  // ── Navigasyon ────────────────────────────────────────────────────────────
  void _goTo(int index) {
    setState(() => _currentIndex = index);
    _scrollTrackTo(index);
  }

  void _scrollTrackTo(int index) {
    final offset = index * 44.0;
    _trackCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    if (_currentIndex < _sorular.length - 1) _goTo(_currentIndex + 1);
  }

  void _prev() {
    if (_currentIndex > 0) _goTo(_currentIndex - 1);
  }

  // ── Şık seç ───────────────────────────────────────────────────────────────
  void _selectOption(String sik) {
    _autoSonrakiTimer?.cancel();
    setState(() => _cevaplar[_currentIndex] = sik);

    // Otomatik geçiş: önce seçim çerçevesi + tik bir frame’de çizilsin, animasyon bitsin.
    if (_examAutoNext && _currentIndex < _sorular.length - 1) {
      final i = _currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoSonrakiTimer = Timer(const Duration(milliseconds: 380), () {
          if (!mounted) return;
          if (_currentIndex != i) return;
          _next();
        });
      });
    }
  }

  // ── Sınavı bitir ──────────────────────────────────────────────────────────
  void _confirmFinish() {
    final answered = _cevaplar.length;
    final unanswered = _sorular.length - answered;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cAppBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sınavı Bitir',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          unanswered > 0
              ? '$unanswered soru boş bırakıldı.\nYine de bitirmek istiyor musun?'
              : 'Tüm $answered soruyu cevapladın.\nSınavı teslim et?',
          style: const TextStyle(color: Color(0xFFA1B5D8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Devam Et',
                style: TextStyle(color: Color(0xFF48CAE4))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cFinish),
            onPressed: () {
              Navigator.pop(context);
              _showResultDialog(timeUp: false);
            },
            child: const Text('Teslim Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResultDialog({required bool timeUp}) async {
    _timer?.cancel();

    // ── Doğru / yanlış hesapla, kategorileri topla ───────────────────────
    int correct = 0;
    final yanlisIds        = <int>[];
    final yanlisKategoriler = <String, int>{}; // kategori → yanlış sayısı

    for (int i = 0; i < _sorular.length; i++) {
      final secilen = _cevaplar[i];
      final soru    = _sorular[i];
      if (secilen == soru.dogruCevap) {
        correct++;
        await YanlisService.removeYanlis(soru.id);
      } else if (secilen != null) {
        yanlisIds.add(soru.id);
        final kat = soru.kategori.replaceAll('_', ' ');
        yanlisKategoriler[kat] = (yanlisKategoriler[kat] ?? 0) + 1;
      }
    }
    await YanlisService.addMultiple(yanlisIds);

    await SoruSonGorulenService.recordSessionIds(_sorular.map((s) => s.id));
    _sessionIdsRecorded = true;

    final total      = _sorular.length;
    final answered   = _cevaplar.length;
    final wrongCount = answered - correct;
    final puanSoru   = SinavPuanFormat.soruBasinaPuan(total);
    final not100     = SinavPuanFormat.alinanNot(correct, total);

    // ── Sınav istatistiğini kaydet ────────────────────────────────────────
    await IstatistikService.saveSinavSonucu(
      SinavSonucu(
        tarih:             DateTime.now(),
        dogru:             correct,
        yanlis:            wrongCount,
        bos:               total - answered,
        toplam:            total,
        yuzde:             not100,
        yanlisKategoriler: yanlisKategoriler,
      ),
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cAppBar,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          timeUp ? 'Süre Doldu! ⏰' : 'Sonuçların 🎯',
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow('Toplam Soru', '$total'),
            _resultRow('Cevaplanan',  '$answered'),
            _resultRow('Boş',         '${total - answered}'),
            const Divider(color: Color(0xFF253354), height: 24),
            _resultRow('Doğru',  '$correct',    color: const Color(0xFF48CAE4)),
            _resultRow('Yanlış', '$wrongCount', color: _cFinish),
            _resultRow(
              'Soru başına puan',
              '${SinavPuanFormat.formatPuan(puanSoru)} puan',
            ),
            const SizedBox(height: 10),
            Text(
              '${SinavPuanFormat.formatPuan(not100)} / 100',
              style: const TextStyle(
                  color: Color(0xFFFFD60A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              'Toplam not',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            // ── Yanlışlarım: tıklanınca Yanlışlarım ekranına gider ─────────
            if (yanlisIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFF3D1515),
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, '/yanlislarim');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.replay_circle_filled_rounded,
                            color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$wrongCount yanlış sorun "Yanlışlarım" listene eklendi.',
                                style: const TextStyle(
                                  color: Color(0xFFFFB4B4),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Şimdi tekrar çöz',
                                style: TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFFF6B6B), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _cBtnPrimary, foregroundColor: Colors.black87),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(ctx);
            },
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF8DA5C8), fontSize: 14)),
            Text(value,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onExamPopInvoked(didPop),
      child: _buildExamScaffold(context),
    );
  }

  Widget _buildExamScaffold(BuildContext context) {
    // Sorular yüklenene kadar loading ekranı göster
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBgDark,
        appBar: AppBar(
          backgroundColor: _cAppBar,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text('Sınav Modu',
              style: TextStyle(color: Colors.white, fontSize: 18)),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _cSelected),
              SizedBox(height: 20),
              Text('Sorular hazırlanıyor...',
                  style: TextStyle(color: Color(0xFF8DA5C8), fontSize: 15)),
            ],
          ),
        ),
      );
    }

    if (_sorular.isEmpty) {
      return Scaffold(
        backgroundColor: kBgDark,
        appBar: AppBar(
          backgroundColor: _cAppBar,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Sınav Modu',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.quiz_outlined,
                    color: Color(0xFF8DA5C8), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Sınav için yeterli soru oluşturulamadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Veri dosyası veya soru sayısı ayarını kontrol edip tekrar dene.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8DA5C8),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _cBtnPrimary,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Geri dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final soru = _sorular[_currentIndex];
    final secili = _cevaplar[_currentIndex];

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTracker(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuestionCard(soru),
                  const SizedBox(height: 16),
                  ...['a', 'b', 'c', 'd'].map(
                    (k) => _buildOption(
                      label: k.toUpperCase(),
                      text: soru.secenekler[k]!,
                      isSelected: secili == k,
                      onTap: () => _selectOption(k),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: _cAppBar,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Sınavı Bitir butonu
              _FinishButton(onTap: _confirmFinish),
              const Spacer(),
              // Kronometre
              _TimerWidget(label: _timerLabel, isLow: _remainingSec < 300),
            ],
          ),
        ),
      );

  // ── Soru takip barı ───────────────────────────────────────────────────────
  Widget _buildTracker() => Container(
        color: _cAppBar,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 38,
          child: ListView.builder(
          controller: _trackCtrl,
          scrollDirection: Axis.horizontal,
          itemCount: _sorular.length,
          itemExtent: 44,
          itemBuilder: (_, i) {
            final isCurrent  = i == _currentIndex;
            final isAnswered = _cevaplar.containsKey(i);
            return GestureDetector(
              onTap: () => _goTo(i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isAnswered ? _cTrackDone : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent
                        ? Colors.white
                        : isAnswered
                            ? _cTrackDone
                            : _cTrackEmpty,
                    width: isCurrent ? 2.0 : 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: isAnswered ? Colors.black87 : const Color(0xFF8DA5C8),
                      fontSize: 11,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ),
      );

  // ── Soru kartı ────────────────────────────────────────────────────────────
  Widget _buildQuestionCard(SoruModel soru) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cSelected.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Soru ${_currentIndex + 1} / ${_sorular.length}',
                    style: const TextStyle(
                        color: _cSelected, fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (soru.paragraf.isNotEmpty &&
                !soru.paragrafSoruMetniyleOzdes) ...[
              ScrollableParagrafCard(
                key: ValueKey(soru.id),
                paragraf: soru.paragraf,
                accentColor: _cSelected,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              soru.soruMetniParagrafinClozeVeyaBenzeri
                  ? SoruModel.clozeYonlendirmeMetni
                  : soru.soruMetni,
              style: TextStyle(
                color: soru.soruMetniParagrafinClozeVeyaBenzeri
                    ? const Color(0xFFA1B5D8)
                    : Colors.white,
                fontSize:
                    soru.soruMetniParagrafinClozeVeyaBenzeri ? 14 : 16,
                height: 1.65,
                fontWeight: soru.soruMetniParagrafinClozeVeyaBenzeri
                    ? FontWeight.w400
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  // ── Şık ───────────────────────────────────────────────────────────────────
  Widget _buildOption({
    required String label,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _cSelected.withValues(alpha: 0.08)
                  : _cUnselected,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _cSelected : Colors.transparent,
                width: 1.8,
              ),
            ),
            child: Row(
              children: [
                // Şık harfi
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? _cSelected
                        : const Color(0xFF1C2541),
                    border: Border.all(
                      color: isSelected
                          ? _cSelected
                          : const Color(0xFF4A6080),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : const Color(0xFF8DA5C8),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Şık metni
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFA1B5D8),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                      color: _cSelected, size: 18),
              ],
            ),
          ),
        ),
      );

  // ── Alt navigasyon barı ───────────────────────────────────────────────────
  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: kBgDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavBtn(
                label: '← Önceki',
                filled: false,
                enabled: _currentIndex > 0,
                onTap: _prev,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavBtn(
                label: _currentIndex == _sorular.length - 1
                    ? 'Bitir ✓'
                    : 'Sonraki →',
                filled: true,
                enabled: true,
                onTap: _currentIndex == _sorular.length - 1
                    ? _confirmFinish
                    : _next,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt bileşenler
// ─────────────────────────────────────────────────────────────────────────────

class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _cFinish.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cFinish.withValues(alpha: 0.50)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag_rounded, color: _cFinish, size: 16),
              SizedBox(width: 6),
              Text('Sınavı Bitir',
                  style: TextStyle(
                      color: _cFinish,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _TimerWidget extends StatelessWidget {
  const _TimerWidget({required this.label, required this.isLow});
  final String label;
  final bool isLow;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: (isLow ? _cFinish : _cSelected).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: (isLow ? _cFinish : _cSelected).withValues(alpha: 0.40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded,
                color: isLow ? _cFinish : _cSelected, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isLow ? _cFinish : _cSelected,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          decoration: BoxDecoration(
            color: !enabled
                ? _cUnselected.withValues(alpha: 0.40)
                : filled
                    ? _cBtnPrimary
                    : _cBtnSecond,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !enabled
                  ? Colors.transparent
                  : filled
                      ? _cBtnPrimary
                      : _cSelected.withValues(alpha: 0.45),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: !enabled
                    ? const Color(0xFF4A6080)
                    : filled
                        ? Colors.black87
                        : _cSelected,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}
