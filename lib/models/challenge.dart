import 'package:cloud_firestore/cloud_firestore.dart';

/// Günlük veya haftalık challenge bilgisi.
class Challenge {
  final String id;       // "daily_2026-05-01" veya "weekly_2026-W18"
  final String type;     // "daily" | "weekly"
  final String label;    // "1 Mayıs Günlük Sınavı"
  final List<String> questionIds;
  final DateTime activeFrom;
  final DateTime activeTo;

  const Challenge({
    required this.id,
    required this.type,
    required this.label,
    required this.questionIds,
    required this.activeFrom,
    required this.activeTo,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(activeFrom) && now.isBefore(activeTo);
  }

  Duration get remaining => activeTo.difference(DateTime.now());
}

/// Bir kullanıcının challenge sonucu.
class ChallengeResult {
  final String id;
  final String challengeId;
  final String userId;
  final String pilotName;
  final int score;       // doğru sayısı
  final int totalMs;     // toplam süre (ms)
  final double accuracy; // 0.0 - 1.0
  final DateTime submittedAt;

  const ChallengeResult({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.pilotName,
    required this.score,
    required this.totalMs,
    required this.accuracy,
    required this.submittedAt,
  });

  factory ChallengeResult.fromDoc(String id, Map<String, dynamic> d) {
    final ts = d['submittedAt'];
    return ChallengeResult(
      id: id,
      challengeId: d['challengeId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      pilotName: d['pilotName'] as String? ?? 'Pilot',
      score: d['score'] as int? ?? 0,
      totalMs: d['totalMs'] as int? ?? 0,
      accuracy: (d['accuracy'] as num?)?.toDouble() ?? 0.0,
      submittedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
