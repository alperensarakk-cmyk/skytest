class KelimeModel {
  final int    id;
  final String ingilizce;
  final String turkce;
  final String modul;
  final String? ornekCumle;
  final String? ipucu;

  const KelimeModel({
    required this.id,
    required this.ingilizce,
    required this.turkce,
    required this.modul,
    this.ornekCumle,
    this.ipucu,
  });

  factory KelimeModel.fromJson(Map<String, dynamic> json) {
    return KelimeModel(
      id:        (json['id'] as num?)?.toInt() ?? 0,
      ingilizce: json['ingilizce'] as String? ?? '',
      turkce:    json['turkce']    as String? ?? '',
      modul:     json['modul']     as String? ?? '',
      ornekCumle: json['ornek_cumle'] as String?,
      ipucu:      json['ipucu']       as String?,
    );
  }
}
