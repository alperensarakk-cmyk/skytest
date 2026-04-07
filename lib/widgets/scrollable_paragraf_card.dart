import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _paragrafMetinStili = TextStyle(
  color: Color(0xFFE8EEF8),
  fontSize: 15,
  height: 1.62,
);

/// Paragraf sorularında okuma metni. Metin kısaysa düz kart; çok uzunsa sabit
/// yükseklik + iç kaydırma.
class ScrollableParagrafCard extends StatelessWidget {
  const ScrollableParagrafCard({
    super.key,
    required this.paragraf,
    this.accentColor,
  });

  final String paragraf;
  final Color? accentColor;

  /// Bu yüksekliği aşan metin kaydırmalı kutuda gösterilir (mantıksal piksel).
  double _maxKompaktYukseklik(double screenH) =>
      (screenH * 0.175).clamp(104.0, 168.0);

  @override
  Widget build(BuildContext context) {
    final p = paragraf.trim();
    if (p.isEmpty) return const SizedBox.shrink();

    final accent = accentColor ?? kAccent;
    final screenH = MediaQuery.sizeOf(context).height;
    final scaler = MediaQuery.textScalerOf(context);
    final maxCompact = _maxKompaktYukseklik(screenH);

    return LayoutBuilder(
      builder: (context, constraints) {
        final icGenislik =
            (constraints.maxWidth - 48).clamp(40.0, double.infinity);

        final tp = TextPainter(
          text: TextSpan(text: p, style: _paragrafMetinStili),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: icGenislik);

        final uzun = tp.height > maxCompact;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2744),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.38)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        uzun
                            ? 'Okuma metni — aşağı kaydırarak okuyun'
                            : 'Okuma metni',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: uzun
                    ? _KaydirmaBolgesi(
                        metin: p,
                        yukseklik:
                            (screenH * 0.36).clamp(180.0, 340.0),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColoredBox(
                          color: kBgCard.withValues(alpha: 0.92),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Text(
                              p,
                              style: _paragrafMetinStili,
                              textScaler: scaler,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KaydirmaBolgesi extends StatefulWidget {
  const _KaydirmaBolgesi({
    required this.metin,
    required this.yukseklik,
  });

  final String metin;
  final double yukseklik;

  @override
  State<_KaydirmaBolgesi> createState() => _KaydirmaBolgesiState();
}

class _KaydirmaBolgesiState extends State<_KaydirmaBolgesi> {
  late final ScrollController _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.yukseklik,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: kBgCard.withValues(alpha: 0.92),
          child: Scrollbar(
            controller: _ctrl,
            thickness: 4,
            radius: const Radius.circular(3),
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _ctrl,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Text(
                widget.metin,
                style: _paragrafMetinStili,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
