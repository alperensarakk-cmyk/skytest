import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/challenge.dart';
import '../models/sky_fight_question.dart';
import 'aviation_callsign_service.dart';

class ChallengeService {
  static final _db = FirebaseFirestore.instance;

  static const _questionsCol = 'sky_fight_challenges';
  static const _resultsCol = 'challenge_results';
  static const _kTotalQ = 400; // Firestore q1..q400 (challenge havuzu)
  static const _kDailyCount = 10;
  static const _kWeeklyCount = 20;

  // ── Challenge ID üretimi (deterministic, sunucu gerekmez) ──────────────────

  static String dailyChallengeId([DateTime? date]) {
    final d = date ?? DateTime.now();
    return 'daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Haftalık sınav Pazartesi 00:00’da başlar; id o Pazartesi’nin tarihidir.
  /// Örn. `weekly_2026-05-19` (eski `weekly_2026-W21` formatından farklıdır).
  static String weeklyChallengeId([DateTime? date]) {
    final monday = _mondayOfWeek(date ?? DateTime.now());
    return 'weekly_${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  /// Eski sürümlerdeki ISO hafta id’si (`weekly_2026-W21`) — Firestore kayıtları silinmedi.
  static String legacyWeeklyChallengeId(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final weekNum = _isoWeekNumber(d);
    return 'weekly_${d.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  static int _isoWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays + 1;
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  static List<String> _weeklyLeaderboardLookupIds(DateTime now) {
    return {
      weeklyChallengeId(now),
      legacyWeeklyChallengeId(now),
    }.toList();
  }

  static List<String> _weeklyPreviousWinnerLookupIds(DateTime now) {
    final prevMonday = _mondayOfWeek(now).subtract(const Duration(days: 7));
    return {
      weeklyChallengeId(prevMonday),
      legacyWeeklyChallengeId(now.subtract(const Duration(days: 7))),
      legacyWeeklyChallengeId(prevMonday),
    }.toList();
  }

  /// Dart: weekday 1 = Pazartesi, 7 = Pazar.
  static DateTime _mondayOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static int _weeklySeed(DateTime monday) =>
      monday.year * 10000 + monday.month * 100 + monday.day;

  /// 1.0.7 ve öncesi: `year * 1000 + ISO hafta` (weekly_2026-W21 ile aynı dönem).
  static int _legacyWeeklySeed(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.year * 1000 + _isoWeekNumber(d);
  }

  /// Geçen haftaların soruları — yeni + eski seed (güncelleme sonrası tekrarı önler).
  static Set<String> _weeklyExcludeIds(DateTime monday) {
    final exclude = <String>{};
    for (var weeksAgo = 1; weeksAgo <= 2; weeksAgo++) {
      final day = monday.subtract(Duration(days: 7 * weeksAgo));
      exclude.addAll(_pickQuestionIds(
        seed: _weeklySeed(day),
        count: _kWeeklyCount,
      ));
      exclude.addAll(_pickQuestionIds(
        seed: _legacyWeeklySeed(day),
        count: _kWeeklyCount,
      ));
    }
    return exclude;
  }

  // ── Soru ID'leri (seed'e göre deterministik) ──────────────────────────────

  static List<String> _pickQuestionIds({
    required int seed,
    required int count,
    Set<String> exclude = const {},
  }) {
    final rng = Random(seed);
    var pool = List.generate(_kTotalQ, (i) => 'q${i + 1}')
        .where((id) => !exclude.contains(id))
        .toList();

    if (pool.length < count) {
      debugPrint(
        'ChallengeService: exclude sonrası yeterli soru yok '
        '(${pool.length}/$count); tam havuz kullanılıyor.',
      );
      pool = List.generate(_kTotalQ, (i) => 'q${i + 1}');
    }

    pool.shuffle(rng);
    final picked = <String>[];
    for (final id in pool) {
      if (picked.length >= count) break;
      picked.add(id);
    }
    assert(
      picked.length == picked.toSet().length,
      'ChallengeService: aynı id iki kez seçildi (seed=$seed)',
    );
    return picked;
  }

  static String _normalizeQuestionText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  /// Eksik / tekrarlayan metin sonrası yedek soru id’leri (deterministik).
  static List<String> _refillSpareIds({
    required int seed,
    required Set<String> usedIds,
    required int count,
  }) {
    if (count <= 0) return const [];
    final rng = Random(seed + 7919);
    final pool = List.generate(_kTotalQ, (i) => 'q${i + 1}')
        .where((id) => !usedIds.contains(id))
        .toList()
      ..shuffle(rng);
    return pool.take(count).toList();
  }

  /// Sınav doldurma / yedek seçim için seed (`weekly_2026-05-26`, `daily_…`).
  static int? refillSeedForChallengeId(String challengeId) {
    if (challengeId.startsWith('weekly_')) {
      final body = challengeId.substring(7);
      final parts = body.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return _weeklySeed(DateTime(y, m, d));
        }
      }
    }
    if (challengeId.startsWith('daily_')) {
      final parts = challengeId.substring(6).split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return y * 10000 + m * 100 + d;
        }
      }
    }
    return null;
  }

  static List<String> dailyQuestionIds([DateTime? date]) {
    final d = date ?? DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return _pickQuestionIds(seed: seed, count: _kDailyCount);
  }

  /// Bu haftanın 20 sorusu; son 2 haftanın (yeni + eski algoritma) soruları çıkarılır.
  static List<String> weeklyQuestionIds([DateTime? date]) {
    final monday = _mondayOfWeek(date ?? DateTime.now());
    return _pickQuestionIds(
      seed: _weeklySeed(monday),
      count: _kWeeklyCount,
      exclude: _weeklyExcludeIds(monday),
    );
  }

  // ── Güncel challenge nesnesini oluştur ────────────────────────────────────

  static Challenge todayDaily() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];
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
    final now = DateTime.now();
    final weekStart = _mondayOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    return Challenge(
      id: weeklyChallengeId(now),
      type: 'weekly',
      label: 'Haftalık Test',
      questionIds: weeklyQuestionIds(now),
      activeFrom: weekStart,
      activeTo: weekEnd,
    );
  }

  // ── Soruları çek ─────────────────────────────────────────────────────────

  static Future<List<SkyFightQuestion>> fetchQuestions(
    List<String> ids, {
    int? refillSeed,
    int? minCount,
  }) async {
    final uniqueIds = <String>[];
    final seenListId = <String>{};
    for (final id in ids) {
      if (seenListId.add(id)) uniqueIds.add(id);
    }
    if (uniqueIds.length < ids.length) {
      debugPrint(
        'ChallengeService: questionIds içinde tekrarlayan id atlandı '
        '(${ids.length} → ${uniqueIds.length})',
      );
    }

    Future<Map<String, SkyFightQuestion>> loadBatch(
        Iterable<String> toLoad) async {
      final list = toLoad.toList();
      if (list.isEmpty) return {};
      final snaps = await Future.wait(
        list.map((id) => _db.collection(_questionsCol).doc(id).get()),
      );
      final map = <String, SkyFightQuestion>{};
      for (final s in snaps) {
        if (s.exists) {
          map[s.id] = SkyFightQuestion.fromFirestore(s.id, s.data()!)
              .withShuffledOptions(
            seed: SkyFightQuestion.shuffleSeedForId(s.id),
          );
        }
      }
      return map;
    }

    var byId = await loadBatch(uniqueIds);
    final target = minCount ?? uniqueIds.length;
    final result = <SkyFightQuestion>[];
    final seenText = <String>{};
    final usedIds = <String>{};

    void tryAdd(String id) {
      final q = byId[id];
      if (q == null) return;
      if (!seenText.add(_normalizeQuestionText(q.question))) {
        debugPrint(
          'ChallengeService: aynı soru metni atlandı ($id)',
        );
        return;
      }
      if (!usedIds.add(id)) return;
      result.add(q);
    }

    for (final id in uniqueIds) {
      tryAdd(id);
    }

    if (refillSeed != null && result.length < target) {
      var need = target - result.length;
      while (need > 0) {
        final before = result.length;
        final spares =
            _refillSpareIds(seed: refillSeed, usedIds: usedIds, count: need);
        final missing =
            spares.where((id) => !byId.containsKey(id)).toList(growable: false);
        if (missing.isNotEmpty) {
          byId = {...byId, ...await loadBatch(missing)};
        }
        for (final id in spares) {
          tryAdd(id);
          if (result.length >= target) break;
        }
        if (result.length == before) break;
        need = target - result.length;
      }
    }

    if (result.length < target) {
      debugPrint(
        'ChallengeService: $target soru bekleniyordu, ${result.length} yüklendi',
      );
    }
    return result;
  }

  // ── Doc ID: challengeId_userId  (composite index gerekmez) ──────────────

  static String _docId(String challengeId, String userId) =>
      '${challengeId}__$userId';

  // ── Kullanıcının bu challenge'ı daha önce bitirip bitirmediğini kontrol et ─

  static Future<ChallengeResult?> myResult(
    String challengeId,
    String userId, {
    String? challengeType,
  }) async {
    final ids = <String>[challengeId];
    if (challengeType == 'weekly') {
      ids.addAll(_weeklyLeaderboardLookupIds(DateTime.now()));
    }

    for (final id in ids.toSet()) {
      final snap =
          await _db.collection(_resultsCol).doc(_docId(id, userId)).get();
      if (snap.exists) {
        return ChallengeResult.fromDoc(snap.id, snap.data()!);
      }
    }
    return null;
  }

  // ── Sonucu kaydet (bir kez; mevcut kayıt varsa üzerine yazılmaz) ─────────

  /// `true` = yeni kayıt yazıldı, `false` = zaten sonuç vardı.
  static Future<bool> submitResult({
    required String challengeId,
    required String userId,
    required int score,
    required int totalQuestions,
    required int totalMs,
  }) async {
    final ref = _db.collection(_resultsCol).doc(_docId(challengeId, userId));
    return _db.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return false;

      transaction.set(ref, {
        'challengeId': challengeId,
        'userId': userId,
        'pilotName': AviationCallsignService.fromUserId(userId),
        'score': score,
        'totalQuestions': totalQuestions,
        'totalMs': totalMs,
        'accuracy': totalQuestions > 0 ? score / totalQuestions : 0.0,
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  // ── Önceki dönemin birincisi ──────────────────────────────────────────────

  static Future<ChallengeResult?> previousWinner(String type) async {
    if (type == 'daily') {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final results = await leaderboard(dailyChallengeId(yesterday));
      return results.isEmpty ? null : results.first;
    }

    for (final id in _weeklyPreviousWinnerLookupIds(DateTime.now())) {
      final results = await leaderboard(id);
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  /// Haftalık: yeni + eski id’lerdeki kayıtları birleştirir.
  static Future<List<ChallengeResult>> leaderboardForChallenge(
      Challenge challenge) async {
    if (challenge.type == 'weekly') {
      return _leaderboardMerged(_weeklyLeaderboardLookupIds(DateTime.now()));
    }
    return leaderboard(challenge.id);
  }

  // ── Leaderboard — sadece challengeId ile filtrele, client'ta sırala ───────
  // Tek alan filtresi → otomatik index, composite index gerekmez.

  static Future<List<ChallengeResult>> leaderboard(String challengeId) async {
    final results = await _fetchResultsForChallengeId(challengeId);
    _sortChallengeResults(results);
    return results.take(50).toList();
  }

  static Future<List<ChallengeResult>> _leaderboardMerged(
      List<String> challengeIds) async {
    final unique = challengeIds.toSet().toList();
    if (unique.length == 1) return leaderboard(unique.first);

    final byUser = <String, ChallengeResult>{};
    for (final id in unique) {
      for (final r in await _fetchResultsForChallengeId(id)) {
        final prev = byUser[r.userId];
        if (prev == null || _ranksHigher(r, prev)) {
          byUser[r.userId] = r;
        }
      }
    }

    final merged = byUser.values.toList();
    _sortChallengeResults(merged);
    return merged.take(50).toList();
  }

  static Future<List<ChallengeResult>> _fetchResultsForChallengeId(
      String challengeId) async {
    final snap = await _db
        .collection(_resultsCol)
        .where('challengeId', isEqualTo: challengeId)
        .limit(100)
        .get();

    return snap.docs
        .map((d) => ChallengeResult.fromDoc(d.id, d.data()))
        .toList();
  }

  static bool _ranksHigher(ChallengeResult a, ChallengeResult b) {
    if (a.score != b.score) return a.score > b.score;
    return a.totalMs < b.totalMs;
  }

  static void _sortChallengeResults(List<ChallengeResult> results) {
    results.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.totalMs.compareTo(b.totalMs);
    });
  }
}
