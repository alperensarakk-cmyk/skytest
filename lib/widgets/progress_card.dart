import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Günlük hedef kartı — dairesel ilerleme halkası + günlük soru hedefi.
/// İş mantığı içermez; yalnızca verilen [solvedToday]/[totalToday] değerlerini
/// görselleştirir ve isteğe bağlı [onTap] ile yönlendirir.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    this.solvedToday = 0,
    this.totalToday = 10,
    this.onTap,
  });

  final int solvedToday;
  final int totalToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double progress = (solvedToday == 0 || totalToday == 0)
        ? 0.0
        : (solvedToday / totalToday).clamp(0.0, 1.0);
    final int percent = (progress * 100).round();

    final String message;
    if (solvedToday == 0) {
      message = 'Hadi ilk soruyla başla!';
    } else if (solvedToday >= totalToday) {
      message = 'Bugünkü hedefini tamamladın! 🎉';
    } else {
      message = 'Hedefe bir adım daha yaklaştın!';
    }

    final card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dairesel ilerleme halkası
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: const Color(0xFF253354),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kAccent),
                  ),
                ),
                Text(
                  '%$percent',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Metinler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Günlük hedef',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$solvedToday / $totalToday soru',
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: kTextSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: kTextSecondary.withValues(alpha: 0.7),
              size: 26,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: kAccent.withValues(alpha: 0.10),
        child: card,
      ),
    );
  }
}
