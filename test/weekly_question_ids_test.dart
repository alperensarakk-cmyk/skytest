import 'package:flutter_test/flutter_test.dart';
import 'package:aerotest/services/challenge_service.dart';

void main() {
  test('weekly and daily question id lists have no duplicate ids', () {
    final dates = [
      DateTime(2026, 6, 2),
      DateTime(2026, 5, 26),
      DateTime(2025, 12, 29),
      DateTime(2024, 1, 1),
    ];
    for (final d in dates) {
      final weekly = ChallengeService.weeklyQuestionIds(d);
      expect(
        weekly.length,
        weekly.toSet().length,
        reason: 'weekly dupes on $d: $weekly',
      );
      final daily = ChallengeService.dailyQuestionIds(d);
      expect(
        daily.length,
        daily.toSet().length,
        reason: 'daily dupes on $d: $daily',
      );
    }
  });
}
