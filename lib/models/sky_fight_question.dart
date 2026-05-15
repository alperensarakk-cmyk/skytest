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
}
