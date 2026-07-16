import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kelime_model.dart';
import 'daily_limit_service.dart';
import 'kelime_yanlis_service.dart';
import 'premium_service.dart';

enum KelimeSessionPhase { list, test, done }

enum KelimeZorlukModu { kolay, zor }

class KelimeSessionSnapshot {
  const KelimeSessionSnapshot({
    required this.wordIds,
    required this.phase,
    required this.mod,
  });

  final List<int> wordIds;
  final KelimeSessionPhase phase;
  final KelimeZorlukModu mod;
}

class KelimeSessionLimitException implements Exception {}

/// Liste → test oturumu; kolay/zor mod ve kelime rotasyonu.
class KelimeSessionService {
  KelimeSessionService._();

  static const hardSessionSize = 10;
  static const kolaySizeMin = 10;
  static const kolaySizeMax = 50;
  static const kolaySizeStep = 10;
  static const _recentSessionKeep = 2;

  static const _kSessionIds = 'kelime_session_ids';
  static const _kSessionPhase = 'kelime_session_phase';
  static const _kSessionMod = 'kelime_session_mod';
  static const _kPreferredMod = 'kelime_preferred_mod';
  static const _kPreferredKolaySize = 'kelime_preferred_kolay_size';
  static const _kRecentSessions = 'kelime_recent_sessions';
  static const _kProgress = 'kelime_word_progress';

  static List<int> get kolaySizeOptions => List.generate(
        (kolaySizeMax - kolaySizeMin) ~/ kolaySizeStep + 1,
        (i) => kolaySizeMin + i * kolaySizeStep,
      );

  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  static Future<void> onDayChanged() async {
    final prefs = await _p();
    await prefs.remove(_kSessionIds);
    await prefs.remove(_kSessionPhase);
    await prefs.remove(_kSessionMod);
  }

  /// Devam eden oturumu tamamlamadan bırak (mod değişimi vb.).
  static Future<void> abandonSession() async {
    final prefs = await _p();
    await prefs.remove(_kSessionIds);
    await prefs.remove(_kSessionPhase);
    await prefs.remove(_kSessionMod);
  }

