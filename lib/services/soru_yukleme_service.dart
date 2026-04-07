import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/soru_model.dart';

/// Tüm soru JSON dosyalarını yükler ve tek listede birleştirir.
class SoruYuklemeService {
  SoruYuklemeService._();

  static const List<String> _assetPaths = [
    'assets/sorular.json',
  ];

  /// Tüm sorular tek JSON dosyasından okunur.
  static Future<List<SoruModel>> tumSorulariYukle() async {
    final out = <SoruModel>[];
    final seenIds = <int>{};

    for (final path in _assetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! List<dynamic>) continue;

        for (final e in decoded) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final s = SoruModel.tryFromJson(m);
          if (s == null) continue;
          if (seenIds.add(s.id)) out.add(s);
        }
      } catch (_) {
        // Eksik asset veya bozuk JSON: diğer dosyaya devam
      }
    }

    return out;
  }
}
