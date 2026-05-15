import 'dart:math';

/// AI rakip simülasyonu: %75 doğruluk, 3.5–8 sn arası insan benzeri gecikme.
class AiPilotService {
  AiPilotService._();

  static const double _accuracy = 0.75;
  static const int _minDelayMs = 3500;
  static const int _maxDelayMs = 8000;

  /// [questionIndex] seed olarak kullanılır → aynı soruda her seferinde tutarlı.
  static int responseDelayMs(int questionIndex) {
    final seed = DateTime.now().millisecondsSinceEpoch + questionIndex;
    final r = Random(seed);
    final range = _maxDelayMs - _minDelayMs;
    // İnsan benzeri dağılım: düşük ve orta süre biraz daha sık
    final raw = _minDelayMs + (r.nextDouble() * range).toInt();
    // Hafif Gaussian benzeri (iki sample ortalaması)
    final raw2 = _minDelayMs + (r.nextDouble() * range).toInt();
    return ((raw + raw2) / 2).toInt();
  }

  /// AI'nın bu soruda doğru cevap verip vermeyeceği.
  static bool isCorrect(int questionIndex) {
    final seed = questionIndex * 1337 + 42;
    return Random(seed).nextDouble() < _accuracy;
  }

  /// Doğruysa doğru şıkkı, yanlışsa rastgele farklı bir şık döner.
  static String answer(
    int questionIndex,
    String correctKey,
    List<String> allKeys,
  ) {
    if (isCorrect(questionIndex)) return correctKey;
    final wrong = allKeys.where((k) => k != correctKey).toList();
    if (wrong.isEmpty) return correctKey;
    return wrong[Random(questionIndex * 7).nextInt(wrong.length)];
  }
}