  static Future<KelimeZorlukModu> getPreferredMod() async {
    final prefs = await _p();
    final raw = prefs.getString(_kPreferredMod);
    return KelimeZorlukModu.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => KelimeZorlukModu.kolay,
    );
  }

  static Future<void> setPreferredMod(KelimeZorlukModu mod) async {
    final prefs = await _p();
    await prefs.setString(_kPreferredMod, mod.name);
  }

  static Future<int> getPreferredKolaySize() async {
    final prefs = await _p();
    final v = prefs.getInt(_kPreferredKolaySize) ?? kolaySizeMin;
    return v.clamp(kolaySizeMin, kolaySizeMax);
  }

  static Future<void> setPreferredKolaySize(int size) async {
    final prefs = await _p();
    await prefs.setInt(
      _kPreferredKolaySize,
      size.clamp(kolaySizeMin, kolaySizeMax),
    );
  }

  static KelimeZorlukModu _readMod(SharedPreferences prefs) {
    final raw = prefs.getString(_kSessionMod) ?? prefs.getString(_kPreferredMod);
    return KelimeZorlukModu.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => KelimeZorlukModu.kolay,
    );
  }

  static Future<KelimeSessionSnapshot?> getActiveSession() async {
    await DailyLimitService.ensureDay();
    final prefs = await _p();
    final raw = prefs.getString(_kSessionIds);
    if (raw == null || raw.isEmpty) return null;

    final ids = raw
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return null;

    final phaseStr = prefs.getString(_kSessionPhase) ?? KelimeSessionPhase.list.name;
    final phase = KelimeSessionPhase.values.firstWhere(
      (e) => e.name == phaseStr,
      orElse: () => KelimeSessionPhase.list,
    );
    if (phase == KelimeSessionPhase.done) return null;

    return KelimeSessionSnapshot(
      wordIds: ids,
      phase: phase,
      mod: _readMod(prefs),
    );
  }

  static Future<bool> canStartNewSession() async {
    if (await PremiumService.isPremiumUser()) return true;
    final active = await getActiveSession();
    if (active != null) return true;
    final rem = await DailyLimitService.kelimeSessionsRemaining();
    return rem > 0;
  }

  static Future<KelimeSessionSnapshot> startOrResume(
    List<KelimeModel> all, {
    required KelimeZorlukModu mod,
    int kolaySize = kolaySizeMin,
  }) async {
    await DailyLimitService.ensureDay();

    final active = await getActiveSession();
    if (active != null) return active;

    if (!await canStartNewSession()) {
      throw KelimeSessionLimitException();
    }

    final premium = await PremiumService.isPremiumUser();
    final size = mod == KelimeZorlukModu.zor || !premium
        ? hardSessionSize
        : kolaySize.clamp(kolaySizeMin, kolaySizeMax);

    await setPreferredMod(mod);
    if (mod == KelimeZorlukModu.kolay) {
      await setPreferredKolaySize(size);
    }

    final words = await _buildNewSet(all, size);
    final ids = words.map((k) => k.id).toList();
    await _saveSession(ids, KelimeSessionPhase.list, mod);
    await _markWordsSeen(ids);
    return KelimeSessionSnapshot(
      wordIds: ids,
      phase: KelimeSessionPhase.list,
      mod: mod,
    );
  }

  static Future<void> setPhase(KelimeSessionPhase phase) async {
    final prefs = await _p();
    await prefs.setString(_kSessionPhase, phase.name);
  }

  static Future<void> completeSession(List<KelimeModel> sessionWords) async {
    final prefs = await _p();
    final ids = sessionWords.map((k) => k.id).toList();

    await _appendRecentSession(ids);
    await prefs.setString(_kSessionPhase, KelimeSessionPhase.done.name);
    await prefs.remove(_kSessionIds);
    await prefs.remove(_kSessionMod);
    await DailyLimitService.recordKelimeSessionCompleted();
  }

  /// Zor modda 10/10 yapılamadıysa oturumu koru, listeye dön.
  static Future<void> retryHardSession() async {
    await setPhase(KelimeSessionPhase.list);
  }

  static bool canCompleteSession({
    required KelimeZorlukModu mod,
    required int correctCount,
    required int total,
  }) {
    if (mod == KelimeZorlukModu.zor) {
      return correctCount == hardSessionSize && total == hardSessionSize;
    }
    return correctCount >= 0;
  }

  static Future<void> recordTestAnswer(int id, bool correct) async {
    final prefs = await _p();
    final progress = _loadProgress(prefs);
    final cur = progress[id] ?? _WordProgress();
    progress[id] = _WordProgress(
      lastSeen: DateTime.now().millisecondsSinceEpoch,
      wrongCount: correct ? cur.wrongCount : cur.wrongCount + 1,
    );
    await _saveProgress(prefs, progress);
  }

  static List<KelimeModel> resolveWords(
    List<KelimeModel> all,
    List<int> ids,
  ) {
    final byId = {for (final k in all) k.id: k};
    return [for (final id in ids) if (byId.containsKey(id)) byId[id]!];
  }

  static List<KelimeModel> shuffledForTest(List<KelimeModel> session) {
    final out = List<KelimeModel>.from(session)..shuffle(Random());
    return out;
  }

  // ── İç yardımcılar ────────────────────────────────────────────────────────

  static Future<void> _saveSession(
    List<int> ids,
    KelimeSessionPhase phase,
    KelimeZorlukModu mod,
  ) async {
    final prefs = await _p();
    await prefs.setString(_kSessionIds, ids.join(','));
    await prefs.setString(_kSessionPhase, phase.name);
    await prefs.setString(_kSessionMod, mod.name);
  }

  static Future<void> _markWordsSeen(List<int> ids) async {
    final prefs = await _p();
    final progress = _loadProgress(prefs);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      final cur = progress[id] ?? _WordProgress();
      progress[id] = _WordProgress(
        lastSeen: now,
        wrongCount: cur.wrongCount,
      );
    }
    await _saveProgress(prefs, progress);
  }

  static Future<List<KelimeModel>> _buildNewSet(
    List<KelimeModel> all,
    int size,
  ) async {
    if (all.length <= size) {
      return List<KelimeModel>.from(all);
    }

    final prefs = await _p();
    final progress = _loadProgress(prefs);
    final excluded = _getExcludedIds(prefs);
    final yanlisIds = (await KelimeYanlisService.getYanlisIdsAsync()).toSet();

    var pool = all.where((k) => !excluded.contains(k.id)).toList();
    if (pool.length < size) {
      pool = List<KelimeModel>.from(all);
    }

    pool.sort((a, b) {
      final pa = progress[a.id];
      final pb = progress[b.id];
      final la = pa?.lastSeen ?? 0;
      final lb = pb?.lastSeen ?? 0;
      if (la == 0 && lb != 0) return -1;
      if (lb == 0 && la != 0) return 1;
      if (la != lb) return la.compareTo(lb);
      final wa = pa?.wrongCount ?? 0;
      final wb = pb?.wrongCount ?? 0;
      return wb.compareTo(wa);
    });

    final selected = <KelimeModel>[];
    final wrongBoost = pool.where((k) => yanlisIds.contains(k.id)).take(2);
    for (final k in wrongBoost) {
      if (selected.length >= size) break;
      selected.add(k);
    }

    for (final k in pool) {
      if (selected.length >= size) break;
      if (selected.any((s) => s.id == k.id)) continue;
      selected.add(k);
    }

    if (selected.length < size) {
      for (final k in all) {
        if (selected.length >= size) break;
        if (selected.any((s) => s.id == k.id)) continue;
        selected.add(k);
      }
    }

    return selected.take(size).toList();
  }

  static Future<void> _appendRecentSession(List<int> ids) async {
    final prefs = await _p();
    final raw = prefs.getStringList(_kRecentSessions) ?? [];
    raw.insert(0, ids.join(','));
    while (raw.length > _recentSessionKeep) {
      raw.removeLast();
    }
    await prefs.setStringList(_kRecentSessions, raw);
  }

  static Set<int> _getExcludedIds(SharedPreferences prefs) {
    final raw = prefs.getStringList(_kRecentSessions) ?? [];
    final out = <int>{};
    for (final s in raw) {
      for (final part in s.split(',')) {
        final id = int.tryParse(part);
        if (id != null) out.add(id);
      }
    }
    return out;
  }

  static Map<int, _WordProgress> _loadProgress(SharedPreferences prefs) {
    final raw = prefs.getString(_kProgress);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          int.parse(e.key): _WordProgress.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveProgress(
    SharedPreferences prefs,
    Map<int, _WordProgress> progress,
  ) async {
    final encoded = {
      for (final e in progress.entries) '${e.key}': e.value.toJson(),
    };
    await prefs.setString(_kProgress, jsonEncode(encoded));
  }
}

class _WordProgress {
  _WordProgress({this.lastSeen = 0, this.wrongCount = 0});

  final int lastSeen;
  final int wrongCount;

  factory _WordProgress.fromJson(Map<String, dynamic> json) => _WordProgress(
        lastSeen: json['ls'] as int? ?? 0,
        wrongCount: json['w'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {'ls': lastSeen, 'w': wrongCount};
}
