/// Konu bazında doğru / yanlış sayacı (sınav sonucu kaydı).
class KonuPerformans {
  const KonuPerformans({this.dogru = 0, this.yanlis = 0});

  final int dogru;
  final int yanlis;

  int get toplam => dogru + yanlis;

  double get hataOrani => toplam > 0 ? yanlis / toplam : 0;

  KonuPerformans birlestir(KonuPerformans diger) => KonuPerformans(
        dogru: dogru + diger.dogru,
        yanlis: yanlis + diger.yanlis,
      );

  Map<String, int> toJson() => {'dogru': dogru, 'yanlis': yanlis};

  factory KonuPerformans.fromJson(Map<String, dynamic> j) => KonuPerformans(
        dogru: j['dogru'] as int? ?? 0,
        yanlis: j['yanlis'] as int? ?? 0,
      );
}
