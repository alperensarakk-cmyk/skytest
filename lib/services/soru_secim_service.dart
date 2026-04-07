import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../models/soru_model.dart';

/// Tüm soru tiplerinde dengeli seçim ve sıra (serpiştirme).
class SoruSecimService {
  SoruSecimService._();

  /// Karşılaştırma için Türkçe karakterleri ASCII'ye yaklaştırır (küçük harf girdi).
  static String _foldAscii(String s) {
    return s
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// `soru_tipi` için gruplama anahtarı: eş anlamlılar tek tipe toplanır.
  static String normalizeSoruTipi(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Genel';

    final lower = t.toLowerCase();
    final f = _foldAscii(lower);

    if (f == 'grammar' || f == 'gramer') return 'Gramer';
    if (f == 'vocabulary' || f == 'kelime' || f == 'kelimeler') {
      return 'Kelime';
    }
    if (f == 'yapi' || f == 'yapı' || f == 'structure') return 'Yapi';
    if (f == 'ceviri' ||
        f == 'cevirı' ||
        f == 'translation' ||
        f == 'translate') {
      return 'Ceviri';
    }
    if (f == 'okuma') return 'Okuma';
    if (f == 'bosluk_doldurma' || f.startsWith('bosluk_doldur')) {
      return 'Bosluk_Doldurma';
    }
    if (f == 'cumle_tamamlama' ||
        (f.contains('cumle') && f.contains('tamamlama'))) {
      return 'Cumle_Tamamlama';
    }
    if (f == 'paragraf' ||
        f == 'passage' ||
        f == 'reading' ||
        f.contains('paragraph')) {
      return 'Paragraf';
    }
    if (f == 'genel' || f == 'general' || f == 'diger' || f == 'misc') {
      return 'Genel';
    }

    return _capitalizeFirst(t);
  }

  /// Havuzdan en fazla [n] soru seçer; tipler arası adil kota + serpiştirilmiş sıra.
  ///
  /// [useRandomization]: false ise şık havuzu ve sıra deterministik (sınavda karıştırma kapalı).
  ///
  /// [avoidRecentIds]: doluysa önce bu ID'ler dışındaki sorular seçilir; yeterli soru yoksa
  /// kalan kotayı havuzun geri kalanından doldurur (oturumlar arası tekrarı azaltır).
  static List<SoruModel> secDengeli(
    List<SoruModel> havuz,
    int n, {
    bool useRandomization = true,
    Random? random,
    Set<int>? avoidRecentIds,
  }) {
    if (havuz.isEmpty || n <= 0) return [];

    final rng = random ?? (useRandomization ? Random() : Random(0));
    final havuzF =
        _havuzOkumaBoslukParagrafBasinaMax2(havuz, rng, useRandomization);

    final avoid = avoidRecentIds;
    if (avoid != null && avoid.isNotEmpty) {
      final preferred =
          havuzF.where((s) => !avoid.contains(s.id)).toList(growable: false);
      if (preferred.length >= n) {
        return _secDengeliCore(
          preferred,
          n,
          useRandomization: useRandomization,
          random: random,
        );
      }
      if (preferred.isNotEmpty) {
        final first = _secDengeliCore(
          preferred,
          preferred.length,
          useRandomization: useRandomization,
          random: random,
        );
        final picked = first.map((e) => e.id).toSet();
        final rest =
            havuzF.where((s) => !picked.contains(s.id)).toList(growable: false);
        final need = n - first.length;
        final second = _secDengeliCore(
          rest,
          need,
          useRandomization: useRandomization,
          random: random,
        );
        return [...first, ...second];
      }
    }

    return _secDengeliCore(
      havuzF,
      n,
      useRandomization: useRandomization,
      random: random,
    );
  }

  static Map<String, Map<String, int>>? _sinavSablonuCache;

  static Future<Map<String, Map<String, int>>> _sinavSablonlariYukle() async {
    if (_sinavSablonuCache != null) return _sinavSablonuCache!;
    final raw = await rootBundle.loadString('assets/sinav_sablonu.json');
    final top = jsonDecode(raw) as Map<String, dynamic>;
    _sinavSablonuCache = {
      for (final e in top.entries)
        e.key.toString(): {
          for (final ie in (e.value as Map<String, dynamic>).entries)
            ie.key.toString(): (ie.value as num).toInt(),
        },
    };
    return _sinavSablonuCache!;
  }

  /// Sınav modu: `sinav_sablonu.json` içindeki [n] soru sayısına karşılık gelen
  /// tip kotlarına göre seçim + serpiştirme. Şablon yoksa veya toplam kotası
  /// [n] ile uyuşmuyorsa [secDengeli] kullanılır.
  static Future<List<SoruModel>> secSinavSablonu(
    List<SoruModel> havuz,
    int n, {
    bool useRandomization = true,
    Random? random,
    Set<int>? avoidRecentIds,
  }) async {
    if (havuz.isEmpty || n <= 0) return [];

    Map<String, int>? quotas;
    try {
      final all = await _sinavSablonlariYukle();
      final soruSayisiKey = n.toString();
      final row = all[soruSayisiKey];
      if (row != null) {
        final sum = row.values.fold<int>(0, (a, b) => a + b);
        if (sum == n) quotas = row;
      }
    } catch (_) {
      quotas = null;
    }

    if (quotas == null) {
      return secDengeli(
        havuz,
        n,
        useRandomization: useRandomization,
        random: random,
        avoidRecentIds: avoidRecentIds,
      );
    }

    final rng = random ?? (useRandomization ? Random() : Random(0));
    return _secSablonCore(
      havuz,
      n,
      quotas,
      useRandomization: useRandomization,
      rng: rng,
      avoidRecentIds: avoidRecentIds,
    );
  }

  static List<SoruModel> _secSablonCore(
    List<SoruModel> havuz,
    int nEff,
    Map<String, int> quotas, {
    required bool useRandomization,
    required Random rng,
    Set<int>? avoidRecentIds,
  }) {
    if (havuz.isEmpty || nEff <= 0) return [];

    final havuzF =
        _havuzOkumaBoslukParagrafBasinaMax2(havuz, rng, useRandomization);

    final nCap = nEff > havuzF.length ? havuzF.length : nEff;
    final groups = <String, List<SoruModel>>{};
    for (final s in havuzF) {
      final k = normalizeSoruTipi(s.soruTipi);
      groups.putIfAbsent(k, () => []).add(s);
    }

    final target = Map<String, int>.from(quotas);
    for (final tip in target.keys.toList()) {
      final want = target[tip] ?? 0;
      final have = groups[tip]?.length ?? 0;
      if (want > have) target[tip] = have;
    }

    var shortfall = nCap - target.values.fold<int>(0, (a, b) => a + b);
    while (shortfall > 0) {
      var bestTip = '';
      var bestSpare = 0;
      for (final tip in groups.keys) {
        final spare = groups[tip]!.length - (target[tip] ?? 0);
        if (spare > bestSpare) {
          bestSpare = spare;
          bestTip = tip;
        }
      }
      if (bestSpare <= 0) break;
      target[bestTip] = (target[bestTip] ?? 0) + 1;
      shortfall--;
    }

    final sablonTipler = quotas.keys.toList()..sort();
    final tipSirasi = <String>[
      ...sablonTipler,
      ...{
        for (final k in groups.keys)
          if (!sablonTipler.contains(k)) k,
      },
    ];

    final picked = <SoruModel>[];
    final pickedIds = <int>{};

    for (final tip in tipSirasi) {
      final want = target[tip] ?? 0;
      if (want <= 0) continue;
      final bucket = List<SoruModel>.from(groups[tip] ?? []);
      _orderBucketPreferAvoid(
        bucket,
        avoidRecentIds,
        useRandomization,
        rng,
      );
      var taken = 0;
      for (final s in bucket) {
        if (picked.length >= nCap) break;
        if (taken >= want) break;
        if (pickedIds.contains(s.id)) continue;
        picked.add(s);
        pickedIds.add(s.id);
        taken++;
      }
    }

    if (picked.length < nCap) {
      final rest = havuzF.where((s) => !pickedIds.contains(s.id)).toList();
      _orderBucketPreferAvoid(
        rest,
        avoidRecentIds,
        useRandomization,
        rng,
      );
      for (final s in rest) {
        if (picked.length >= nCap) break;
        picked.add(s);
        pickedIds.add(s.id);
      }
    }

    if (picked.length > nCap) {
      picked.removeRange(nCap, picked.length);
    }

    final byTip = <String, List<SoruModel>>{};
    for (final s in picked) {
      final k = normalizeSoruTipi(s.soruTipi);
      byTip.putIfAbsent(k, () => []).add(s);
    }
    return _interleaveByTip(byTip, rng, useRandomization);
  }

  static void _orderBucketPreferAvoid(
    List<SoruModel> bucket,
    Set<int>? avoid,
    bool useRandomization,
    Random rng,
  ) {
    if (avoid == null || avoid.isEmpty) {
      if (useRandomization) {
        bucket.shuffle(rng);
      } else {
        bucket.sort((a, b) => a.id.compareTo(b.id));
      }
      return;
    }
    final good = bucket.where((s) => !avoid.contains(s.id)).toList();
    final bad = bucket.where((s) => avoid.contains(s.id)).toList();
    if (useRandomization) {
      good.shuffle(rng);
      bad.shuffle(rng);
    } else {
      good.sort((a, b) => a.id.compareTo(b.id));
      bad.sort((a, b) => a.id.compareTo(b.id));
    }
    bucket
      ..clear()
      ..addAll(good)
      ..addAll(bad);
  }

  static List<SoruModel> _secDengeliCore(
    List<SoruModel> havuz,
    int n, {
    bool useRandomization = true,
    Random? random,
  }) {
    if (havuz.isEmpty || n <= 0) return [];

    final rng = random ?? (useRandomization ? Random() : Random(0));
    final nEff = n > havuz.length ? havuz.length : n;

    final groups = <String, List<SoruModel>>{};
    for (final s in havuz) {
      final k = normalizeSoruTipi(s.soruTipi);
      groups.putIfAbsent(k, () => []).add(s);
    }

    var typeKeys = groups.keys.toList()..sort();
    if (useRandomization) {
      typeKeys.shuffle(rng);
    }
    final t = typeKeys.length;
    if (t == 0) return [];

    final target = <String, int>{for (final k in typeKeys) k: 0};

    var base = nEff ~/ t;
    var rem = nEff % t;
    for (var i = 0; i < t; i++) {
      target[typeKeys[i]] = base + (i < rem ? 1 : 0);
    }

    for (final k in typeKeys) {
      final cap = groups[k]!.length;
      if (target[k]! > cap) target[k] = cap;
    }

    var shortfall = nEff - target.values.fold<int>(0, (a, b) => a + b);
    while (shortfall > 0) {
      var progressed = false;
      final sorted = List<String>.from(typeKeys)
        ..sort((a, b) {
          final sa = groups[a]!.length - target[a]!;
          final sb = groups[b]!.length - target[b]!;
          return sb.compareTo(sa);
        });
      for (final k in sorted) {
        if (shortfall <= 0) break;
        final spare = groups[k]!.length - target[k]!;
        if (spare > 0) {
          target[k] = target[k]! + 1;
          shortfall--;
          progressed = true;
        }
      }
      if (!progressed) break;
    }

    final queues = <String, List<SoruModel>>{};
    for (final k in typeKeys) {
      final bucket = List<SoruModel>.from(groups[k]!);
      if (useRandomization) {
        bucket.shuffle(rng);
      } else {
        bucket.sort((a, b) => a.id.compareTo(b.id));
      }
      final take = target[k]!.clamp(0, bucket.length);
      queues[k] = bucket.sublist(0, take);
    }

    var picked = <SoruModel>[];
    for (final k in typeKeys) {
      picked.addAll(queues[k]!);
    }

    if (picked.length < nEff) {
      final pickedIds = picked.map((e) => e.id).toSet();
      final rest = havuz.where((s) => !pickedIds.contains(s.id)).toList();
      if (useRandomization) {
        rest.shuffle(rng);
      } else {
        rest.sort((a, b) => a.id.compareTo(b.id));
      }
      for (final s in rest) {
        if (picked.length >= nEff) break;
        picked.add(s);
      }
    }

    if (picked.length > nEff) {
      picked = picked.sublist(0, nEff);
    }

    final byTip = <String, List<SoruModel>>{};
    for (final s in picked) {
      final k = normalizeSoruTipi(s.soruTipi);
      byTip.putIfAbsent(k, () => []).add(s);
    }

    return _interleaveByTip(byTip, rng, useRandomization);
  }

  static const _kPassageCluster = '__passage_cluster__';

  /// Okuma + Bosluk_Doldurma: aynı [paragraf] metni tek küme; boş paragrafta her soru ayrı küme.
  static String _paragrafKumeAnahtari(SoruModel s) {
    final raw = s.paragraf.trim();
    if (raw.isEmpty) return '__bos_${s.id}';
    return raw.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Okuma + Bosluk_Doldurma: aynı paragraf metnine göre gruplanır; gruptan en fazla
  /// 2 soru havuzda kalır (bir oturumda aynı passage’dan fazla soru seçilmesin).
  static List<SoruModel> _havuzOkumaBoslukParagrafBasinaMax2(
    List<SoruModel> havuz,
    Random rng,
    bool useRandomization,
  ) {
    final diger = <SoruModel>[];
    final ob = <SoruModel>[];
    for (final s in havuz) {
      final t = normalizeSoruTipi(s.soruTipi);
      if (t == 'Okuma' || t == 'Bosluk_Doldurma') {
        ob.add(s);
      } else {
        diger.add(s);
      }
    }
    if (ob.isEmpty) return havuz;

    final byKey = <String, List<SoruModel>>{};
    for (final s in ob) {
      byKey.putIfAbsent(_paragrafKumeAnahtari(s), () => []).add(s);
    }
    final kept = <SoruModel>[];
    for (final list in byKey.values) {
      final copy = List<SoruModel>.from(list);
      if (useRandomization) {
        copy.shuffle(rng);
      } else {
        copy.sort((a, b) => a.id.compareTo(b.id));
      }
      kept.addAll(copy.take(2));
    }
    return [...diger, ...kept];
  }

  static List<List<SoruModel>> _okumaBoslukParagrafKumeleri(
    List<SoruModel> okuma,
    List<SoruModel> bosluk,
    Random rng,
    bool random,
  ) {
    final byKey = <String, List<SoruModel>>{};
    for (final s in okuma) {
      byKey.putIfAbsent(_paragrafKumeAnahtari(s), () => []).add(s);
    }
    for (final s in bosluk) {
      byKey.putIfAbsent(_paragrafKumeAnahtari(s), () => []).add(s);
    }
    var kumeler = byKey.values.map((list) {
      final copy = List<SoruModel>.from(list);
      if (random) {
        copy.shuffle(rng);
      } else {
        copy.sort((a, b) => a.id.compareTo(b.id));
      }
      return copy;
    }).toList();
    if (random) {
      kumeler.shuffle(rng);
    } else {
      kumeler.sort((a, b) => a.first.id.compareTo(b.first.id));
    }
    return kumeler;
  }

  static List<SoruModel> _interleaveByTip(
    Map<String, List<SoruModel>> byTip,
    Random rng,
    bool random,
  ) {
    if (byTip.isEmpty) return [];

    final tipQueues = <String, List<SoruModel>>{};
    for (final e in byTip.entries) {
      if (e.key == 'Okuma' || e.key == 'Bosluk_Doldurma') continue;
      tipQueues[e.key] = List<SoruModel>.from(e.value);
    }

    final okuma = byTip['Okuma'] ?? const <SoruModel>[];
    final bosluk = byTip['Bosluk_Doldurma'] ?? const <SoruModel>[];
    final passageKumeler = (okuma.isNotEmpty || bosluk.isNotEmpty)
        ? _okumaBoslukParagrafKumeleri(
            List<SoruModel>.from(okuma),
            List<SoruModel>.from(bosluk),
            rng,
            random,
          )
        : <List<SoruModel>>[];

    final orderKeys = <String>[...tipQueues.keys]..sort();
    if (passageKumeler.isNotEmpty) {
      orderKeys.add(_kPassageCluster);
    }

    if (orderKeys.isEmpty) return [];

    if (orderKeys.length == 1 && orderKeys.single == _kPassageCluster) {
      return passageKumeler.expand((c) => c).toList(growable: false);
    }

    if (random) orderKeys.shuffle(rng);

    final out = <SoruModel>[];
    String? lastTip;
    var rr = 0;
    final kumeSirasi = List<List<SoruModel>>.from(passageKumeler);

    bool tipBos(String k) {
      if (k == _kPassageCluster) return kumeSirasi.isEmpty;
      return tipQueues[k]?.isEmpty ?? true;
    }

    while (true) {
      final nonEmpty = orderKeys.where((k) => !tipBos(k)).toList();
      if (nonEmpty.isEmpty) break;

      String? pickKey;
      if (!random) {
        for (var i = 0; i < orderKeys.length; i++) {
          final idx = (rr + i) % orderKeys.length;
          final k = orderKeys[idx];
          if (!tipBos(k)) {
            pickKey = k;
            rr = (idx + 1) % orderKeys.length;
            break;
          }
        }
        if (pickKey == null) break;
      } else {
        final candidates = lastTip != null && nonEmpty.length > 1
            ? nonEmpty.where((k) => k != lastTip).toList()
            : nonEmpty;
        final use = candidates.isNotEmpty ? candidates : nonEmpty;
        pickKey = use[rng.nextInt(use.length)];
        lastTip = pickKey;
      }

      if (pickKey == _kPassageCluster) {
        out.addAll(kumeSirasi.removeAt(0));
      } else {
        out.add(tipQueues[pickKey]!.removeAt(0));
      }
    }

    return out;
  }
}
