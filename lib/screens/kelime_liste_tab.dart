import 'package:flutter/material.dart';

import '../models/kelime_model.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cPurple = Color(0xFF6C63FF);

/// Kelime sözlüğü — ücretsiz ilk 10, Premium tüm liste.
class KelimeListeTab extends StatefulWidget {
  const KelimeListeTab({super.key, required this.tumKelimeler});

  final List<KelimeModel> tumKelimeler;

  @override
  State<KelimeListeTab> createState() => _KelimeListeTabState();
}

class _KelimeListeTabState extends State<KelimeListeTab> {
  bool _loading = true;
  bool _premium = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    PremiumService.isPremiumNotifier.addListener(_onPremiumChanged);
    _load();
  }

  @override
  void dispose() {
    PremiumService.isPremiumNotifier.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final premium = await PremiumService.isPremiumUser();
    if (!mounted) return;
    setState(() {
      _premium = premium;
      _loading = false;
    });
  }

  List<KelimeModel> get _allSorted {
    final out = List<KelimeModel>.from(widget.tumKelimeler)
      ..sort((a, b) => a.ingilizce.toLowerCase().compareTo(
            b.ingilizce.toLowerCase(),
          ));
    return out;
  }

  List<KelimeModel> get _filtered {
    final q = _query.trim().toLowerCase();
    final available =
        _premium ? _allSorted : _allSorted.take(10).toList();
    if (q.isEmpty) return available;
    return available.where((k) {
      return k.ingilizce.toLowerCase().contains(q) ||
          k.turkce.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    final shown = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Kelime ara (EN / TR)',
              hintStyle: TextStyle(color: _cMuted.withValues(alpha: 0.75)),
              prefixIcon: const Icon(Icons.search_rounded, color: _cMuted, size: 22),
              filled: true,
              fillColor: kBgCard,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _cPurple.withValues(alpha: 0.55)),
              ),
            ),
          ),
        ),
        if (!_premium)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Text(
              'Ücretsiz planda sözlüğün ilk 10 kelimesi gösterilir.',
              style: TextStyle(
                color: _cMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: shown.length + (_premium ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == shown.length) {
                return const _SozlukPremiumCard();
              }
              return KelimeListTile(kelime: shown[i]);
            },
          ),
        ),
      ],
    );
  }
}

class _SozlukPremiumCard extends StatelessWidget {
  const _SozlukPremiumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFFFD60A),
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tüm sözlüğün kilidini aç',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tüm havacılık kelimelerine ve sınırsız aramaya erişmek için Premium’a geç.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8DA5C8),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: const Color(0xFF0B132B),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
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
    );
  }
}

class KelimeListTile extends StatelessWidget {
  const KelimeListTile({super.key, required this.kelime});

  final KelimeModel kelime;

  @override
  Widget build(BuildContext context) {
    final hasExtra = (kelime.ornekCumle?.trim().isNotEmpty == true) ||
        (kelime.ipucu?.trim().isNotEmpty == true);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Text(
            kelime.ingilizce,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 10,
          child: Text(
            kelime.turkce,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _cMuted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    if (!hasExtra) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: row,
      );
    }

    return Material(
      color: kBgCard,
      borderRadius: BorderRadius.circular(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: row,
          children: [
            if (kelime.ornekCumle?.trim().isNotEmpty == true) ...[
              const Text(
                'Örnek',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kelime.ornekCumle!,
                style: const TextStyle(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (kelime.ipucu?.trim().isNotEmpty == true) ...[
              const Text(
                'İpucu',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kelime.ipucu!,
                style: const TextStyle(
                  color: _cMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
