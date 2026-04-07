import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/kalip_model.dart';
import '../services/daily_limit_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flash_card.dart';
import '../widgets/limit_exceeded_dialog.dart';

class KaliplarScreen extends StatefulWidget {
  const KaliplarScreen({super.key});

  @override
  State<KaliplarScreen> createState() => _KaliplarScreenState();
}

class _KaliplarScreenState extends State<KaliplarScreen> {
  late final Future<List<KalipModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<KalipModel>> _load() async {
    final raw = await rootBundle.loadString('assets/kaliplar.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final out = list
        .map((e) => KalipModel.fromJson(e as Map<String, dynamic>))
        .toList();
    out.shuffle(Random());
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF48CAE4), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Altın Kalıplar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFFFD60A), size: 20),
          ),
        ],
      ),
      body: FutureBuilder<List<KalipModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF48CAE4)),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Text('Hata: ${snap.error}',
                  style: const TextStyle(color: Color(0xFF8DA5C8))),
            );
          }

          final list = snap.data!;
          return _KaliplarDeck(list: list);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _KaliplarDeck extends StatefulWidget {
  const _KaliplarDeck({required this.list});
  final List<KalipModel> list;

  @override
  State<_KaliplarDeck> createState() => _KaliplarDeckState();
}

class _KaliplarDeckState extends State<_KaliplarDeck> {
  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordFirstCard());
  }

  Future<void> _recordFirstCard() async {
    if (!mounted) return;
    await DailyLimitService.ensureDay();
    if (await PremiumService.isPremiumUser()) return;
    await DailyLimitService.recordKaliplarPageIndex(0);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPageChanged(int i) async {
    if (!mounted) return;
    setState(() => _currentIndex = i);
    await DailyLimitService.ensureDay();
    if (await PremiumService.isPremiumUser()) return;

    final maxIx = await DailyLimitService.kaliplarMaxAllowedIndex();
    if (i > maxIx) {
      if (_pageCtrl.hasClients) {
        await _pageCtrl.animateToPage(
          maxIx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
      if (!mounted) return;
      setState(() => _currentIndex = maxIx);
      await showDailyLimitExceededDialog(context);
      return;
    }
    await DailyLimitService.recordKaliplarPageIndex(i);
  }

  Future<void> _tryNext() async {
    final total = widget.list.length;
    if (_currentIndex >= total - 1) return;
    await DailyLimitService.ensureDay();
    if (!await PremiumService.isPremiumUser()) {
      final maxIx = await DailyLimitService.kaliplarMaxAllowedIndex();
      if (_currentIndex >= maxIx) {
        if (mounted) await showDailyLimitExceededDialog(context);
        return;
      }
    }
    if (_pageCtrl.hasClients) {
      await _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final total = list.length;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) {
              _onPageChanged(i);
            },
            itemBuilder: (_, i) => FlashCard(
              key: ValueKey(i),
              kalip: list[i],
            ),
          ),
        ),
        _BottomNav(
          onPrev: _currentIndex > 0
              ? () {
                  _pageCtrl.previousPage(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeInOut,
                  );
                }
              : null,
          onNext: _currentIndex < total - 1
              ? () {
                  _tryNext();
                }
              : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.onPrev,
    required this.onNext,
  });

  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _iconBtn(Icons.arrow_back_ios_rounded, onPrev),
          _iconBtn(Icons.arrow_forward_ios_rounded, onNext),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? cb) {
    final active = cb != null;
    return GestureDetector(
      onTap: cb,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? const Color(0xFF48CAE4).withValues(alpha: 0.35)
                : const Color(0xFF253354),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: active
              ? const Color(0xFF48CAE4)
              : const Color(0xFF48CAE4).withValues(alpha: 0.20),
        ),
      ),
    );
  }
}
