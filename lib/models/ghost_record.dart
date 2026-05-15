class GhostRound {
  final String questionId;
  final String? answer; // null = süre doldu
  final int timeMs;     // ne kadar sürede cevapladı (ms)
  final bool correct;

  const GhostRound({
    required this.questionId,
    required this.answer,
    required this.timeMs,
    required this.correct,
  });

  factory GhostRound.fromMap(Map<String, dynamic> m) {
    return GhostRound(
      questionId: m['questionId'] as String? ?? '',
      answer: m['answer'] as String?,
      timeMs: (m['timeMs'] as int?) ?? 8000,
      correct: m['correct'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        'answer': answer,
        'timeMs': timeMs,
        'correct': correct,
      };
}

class GhostRecord {
  final String recordId;
  final String userId;
  final String pilotName;
  final DateTime createdAt;
  final List<String> questionIds;
  final List<GhostRound> rounds;
  final int finalHp;

  const GhostRecord({
    required this.recordId,
    required this.userId,
    required this.pilotName,
    required this.createdAt,
    required this.questionIds,
    required this.rounds,
    required this.finalHp,
  });

  factory GhostRecord.fromDoc(String id, Map<String, dynamic> d) {
    final ts = d['createdAt'];
    final createdAt = ts != null
        ? (ts as dynamic).toDate() as DateTime
        : DateTime.now();

    final roundsList = (d['rounds'] as List?)
            ?.map((r) => GhostRound.fromMap(r as Map<String, dynamic>))
            .toList() ??
        [];

    return GhostRecord(
      recordId: id,
      userId: d['userId'] as String? ?? '',
      pilotName: d['pilotName'] as String? ?? 'Pilot',
      createdAt: createdAt,
      questionIds: List<String>.from(d['questionIds'] as List? ?? []),
      rounds: roundsList,
      finalHp: d['finalHp'] as int? ?? 0,
    );
  }
}
