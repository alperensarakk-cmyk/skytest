import 'package:flutter/material.dart';
import '../services/sinav_kelime_lookup_service.dart';

/// Sözlükte karşılığı olan kelimelere tıklanınca üstte mini Türkçe baloncuk.
class TappableVocabText extends StatefulWidget {
  const TappableVocabText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.accentColor,
    this.minWordLength = 3,
    this.enabled = true,
  });

  final String text;
  final TextStyle baseStyle;
  final Color? accentColor;
  final int minWordLength;
  final bool enabled;

  @override
  State<TappableVocabText> createState() => _TappableVocabTextState();
}

class _TappableVocabTextState extends State<TappableVocabText> {
  OverlayEntry? _bubbleEntry;

  @override
  void dispose() {
    _removeBubble();
    super.dispose();
  }

  @override
  void didUpdateWidget(TappableVocabText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.enabled != widget.enabled) {
      _removeBubble();
    }
  }

  void _removeBubble() {
    _bubbleEntry?.remove();
    _bubbleEntry = null;
  }

  void _onWordTap(BuildContext wordContext, String turkce) {
    _removeBubble();

    final box = wordContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final accent = widget.accentColor ?? const Color(0xFF48CAE4);
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final short = SinavKelimeLookupService.shortTurkce(turkce);

    _bubbleEntry = OverlayEntry(
      builder: (ctx) {
        const maxW = 220.0;
        final centerX = offset.dx + size.width / 2;
        final left = (centerX - maxW / 2).clamp(12.0, screenW - maxW - 12.0);
        final top = (offset.dy - 44).clamp(
          media.padding.top + 4,
          offset.dy - 4,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _removeBubble,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: maxW,
              child: _MiniBubble(text: short, accentColor: accent),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_bubbleEntry!);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        !SinavKelimeLookupService.isReady ||
        widget.text.isEmpty) {
      return Text(widget.text, style: widget.baseStyle);
    }

    final parts = SinavKelimeLookupService.tokenizeForTap(widget.text);
    final spans = <InlineSpan>[];

    for (final part in parts) {
      if (!part.isTappable) {
        spans.add(TextSpan(text: part.text, style: widget.baseStyle));
        continue;
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Builder(
            builder: (ctx) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onWordTap(ctx, part.turkce!),
              child: Text(part.text, style: widget.baseStyle),
            ),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.baseStyle,
    );
  }
}

class _MiniBubble extends StatelessWidget {
  const _MiniBubble({
    required this.text,
    required this.accentColor,
  });

  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2744),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE8EEF8),
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(10, 5),
            painter: _BubbleTailPainter(color: const Color(0xFF1A2744)),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
