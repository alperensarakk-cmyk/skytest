import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/challenge.dart';
import '../models/sky_fight_question.dart';

class ChallengeService {
  static final _db = FirebaseFirestore.instance;

  static const _questionsCol = 'sky_fight_challenges';
  static const _resultsCol   = 'challenge_results';
  static const _kTotalQ      = 241; // Firestore q1..q241 (challenge havuzu)
  static const _kDailyCount  = 10;
  static const _kWeeklyCount = 20;

  // ── Challenge ID üretimi (deterministic, sunucu gerekmez) ──────────────────

  static String dailyChallengeId([DateTime? date]) {
    final d = date ?? DateTime.now();
    return 'daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String weeklyChallengeId([DateTime? date]) {
    final d = date ?? DateTime.now();
    final weekNum = _isoWeekNumber(d);
    return 'weekly_${d.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  static int _isoWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear   = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // ── Soru ID'leri (seed'e göre deterministik) ──────────────────────────────

  static List<String> _questionIdsForSeed(int seed, int count) {
    final rng  = Random(seed);
    final all  = List.generate(_kTotalQ, (i) => 'q${i + 1}');
    all.shuffle(rng);
    return all.take(count).toList();
  }

  static List<String> dailyQuestionIds([DateTime? date]) {
    final d    = date ?? DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return _questionIdsForSeed(seed, _kDailyCount);
  }

  static List<String> weeklyQuestionIds([DateTime? date]) {
    final d    = date ?? DateTime.now();
    final seed = d.year * 1000 + _isoWeekNumber(d);
    return _questionIdsForSeed(seed, _kWeeklyCount);
  }

  // ── Güncel challenge nesnesini oluştur ────────────────────────────────────

  static Challenge todayDaily() {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
                    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return Challenge(
      id: dailyChallengeId(now),
      type: 'daily',
      label: '${now.day} ${months[now.month - 1]} Günlük Sınavı',
      questionIds: dailyQuestionIds(now),
      activeFrom: today,
      activeTo: today.add(const Duration(days: 1)),
    );
  }

  static Challenge thisWeekly() {
    final now       = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd   = weekStart.add(const Duration(days: 7));
    return Challenge(
      id: weeklyChallengeId(now),
      type: 'weekly',
      label: 'Haftalık Test',
      questionIds: weeklyQuestionIds(now),
      activeFrom: DateTime(weekStart.year, weekStart.month, weekStart.day),
      activeTo: DateTime(weekEnd.year, weekEnd.month, weekEnd.day),
    );
  }

  // ── Soruları çek ─────────────────────────────────────────────────────────

  static Future<List<SkyFightQuestion>> fetchQuestions(
      List<String> ids) async {
    final futures =
        ids.map((id) => _db.collection(_questionsCol).doc(id).get()).toList();
    final snaps = await Future.wait(futures);
    return snaps
        .where((s) => s.exists)
        .map((s) => SkyFightQuestion.fromFirestore(s.id, s.data()!))
        .toList();
  }

  // ── Doc ID: challengeId_userId  (composite index gerekmez) ──────────────

  static String _docId(String challengeId, String userId) =>
      '${challengeId}__$userId';

  // ── Kullanıcının bu challenge'ı daha önce bitirip bitirmediğini kontrol et ─

  static Future<ChallengeResult?> myResult(
      String challengeId, String userId) async {
    final snap = await _db
        .collection(_resultsCol)
        .doc(_docId(challengeId, userId))
        .get();
    if (!snap.exists) return null;
    return ChallengeResult.fromDoc(snap.id, snap.data()!);
  }

  // ── Sonucu kaydet (doc ID sabit → tekrar oynayınca üzerine yazar) ─────────

  static Future<void> submitResult({
    required String challengeId,
    required String userId,
    required String pilotName,
    required int score,
    required int totalQuestions,
    required int totalMs,
  }) async {
    await _db
        .collection(_resultsCol)
        .doc(_docId(challengeId, userId))
        .set({
      'challengeId': challengeId,
      'userId': userId,
      'pilotName': pilotName,
      'score': score,
      'totalQuestions': totalQuestions,
      'totalMs': totalMs,
      'accuracy': totalQuestions > 0 ? score / totalQuestions : 0.0,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Önceki dönemin birincisi ──────────────────────────────────────────────

  static Future<ChallengeResult?> previousWinner(String type) async {
    final String prevId;
    if (type == 'daily') {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      prevId = dailyChallengeId(yesterday);
    } else {
      final lastWeek = DateTime.now().subtract(const Duration(days: 7));
      prevId = weeklyChallengeId(lastWeek);
    }

    final results = await leaderboard(prevId);
    return results.isEmpty ? null : results.first;
  }

  // ── Leaderboard — sadece challengeId ile filtrele, client'ta sırala ───────
  // Tek alan filtresi → otomatik index, composite index gerekmez.

  static Future<List<ChallengeResult>> leaderboard(
      String challengeId) async {
    final snap = await _db
        .collection(_resultsCol)
        .where('challengeId', isEqualTo: challengeId)
        .limit(100)
        .get();

    final results = snap.docs
        .map((d) => ChallengeResult.fromDoc(d.id, d.data()))
        .toList();

    // score desc, sonra totalMs asc (hızlı olan önce)
    results.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.totalMs.compareTo(b.totalMs);
    });

    return results.take(50).toList();
  }
}
