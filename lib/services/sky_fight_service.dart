import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sky_fight_question.dart';

class SkyFightService {
  SkyFightService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static const _collection = 'sky_fight_challenges';
  static const _logsCollection = 'sky_fight_logs';

  /// Anonim giriş — kullanıcı ID'si için.
  static Future<String> ensureSignedIn() async {
    var user = _auth.currentUser;
    if (user == null) {
      final cred = await _auth.signInAnonymously();
      user = cred.user!;
    }
    return user.uid;
  }

  /// Belirtilen ID'lere göre soruları sırayla çeker (online maç için).
  static Future<List<SkyFightQuestion>> fetchQuestionsByIds(
      List<String> ids) async {
    final futures =
        ids.map((id) => _db.collection(_collection).doc(id).get()).toList();
    final snaps = await Future.wait(futures);
    return snaps
        .where((s) => s.exists)
        .map((s) => SkyFightQuestion.fromFirestore(s.id, s.data()!))
        .toList();
  }

  /// Firestore'dan rastgele [count] soru çeker.
  /// Tüm koleksiyonu çeker, istemci tarafında shuffle eder (ilk aşama; belge sayısı < 500 için yeterli).
  static Future<List<SkyFightQuestion>> fetchQuestions({int count = 10}) async {
    final snap = await _db.collection(_collection).get();
    final all = snap.docs
        .map((d) => SkyFightQuestion.fromFirestore(d.id, d.data()))
        .toList();
    all.shuffle(Random());
    return all.take(count).toList();
  }

  /// Maç sonucunu Firestore'a kaydeder (Ghost Record için).
  static Future<void> logMatchResult({
    required String userId,
    required List<SkyFightQuestion> questions,
    required List<String?> userAnswers,
    required List<int?> userTimesMs,
    required int userScore,
    required int opponentScore,
  }) async {
    final batch = _db.batch();
    final matchRef = _db.collection(_logsCollection).doc();

    batch.set(matchRef, {
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
      'userScore': userScore,
      'opponentScore': opponentScore,
      'questionCount': questions.length,
    });

    for (var i = 0; i < questions.length; i++) {
      final qRef = matchRef.collection('answers').doc();
      batch.set(qRef, {
        'questionId': questions[i].id,
        'userAnswer': userAnswers.length > i ? userAnswers[i] : null,
        'correct': questions[i].correct,
        'isCorrect': (userAnswers.length > i && userAnswers[i] != null)
            ? userAnswers[i] == questions[i].correct
            : false,
        'timeMs': userTimesMs.length > i ? userTimesMs[i] : null,
      });
    }

    await batch.commit();
  }
}
