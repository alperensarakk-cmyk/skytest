import 'dart:math';

import '../models/kelime_model.dart';

/// Kelime çalışması için 4 şık: doğru Türkçe + 3 yanlış (başka kelimelerden).
///
/// Tüm havuzdan düz rastgele seçmek, bazı kayıtlarda `turkce` alanı uzun tanım
/// cümlesi olduğunda şıkları okunaksız yapıyordu. Önce kısa adaylar, gerekirse
/// uzunlar kullanılır; aynı metin ve doğru cevap tekrarı elenir.
List<String> buildKelimeMcqTurkceOptions(
  KelimeModel kelime,
  List<KelimeModel> tumKelimeler, {
  Random? random,
  int maxDistractorChars = 72,
}) {
  final rng = random ?? Random();
  final correct = kelime.turkce;
  final others = List<KelimeModel>.from(
    tumKelimeler.where((k) => k.id != kelime.id),
  )..shuffle(rng);

  final preferred = others
      .where((k) {
        final t = k.turkce;
        return t.length <= maxDistractorChars && t != correct;
      })
      .toList();
  final fallback = others
      .where((k) {
        final t = k.turkce;
        return t.length > maxDistractorChars && t != correct;
      })
      .toList();
  preferred.shuffle(rng);
  fallback.shuffle(rng);

  final wrong = <String>[];
  void pick(Iterable<KelimeModel> src) {
    for (final k in src) {
      if (wrong.length >= 3) return;
      final t = k.turkce;
      if (t.isEmpty || wrong.contains(t)) continue;
      wrong.add(t);
    }
  }

  pick(preferred);
  pick(fallback);
  pick(others);

  final opts = [correct, ...wrong.take(3)];
  opts.shuffle(rng);
  return opts;
}
