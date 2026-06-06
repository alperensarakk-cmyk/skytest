class KalipModel {
  const KalipModel({
    required this.id,
    required this.kategori,
    required this.ipucuKalip,
    required this.tamamlayici,
    required this.turkcaAnlami,
    required this.ornekCumle,
    required this.taktik,
    this.soruSayisi,
    this.tamIfade,
    this.jsonDisi = false,
  });

  final int id;
  final String kategori;
  final String ipucuKalip;
  final String tamamlayici;
  final String turkcaAnlami;
  final String ornekCumle;
  final String taktik;
  final int? soruSayisi;
  final String? tamIfade;
  final bool jsonDisi;

  factory KalipModel.fromJson(Map<String, dynamic> j) => KalipModel(
        id: j['id'] as int,
        kategori: j['kategori'] as String,
        ipucuKalip: j['ipucu_kalip'] as String,
        tamamlayici: j['tamamlayici'] as String,
        turkcaAnlami: j['turkce_anlami'] as String,
        ornekCumle: j['ornek_cumle'] as String,
        taktik: j['taktik'] as String,
        soruSayisi: j['soru_sayisi'] as int?,
        tamIfade: j['tam_ifade'] as String?,
        jsonDisi: j['json_disi'] == true,
      );

  /// "Edat_Kaliplari" → "Edat Kalıpları"
  String get kategoriLabel => kategori.replaceAll('_', ' ');
}
