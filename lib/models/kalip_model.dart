class KalipModel {
  const KalipModel({
    required this.id,
    required this.kategori,
    required this.ipucuKalip,
    required this.tamamlayici,
    required this.turkcaAnlami,
    required this.ornekCumle,
    required this.taktik,
  });

  final int id;
  final String kategori;
  final String ipucuKalip;
  final String tamamlayici;
  final String turkcaAnlami;
  final String ornekCumle;
  final String taktik;

  factory KalipModel.fromJson(Map<String, dynamic> j) => KalipModel(
        id: j['id'] as int,
        kategori: j['kategori'] as String,
        ipucuKalip: j['ipucu_kalip'] as String,
        tamamlayici: j['tamamlayici'] as String,
        turkcaAnlami: j['turkce_anlami'] as String,
        ornekCumle: j['ornek_cumle'] as String,
        taktik: j['taktik'] as String,
      );

  /// "Edat_Kaliplari" → "Edat Kalıpları"
  String get kategoriLabel => kategori.replaceAll('_', ' ');
}
