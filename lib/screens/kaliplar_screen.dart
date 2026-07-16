import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/kalip_model.dart';
import '../services/app_review_service.dart';
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

class _KaliplarScreenState extends State<KaliplarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final Future<List<KalipModel>> _allFuture;
  late final Future<List<KalipModel>> _sikFuture;
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabCtrl.addListener(_guardPriorityTab);
    PremiumService.isPremiumNotifier.addListener(_onPremiumChanged);
    _allFuture = _loadAll();
    _sikFuture = _loadSik();
    _syncPremium();
  }

  Future<void> _syncPremium() async {
    final p = await PremiumService.isPremiumUser();
    if (mounted) setState(() => _premium = p);
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    setState(() => _premium = PremiumService.isPremiumNotifier.value);
  }

  void _guardPriorityTab() {
    if (!_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 1 && !_premium) {
      _tabCtrl.index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPremiumForPriority();
      });
    }
  }

  Future<void> _openPriorityTab() async {
    if (await PremiumService.isPremiumUser()) {
      if (mounted) _tabCtrl.animateTo(1);
    } else if (mounted) {
      _openPremiumForPriority();
    }
  }

  void _openPremiumForPriority() {
    Navigator.pushNamed(context, '/premium');
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_guardPriorityTab);
    PremiumService.isPremiumNotifier.removeListener(_onPremiumChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<List<KalipModel>> _loadAll() async {
    final raw = await rootBundle.loadString('assets/kaliplar.json');
    final list = jsonDecode(raw) as List<dynamic>;
    final out = list
        .map((e) => KalipModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return DailyLimitService.kaliplarDeckForToday(out);
  }

  Future<List<KalipModel>> _loadSik() async {
    final raw = await rootBundle.loadString('assets/kaliplar_sik.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final sik = (data['sik_kaliplar'] as List<dynamic>)
        .map((e) => KalipModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final disi = (data['json_disi_kaliplar'] as List<dynamic>)
        .map((e) => KalipModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return [...sik, ...disi];
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
        title: buildAeroTestAppBarTitle('Altın Kalıplar', subtitleFontSize: 18),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFFFD60A), size: 20),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF48CAE4),
          indicatorWeight: 3,
          labelColor: const Color(0xFF48CAE4),
          unselectedLabelColor: const Color(0xFF6B85A8),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          tabs: [
            const Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apps_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Tüm Kalıplar'),
                ],
              ),
            ),
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFD60A)),
                  const SizedBox(width: 6),
                  const Text('Öncelikli Kalıplar'),
                  if (!_premium) ...[
                    const SizedBox(width: 5),
                    Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: const Color(0xFFFFD60A).withValues(alpha: 0.85),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: _premium
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        children: [
          _KalipTabBody(
            future: _allFuture,
            emptyMessage: 'Kalıp yüklenemedi.',
            header: _AllTabHint(
              onGoPriority: _openPriorityTab,
              isPremium: _premium,
            ),
          ),
          _premium
              ? _KalipTabBody(
                  future: _sikFuture,
                  emptyMessage: 'Öncelikli kalıp bulunamadı.',
                  header: const _PriorityHeader(),
                )
              : const _PriorityPremiumGate(),
        ],
      ),
    );
  }
}

class _PriorityHeader extends StatelessWidget {
  const _PriorityHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD60A).withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_rounded, color: Color(0xFFFFD60A), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tüm altın kalıplar önemlidir. Bu listede ise soru '
              'bankasında en sık geçen ve öncelikle ezberlemen '
              'gereken kalıplar var. Karttaki sayı, kaç soruda '
              'geçtiğini gösterir.',
              style: TextStyle(
                color: Color(0xFF8DA5C8),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTabHint extends StatelessWidget {
  const _AllTabHint({
    required this.onGoPriority,
    required this.isPremium,
  });

  final VoidCallback onGoPriority;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onGoPriority,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF233056),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD60A).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD60A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPremium
                    ? 'Sınavına çalışmaya geç kaldıysan Öncelikli Kalıplar '
                        'sekmesine geç.'
                    : 'Öncelikli Kalıplar (sınavda en sık geçenler) Premium\'da.',
                style: const TextStyle(
                  color: Color(0xFFA1B5D8),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              isPremium ? Icons.chevron_right_rounded : Icons.lock_rounded,
              color: const Color(0xFFFFD60A),
              size: isPremium ? 22 : 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityPremiumGate extends StatelessWidget {
  const _PriorityPremiumGate();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD60A), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Öncelikli Kalıplar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Soru bankasında en sık geçen kalıplar Premium üyeler için.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8DA5C8),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: const Color(0xFF0B132B),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => Navigator.pushNamed(context, '/premium'),
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: const Text(
                'Premium\'a Geç',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KalipTabBody extends StatelessWidget {
  const _KalipTabBody({
    required this.future,
    required this.emptyMessage,
    this.header,
  });

  final Future<List<KalipModel>> future;
  final String emptyMessage;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KalipModel>>(
      future: future,
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
        if (list.isEmpty) {
          return Center(
            child: Text(emptyMessage,
                style: const TextStyle(color: Color(0xFF8DA5C8))),
          );
        }
        return Column(
          children: [
            if (header != null) header!,
            Expanded(child: _KaliplarDeck(list: list)),
          ],
        );
      },
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
  bool _completionReviewQueued = false;

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
    if (!await PremiumService.isPremiumUser()) {
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

    final total = widget.list.length;
    final triggerIndex = AppReviewService.milestoneTriggerAt(total) - 1;
    if (total > 0 && i >= triggerIndex && !_completionReviewQueued) {
      _completionReviewQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await AppReviewService.tryShowAfterCompletion(context);
      });
    }
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
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => FlashCard(
              key: ValueKey('${list[i].id}-$i'),
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
          onNext: _currentIndex < total - 1 ? _tryNext : null,
        ),
      ],
    );
  }
}

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
