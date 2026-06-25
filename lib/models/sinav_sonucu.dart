import 'konu_performans.dart';

/// Tamamlanan bir sınavın kayıtlı özeti.
class SinavSonucu {
  const SinavSonucu({
    required this.tarih,
    required this.dogru,
    required this.yanlis,
    required this.bos,
    required this.toplam,
    required this.yuzde,
    required this.yanlisKategoriler,
    this.konuPerformans = const {},
    this.analizVersiyonu = 0,
  });

  final DateTime                    tarih;
  final int                       dogru;
  final int                       yanlis;
  final int                       bos;
  final int                       toplam;
  final double                    yuzde;
  final Map<String, int>          yanlisKategoriler;
  final Map<String, KonuPerformans> konuPerformans;

  /// 1 = konuPerformans ile güvenilir zayıf konu analizi.
  final int analizVersiyonu;

  Map<String, dynamic> toJson() => {
        'tarih':             tarih.toIso8601String(),
        'dogru':             dogru,
        'yanlis':            yanlis,
        'bos':               bos,
        'toplam':            toplam,
        'yuzde':             yuzde,
        'yanlisKategoriler': yanlisKategoriler,
        if (konuPerformans.isNotEmpty)
          'konuPerformans': konuPerformans.map(
            (k, v) => MapEntry(k, v.toJson()),
          ),
        if (analizVersiyonu > 0) 'analizVersiyonu': analizVersiyonu,
      };

  factory SinavSonucu.fromJson(Map<String, dynamic> j) {
    final perfRaw = j['konuPerformans'];
    final perf = <String, KonuPerformans>{};
    if (perfRaw is Map) {
      perfRaw.forEach((key, val) {
        if (val is Map) {
          perf[key as String] =
              KonuPerformans.fromJson(Map<String, dynamic>.from(val));
        }
      });
    }

    return SinavSonucu(
      tarih:    DateTime.parse(j['tarih'] as String),
      dogru:    j['dogru']  as int,
      yanlis:   j['yanlis'] as int,
      bos:      j['bos']    as int,
      toplam:   j['toplam'] as int,
      yuzde:    (j['yuzde'] as num).toDouble(),
      yanlisKategoriler: Map<String, int>.from(
        (j['yanlisKategoriler'] as Map).map(
          (k, v) => MapEntry(k as String, v as int),
        ),
      ),
      konuPerformans: perf,
      analizVersiyonu: j['analizVersiyonu'] as int? ?? 0,
    );
  }
}
