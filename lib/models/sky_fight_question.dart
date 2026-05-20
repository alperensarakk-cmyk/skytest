import 'dart:math';

class SkyFightQuestion {
  final String id;
  final String type;
  final String question;
  final Map<String, String> options;
  final String correct;
  final String difficulty;

  const SkyFightQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correct,
    required this.difficulty,
  });

  factory SkyFightQuestion.fromFirestore(String docId, Map<String, dynamic> data) {
    final rawOptions = data['options'] as Map<String, dynamic>? ?? {};
    return SkyFightQuestion(
      id: docId,
      type: data['type'] as String? ?? '',
      question: data['question'] as String? ?? '',
      options: rawOptions.map((k, v) => MapEntry(k, v.toString())),
      correct: data['correct'] as String? ?? 'A',
      difficulty: data['difficulty'] as String? ?? 'easy',
    );
  }

  /// Şık metinlerini A–D arasında karıştırır; doğru cevap harfi güncellenir.
  /// [seed] verilirse sıra deterministik (online maç / aynı soru id).
  SkyFightQuestion withShuffledOptions({int? seed}) {
    if (options.length < 2) return this;

    final rng = Random(seed ?? id.hashCode);
    final keys = options.keys.toList()..sort();
    final values = options.values.toList()..shuffle(rng);

    final shuffled = <String, String>{};
    for (var i = 0; i < keys.length; i++) {
      shuffled[keys[i]] = values[i];
    }

    final answerText = options[correct] ?? '';
    var newCorrect = correct;
    for (final e in shuffled.entries) {
      if (e.value == answerText) {
        newCorrect = e.key;
        break;
      }
    }

    return SkyFightQuestion(
      id: id,
      type: type,
      question: question,
      options: shuffled,
      correct: newCorrect,
      difficulty: difficulty,
    );
  }

  static int shuffleSeedForId(String questionId) {
    final m = RegExp(r'(\d+)').firstMatch(questionId);
    return m != null ? int.parse(m.group(1)!) : questionId.hashCode;
  }
}
