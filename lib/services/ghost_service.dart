import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ghost_record.dart';
import '../models/sky_fight_question.dart';

class GhostService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'ghost_records';
  static const _kMaxAgeDays = 30;

  /// Başka bir kullanıcının ghost kaydını bul.
  static Future<GhostRecord?> findOpponent(String myUserId) async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: _kMaxAgeDays)),
    );

    // Sadece orderBy kullanıyoruz; composite index gerektirmiyor.
    final snap = await _db
        .collection(_col)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    // Kendi kayıtlarımı çıkar
    final others =
        snap.docs.where((d) => d.data()['userId'] != myUserId).toList();

    if (others.isEmpty) return null;

    // Rastgele bir ghost seç (son 10 içinden)
    final pool = others.take(10).toList();
    pool.shuffle(Random());
    final doc = pool.first;
    return GhostRecord.fromDoc(doc.id, doc.data());
  }

  /// Maç sonucunu ghost record olarak kaydet.
  static Future<void> save({
    required String userId,
    required List<SkyFightQuestion> questions,
    required List<String?> answers,
    required List<int?> timesMs,
    required int finalHp,
    String? pilotName,
  }) async {
    if (pilotName == null || pilotName.trim().isEmpty) {
      final tag = userId.length >= 4
          ? userId.substring(0, 4).toUpperCase()
          : userId.toUpperCase();
      pilotName = 'Pilot #$tag';
    }

    final rounds = questions.asMap().entries.map((e) {
      final i = e.key;
      final q = e.value;
      final ans = i < answers.length ? answers[i] : null;
      final ms  = i < timesMs.length ? (timesMs[i] ?? 9000) : 9000;
      return GhostRound(
        questionId: q.id,
        answer: ans,
        timeMs: ms.clamp(300, 14500),
        correct: ans != null && ans == q.correct,
      ).toMap();
    }).toList();

    await _db.collection(_col).add({
      'userId': userId,
      'pilotName': pilotName,
      'createdAt': FieldValue.serverTimestamp(),
      'questionIds': questions.map((q) => q.id).toList(),
      'rounds': rounds,
      'finalHp': finalHp,
    });
  }
}
