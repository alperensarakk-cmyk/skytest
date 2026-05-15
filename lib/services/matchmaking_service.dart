import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchmakingResult {
  final String matchId;
  final bool isPlayer1;
  final List<String> questionIds;

  const MatchmakingResult({
    required this.matchId,
    required this.isPlayer1,
    required this.questionIds,
  });
}

class MatchmakingService {
  static final _db = FirebaseFirestore.instance;
  static const _kRoundSeconds = 15;
  static const _kSearchTimeoutSeconds = 15;

  // Soru ID'leri q1-q100 olarak sabit; Firestore'a ekstra sorgu atmaz.
  static List<String> _randomQuestionIds({int count = 10}) {
    final all = List.generate(100, (i) => 'q${i + 1}');
    all.shuffle(Random());
    return all.take(count).toList();
  }

  /// Rakip arar. Bulamazsa null döner (AI moduna düş).
  static Future<MatchmakingResult?> search(String userId) async {
    final mmRef = _db.collection('matchmaking').doc(userId);

    await mmRef.set({
      'userId': userId,
      'status': 'searching',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final completer = Completer<MatchmakingResult?>();
    StreamSubscription? sub;

    // Kendi dokümanını dinle — başka biri bizi eşleştirirse buradan haberimiz olur.
    sub = mmRef.snapshots().listen((snap) {
      if (!snap.exists || completer.isCompleted) return;
      final data = snap.data()!;
      if (data['status'] == 'matched' && data['matchId'] != null) {
        completer.complete(MatchmakingResult(
          matchId: data['matchId'] as String,
          isPlayer1: data['isPlayer1'] as bool? ?? false,
          questionIds:
              List<String>.from(data['questionIds'] as List? ?? []),
        ));
      }
    });

    // Her 2 saniyede rakip ara.
    Timer.periodic(const Duration(seconds: 2), (t) async {
      if (completer.isCompleted) {
        t.cancel();
        return;
      }
      try {
        final result = await _tryCreateMatch(userId);
        if (result != null && !completer.isCompleted) {
          t.cancel();
          completer.complete(result);
        }
      } catch (_) {}
    });

    // 15 saniye sonra AI moduna dön.
    Timer(const Duration(seconds: _kSearchTimeoutSeconds), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final result = await completer.future;
    await sub.cancel();

    if (result == null) {
      await mmRef.delete().catchError((_) {});
    }

    return result;
  }

  static Future<MatchmakingResult?> _tryCreateMatch(String myUserId) async {
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 30)),
    );

    final snap = await _db
        .collection('matchmaking')
        .where('status', isEqualTo: 'searching')
        .where('createdAt', isGreaterThan: cutoff)
        .limit(5)
        .get();

    final candidates =
        snap.docs.where((d) => d.id != myUserId).toList();
    if (candidates.isEmpty) return null;

    final opponent = candidates.first;
    final opponentId = opponent.id;
    final questionIds = _randomQuestionIds();

    String? matchId;

    try {
      await _db.runTransaction((tx) async {
        final opRef = _db.collection('matchmaking').doc(opponentId);
        final opSnap = await tx.get(opRef);

        if (!opSnap.exists) throw Exception('opponent gone');
        if (opSnap.data()?['status'] != 'searching') {
          throw Exception('already matched');
        }

        final matchRef = _db.collection('matches').doc();
        matchId = matchRef.id;

        tx.set(matchRef, {
          'p1': myUserId,
          'p2': opponentId,
          'p1Hp': 100,
          'p2Hp': 100,
          'questionIds': questionIds,
          'round': 0,
          'status': 'active',
          'winner': null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // İlk turu oluştur.
        tx.set(
          matchRef.collection('rounds').doc('0'),
          _roundDoc(),
        );

        // Rakibin matchmaking dokümanını güncelle.
        tx.update(opRef, {
          'status': 'matched',
          'matchId': matchId,
          'isPlayer1': false,
          'questionIds': questionIds,
        });
      });
    } catch (_) {
      return null;
    }

    if (matchId == null) return null;

    // Kendi matchmaking dokümanını güncelle.
    await _db.collection('matchmaking').doc(myUserId).update({
      'status': 'matched',
      'matchId': matchId,
      'isPlayer1': true,
    });

    return MatchmakingResult(
      matchId: matchId!,
      isPlayer1: true,
      questionIds: questionIds,
    );
  }

  static Map<String, dynamic> _roundDoc() => {
        'p1Answer': null,
        'p1Ms': null,
        'p2Answer': null,
        'p2Ms': null,
        'resolved': false,
        'deadline': Timestamp.fromDate(
          DateTime.now().add(
            const Duration(seconds: _kRoundSeconds + 2),
          ),
        ),
      };

  static Future<void> cancelSearch(String userId) async {
    await _db
        .collection('matchmaking')
        .doc(userId)
        .delete()
        .catchError((_) {});
  }
}
