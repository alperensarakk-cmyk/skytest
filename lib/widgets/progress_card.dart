import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    this.solvedToday = 0,
    this.totalToday = 10,
  });

  final int solvedToday;
  final int totalToday;

  @override
  Widget build(BuildContext context) {
    // 0 soruda bar tamamen boş
    final double progress = (solvedToday == 0 || totalToday == 0)
        ? 0.0
        : (solvedToday / totalToday).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kAccent.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bugün ',
                      style: TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                    Text(
                      '$solvedToday soru',
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' çözdün 🎯',
                      style: TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,          // 0.0 → tamamen boş bar
                    minHeight: 6,
                    backgroundColor: const Color(0xFF253354),
                    valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  solvedToday == 0
                      ? 'Hadi ilk soruyla başla!'
                      : '$solvedToday / $totalToday hedef tamamlandı',
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAccent.withValues(alpha: 0.10),
              border: Border.all(
                color: kAccent.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: kAccent,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
