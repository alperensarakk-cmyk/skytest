import 'package:flutter/material.dart';

import '../services/app_review_service.dart';
import '../theme/app_theme.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cGold = Color(0xFFFFD60A);

/// Mağaza puanı / geri bildirim bottom sheet.
Future<void> showAppReviewSheet(
  BuildContext context, {
  bool fromSettings = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: fromSettings,
    enableDrag: fromSettings,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AppReviewSheetBody(fromSettings: fromSettings),
  );
}

class _AppReviewSheetBody extends StatefulWidget {
  const _AppReviewSheetBody({required this.fromSettings});
  final bool fromSettings;

  @override
  State<_AppReviewSheetBody> createState() => _AppReviewSheetBodyState();
}

class _AppReviewSheetBodyState extends State<_AppReviewSheetBody> {
  int _stars = 0;
  bool _busy = false;
  bool _resolved = false;

  Future<void> _close({bool postponed = false}) async {
    if (!widget.fromSettings && !_resolved && postponed) {
      await AppReviewService.markPostponed();
    }
    _resolved = true;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onLater() async {
    await _close(postponed: !widget.fromSettings);
  }

  Future<void> _onDecline() async {
    await _close(postponed: !widget.fromSettings);
  }

  Future<void> _onSubmit() async {
    if (_stars < 1 || _busy) return;
    setState(() => _busy = true);
    try {
      _resolved = true;
      if (_stars >= 4) {
        await AppReviewService.markRated();
        await AppReviewService.requestInAppReviewThenStore();
      } else {
        await AppReviewService.markRated();
        await AppReviewService.openFeedbackEmail(stars: _stars);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final body = _buildBody(bottom);
    if (widget.fromSettings) return body;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_resolved) {
          AppReviewService.markPostponed();
          _resolved = true;
        }
      },
      child: body,
    );
  }

  Widget _buildBody(double bottom) {
    final primaryLabel = _stars >= 4
        ? 'Mağazada değerlendir'
        : (_stars >= 1 ? 'Geri bildirim gönder' : 'Puan seç');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kBgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccent.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(Icons.star_rounded, color: _cGold, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Bir dakikanı ayırır mısın?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mağazada kısa bir yorum ve puan, AeroTest\'in daha çok '
                'kullanıcıya ulaşmasına yardım eder.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _cMuted, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  final filled = star <= _stars;
                  return IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _stars = star),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? _cGold : _cMuted,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_stars >= 1 && !_busy) ? _onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    disabledBackgroundColor: const Color(0xFF253354),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          primaryLabel,
                          style: const TextStyle(
                            color: Color(0xFF0B132B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : _onLater,
                      child: const Text(
                        'Sonra',
                        style: TextStyle(color: _cMuted),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _busy ? null : _onDecline,
                      child: const Text(
                        'Hayır, teşekkürler',
                        style: TextStyle(color: _cMuted, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
