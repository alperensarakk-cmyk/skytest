class SoruModel {
  /// [soruMetniParagrafinClozeVeyaBenzeri] iken soru cümlesi yerine gösterilir.
  static const clozeYonlendirmeMetni =
      'İlgili boşluk yukarıdaki metinde. Doğru şıkkı seçin.';

  const SoruModel({
    required this.id,
    required this.kategori,
    required this.soruTipi,
    this.paragraf = '',
    required this.soruMetni,
    required this.secenekler,
    required this.dogruCevap,
    required this.nedenDogru,
    required this.yanlislar,
    required this.tip,
  });

  final int               id;
  final String            kategori;
  final String            soruTipi;
  /// Paragraf sorularında okunacak metin; boşsa gösterilmez.
  final String            paragraf;
  final String            soruMetni;
  final Map<String,String> secenekler; // {'a': '...', 'b': '...', 'c': '...', 'd': '...'}
  final String            dogruCevap;  // 'a' | 'b' | 'c' | 'd'
  final String            nedenDogru;
  final String            yanlislar;
  final String            tip;

  /// Boşluk / satır sonu farklarını yok sayarak paragraf ile soru metni aynı mı.
  /// Aynıysa ekranda iki kez göstermemek için kullanılır.
  bool get paragrafSoruMetniyleOzdes {
    if (paragraf.isEmpty) return false;
    return _metinOzeti(paragraf) == _metinOzeti(soruMetni);
  }

  /// Soru metni, paragrafın neredeyse aynı cümlesi (boşluk/çizgi ile) veya
  /// paragrafın başıyla çok örtüşüyorsa; tam soru cümlesini tekrar göstermeyelim.
  bool get soruMetniParagrafinClozeVeyaBenzeri {
    if (paragraf.isEmpty) return false;
    if (paragrafSoruMetniyleOzdes) return false;

    final p = _metinOzeti(paragraf);
    final soruBlanksiz = soruMetni.replaceAll(RegExp(r'_{2,}|…+'), ' ');
    var stem = _metinOzeti(soruBlanksiz);
    stem = stem.replaceAll(RegExp(r'[.\s,;:]+$'), '').trim();

    if (stem.length >= 22 && p.startsWith(stem)) return true;

    final hasBlank = soruMetni.contains(RegExp(r'_{2,}|…+'));
    if (!hasBlank) return false;

    final pa = _articlesiz(p.toLowerCase());
    final sa = _articlesiz(_metinOzeti(soruBlanksiz).toLowerCase());
    return _ortakBaslangicUzunlugu(pa, sa) >= 38;
  }

  static String _metinOzeti(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _articlesiz(String s) => s.replaceAllMapped(
        RegExp(r'\b(a|an|the)\s+', caseSensitive: false),
        (_) => '',
      );

  static int _ortakBaslangicUzunlugu(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) break;
      i++;
    }
    return i;
  }

  static int? _parseId(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String _str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static Map<String, String> _parseSecenekler(dynamic raw) {
    if (raw is! Map) return {};
    final m = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim().toLowerCase();
      m[k] = _str(e.value);
    }
    return m;
  }

  static String _normalizeDogruCevap(dynamic raw, Map<String, String> sec) {
    final s = _str(raw, 'a').trim().toLowerCase();
    if (s.isEmpty) return sec.keys.isNotEmpty ? sec.keys.first : 'a';
    final letter = s.length == 1 ? s : s.substring(0, 1);
    if (sec.containsKey(letter)) return letter;
    if (sec.containsKey(s)) return s;
    return sec.keys.isNotEmpty ? sec.keys.first : 'a';
  }

  /// Eksik alanlarda güvenli varsayılanlar; geçersiz kayıt için `null`.
  static SoruModel? tryFromJson(Map<String, dynamic> j) {
    final id = _parseId(j['id']);
    if (id == null) return null;

    final soruMetni = _str(j['soru_metni']).trim();
    if (soruMetni.isEmpty) return null;

    final secenekler = _parseSecenekler(j['secenekler']);
    if (secenekler.isEmpty) return null;

    final dogru = _normalizeDogruCevap(j['dogru_cevap'], secenekler);

    return SoruModel(
      id: id,
      kategori: _str(j['kategori'], 'Genel'),
      soruTipi: _str(j['soru_tipi'], 'Genel'),
      paragraf: _str(j['paragraf']).trim(),
      soruMetni: soruMetni,
      secenekler: secenekler,
      dogruCevap: dogru,
      nedenDogru: _str(j['neden_dogru']),
      yanlislar: _str(j['yanlislar']),
      tip: _str(j['tip']),
    );
  }

  factory SoruModel.fromJson(Map<String, dynamic> j) {
    final s = SoruModel.tryFromJson(j);
    if (s == null) {
      throw FormatException('Geçersiz soru kaydı: id=${j['id']}');
    }
    return s;
  }
}
