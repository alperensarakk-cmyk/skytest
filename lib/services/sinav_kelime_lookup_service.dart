import 'dart:convert';
import 'package:flutter/services.dart';

/// Sınav modu kelime çevirisi — [user_sozluk_ai.json] + çekim eşleştirme.
class SinavKelimeLookupService {
  SinavKelimeLookupService._();

  static Map<String, String>? _lookup;
  static List<String>? _phrases;

  static Future<void> ensureLoaded() async {
    if (_lookup != null) return;

    final raw =
        await rootBundle.loadString('assets/user_sozluk_ai.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final map = <String, String>{};
    final phraseKeys = <String>[];

    for (final e in json.entries) {
      if (e.value is! String) continue;
      final key = _norm(e.key);
      final tr = (e.value as String).trim();
      if (key.isEmpty || tr.isEmpty) continue;
      map[key] = tr;
      if (key.contains(' ')) phraseKeys.add(key);
    }

    _lookup = map;
    _phrases = phraseKeys.toSet().toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  static bool get isReady => _lookup != null;

  /// Tıklanan kelimeyi ara: tam eşleşme → çekim kökü.
  static String? lookupWord(String tapped) {
    if (_lookup == null) return null;
    final w = _norm(tapped);
    if (w.length < 2) return null;

    final direct = _lookup![w];
    if (direct != null) return direct;

    for (final stem in _stemCandidates(w)) {
      final hit = _lookup![stem];
      if (hit != null) return hit;
    }
    return null;
  }

  /// Popup için kısa Türkçe: ilk anlam.
  static String shortTurkce(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    s = s.replaceFirst(RegExp(r'^\d+\s*[-–.)]\s*'), '');
    final slash = s.split(' / ');
    if (slash.length > 1) return slash.first.trim();
    final paren = s.indexOf('(');
    if (paren > 0) return s.substring(0, paren).trim();
    return s;
  }

  static List<String> _stemCandidates(String w) {
    final out = <String>[];
    void push(String s) {
      final n = _norm(s);
      if (n.length >= 3 && !out.contains(n)) out.add(n);
    }

    if (w.endsWith('ied') && w.length > 4) {
      push('${w.substring(0, w.length - 3)}y');
    }
    if (w.endsWith('ies') && w.length > 4) {
      push('${w.substring(0, w.length - 3)}y');
    }
    if (w.endsWith('ying') && w.length > 5) {
      push('${w.substring(0, w.length - 4)}y');
    }
    if (w.endsWith('ing') && w.length > 4) {
      final stem = w.substring(0, w.length - 3);
      push(stem);
      push('${stem}e');
    }
    if (w.endsWith('ed') && w.length > 3) {
      final stem = w.substring(0, w.length - 2);
      push(stem);
      push('${stem}e');
      if (stem.endsWith('i')) push('${stem.substring(0, stem.length - 1)}y');
    }
    if (w.endsWith('es') && w.length > 3) {
      final stem = w.substring(0, w.length - 2);
      push(stem);
      push('${stem}e');
    }
    if (w.endsWith('s') && w.length > 3 && !w.endsWith('ss')) {
      push(w.substring(0, w.length - 1));
    }
    if (w.endsWith('er') && w.length > 4) {
      push(w.substring(0, w.length - 2));
      push('${w.substring(0, w.length - 2)}e');
    }
    if (w.endsWith('ly') && w.length > 4) {
      push(w.substring(0, w.length - 2));
    }

    return out;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isWordChar(String? ch) {
    if (ch == null || ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        ch == '-' ||
        ch == "'";
  }

  /// Metni tıklanabilir ve düz parçalara ayırır (öbek önce).
  static List<TapPart> tokenizeForTap(String text) {
    if (text.isEmpty) return [TapPart.plain('')];
    if (_lookup == null) return [TapPart.plain(text)];

    final out = <TapPart>[];
    var i = 0;

    while (i < text.length) {
      final hit = _matchAt(text, i);
      if (hit != null) {
        out.add(TapPart.tappable(hit.text, hit.turkce));
        i += hit.text.length;
        continue;
      }

      final start = i;
      i++;
      while (i < text.length && _matchAt(text, i) == null) {
        i++;
      }
      out.add(TapPart.plain(text.substring(start, i)));
    }

    return _mergePlain(out);
  }

  static _Hit? _matchAt(String text, int index) {
    final tail = text.substring(index);
    final tailLow = tail.toLowerCase();

    for (final ph in _phrases!) {
      if (!tailLow.startsWith(ph)) continue;
      final after = index + ph.length;
      if (index > 0 && _isWordChar(text[index - 1])) continue;
      if (after < text.length && _isWordChar(text[after])) continue;
      return _Hit(text.substring(index, after), _lookup![ph]!);
    }

    final word = RegExp(r"^[A-Za-z][A-Za-z'-]*").firstMatch(tail);
    if (word != null) {
      final w = word.group(0)!;
      final tr = lookupWord(w);
      if (tr != null) return _Hit(w, tr);
    }

    return null;
  }

  static List<TapPart> _mergePlain(List<TapPart> parts) {
    if (parts.length < 2) return parts;
    final merged = <TapPart>[parts.first];
    for (var i = 1; i < parts.length; i++) {
      final p = parts[i];
      final last = merged.last;
      if (!p.isTappable && !last.isTappable) {
        merged[merged.length - 1] =
            TapPart.plain('${last.text}${p.text}');
      } else {
        merged.add(p);
      }
    }
    return merged;
  }
}

class _Hit {
  const _Hit(this.text, this.turkce);
  final String text;
  final String turkce;
}

class TapPart {
  const TapPart._({required this.text, this.turkce});

  factory TapPart.plain(String text) => TapPart._(text: text);
  factory TapPart.tappable(String text, String turkce) =>
      TapPart._(text: text, turkce: turkce);

  final String text;
  final String? turkce;

  bool get isTappable => turkce != null;
}
