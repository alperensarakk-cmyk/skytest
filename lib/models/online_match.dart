import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineMatch {
  final String matchId;
  final String p1;
  final String p2;
  final int p1Hp;
  final int p2Hp;
  final List<String> questionIds;
  final int round;
  final String status; // "active" | "finished"
  final String? winner; // "p1" | "p2" | "draw"

  const OnlineMatch({
    required this.matchId,
    required this.p1,
    required this.p2,
    required this.p1Hp,
    required this.p2Hp,
    required this.questionIds,
    required this.round,
    required this.status,
    this.winner,
  });

  factory OnlineMatch.fromDoc(String id, Map<String, dynamic> d) {
    return OnlineMatch(
      matchId: id,
      p1: d['p1'] as String,
      p2: d['p2'] as String,
      p1Hp: d['p1Hp'] as int? ?? 100,
      p2Hp: d['p2Hp'] as int? ?? 100,
      questionIds: List<String>.from(d['questionIds'] as List? ?? []),
      round: d['round'] as int? ?? 0,
      status: d['status'] as String? ?? 'active',
      winner: d['winner'] as String?,
    );
  }

  bool get isFinished => status == 'finished';
}

class RoundData {
  final String? p1Answer;
  final int? p1Ms;
  final String? p2Answer;
  final int? p2Ms;
  final bool resolved;
  final DateTime deadline;

  const RoundData({
    required this.p1Answer,
    required this.p1Ms,
    required this.p2Answer,
    required this.p2Ms,
    required this.resolved,
    required this.deadline,
  });

  factory RoundData.fromDoc(Map<String, dynamic> d) {
    final dl = d['deadline'];
    final deadline = dl is Timestamp
        ? dl.toDate()
        : DateTime.now().add(const Duration(seconds: 15));
    return RoundData(
      p1Answer: d['p1Answer'] as String?,
      p1Ms: d['p1Ms'] as int?,
      p2Answer: d['p2Answer'] as String?,
      p2Ms: d['p2Ms'] as int?,
      resolved: d['resolved'] as bool? ?? false,
      deadline: deadline,
    );
  }

  bool get bothAnswered => p1Answer != null && p2Answer != null;
}
