import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/kelime_model.dart';

class KelimeService {
  // ── Tüm kelimeleri yükle ──────────────────────────────────────────────────
  static Future<List<KelimeModel>> loadAll() async {
    final raw  = await rootBundle.loadString('assets/kelimeler.json');
    final list = (jsonDecode(raw) as List<dynamic>)
        .where((e) {
          final m = e as Map<String, dynamic>;
          return m['id'] != null && (m['ingilizce'] as String? ?? '').isNotEmpty;
        })
        .map((e) => KelimeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  // ── Karıştırılmış N kelime ─────────────────────────────────────────────────
  static Future<List<KelimeModel>> loadShuffled({int? count}) async {
    final all = await loadAll();
    all.shuffle();
    if (count != null && count < all.length) {
      return all.take(count).toList();
    }
    return all;
  }
}
