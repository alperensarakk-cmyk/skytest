import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/online_match.dart';

class OnlineMatchService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference _matchRef(String matchId) =>
      _db.collection('matches').doc(matchId);

  static DocumentReference _roundRef(String matchId, int idx) =>
      _matchRef(matchId).collection('rounds').doc('$idx');

  // ── Dinleyiciler ──────────────────────────────────────────────────────────

  static Stream<OnlineMatch> watchMatch(String matchId) {
    return _matchRef(matchId)
        .snapshots()
        .where((s) => s.exists)
        .map((s) =>
            OnlineMatch.fromDoc(s.id, s.data() as Map<String, dynamic>));
  }

  static Stream<RoundData?> watchRound(String matchId, int roundIdx) {
    return _roundRef(matchId, roundIdx).snapshots().map((s) =>
        s.exists ? RoundData.fromDoc(s.data() as Map<String, dynamic>) : null);
  }

  // ── Cevap gönder ──────────────────────────────────────────────────────────

  static Future<void> submitAnswer({
    required String matchId,
    required int roundIdx,
    required bool isPlayer1,
    required String answer,
    required int timeMs,
  }) async {
    await _roundRef(matchId, roundIdx).update(
      isPlayer1
          ? {'p1Answer': answer, 'p1Ms': timeMs}
          : {'p2Answer': answer, 'p2Ms': timeMs},
    );
  }

  // ── Tur çözümle (transaction, sadece bir kez çalışır) ────────────────────

  static Future<void> resolveRound({
    required String matchId,
    required int roundIdx,
    required int totalRounds,
    required int p1DmgReceived, // p1'in aldığı hasar
    required int p2DmgReceived, // p2'nin aldığı hasar
  }) async {
    final mRef = _matchRef(matchId);
    final rRef = _roundRef(matchId, roundIdx);

    await _db.runTransaction((tx) async {
      final roundSnap = await tx.get(rRef);
      final matchSnap = await tx.get(mRef);

      if (!roundSnap.exists || !matchSnap.exists) return;
      if ((roundSnap.data() as Map<String, dynamic>)['resolved'] == true) {
        return; // Başka client zaten çözdü.
      }

      final md = matchSnap.data() as Map<String, dynamic>;
      final currentP1Hp = md['p1Hp'] as int? ?? 100;
      final currentP2Hp = md['p2Hp'] as int? ?? 100;
      final newP1Hp = (currentP1Hp - p1DmgReceived).clamp(0, 100);
      final newP2Hp = (currentP2Hp - p2DmgReceived).clamp(0, 100);

      final nextRound = roundIdx + 1;
      final gameOver =
          newP1Hp <= 0 || newP2Hp <= 0 || nextRound >= totalRounds;

      String? winner;
      if (gameOver) {
        if (newP1Hp > newP2Hp) {
          winner = 'p1';
        } else if (newP2Hp > newP1Hp) {
          winner = 'p2';
        } else {
          winner = 'draw';
        }
      }

      tx.update(rRef, {'resolved': true});
      tx.update(mRef, {
        'p1Hp': newP1Hp,
        'p2Hp': newP2Hp,
        'round': nextRound,
        if (gameOver) 'status': 'finished',
        if (winner != null) 'winner': winner,
      });

      // Sonraki tur dokümanını önceden oluştur.
      if (!gameOver) {
        tx.set(
          _roundRef(matchId, nextRound),
          {
            'p1Answer': null,
            'p1Ms': null,
            'p2Answer': null,
            'p2Ms': null,
            'resolved': false,
            'deadline': Timestamp.fromDate(
              DateTime.now().add(const Duration(seconds: 17)),
            ),
          },
        );
      }
    });
  }

  // ── Temizlik ──────────────────────────────────────────────────────────────

  static Future<void> cleanup(String userId) async {
    await _db
        .collection('matchmaking')
        .doc(userId)
        .delete()
        .catchError((_) {});
  }
}
