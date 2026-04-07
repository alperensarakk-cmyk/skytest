/// Sınav modu: toplam her zaman 100 puan; soru başına `100 / soruSayısı`.
class SinavPuanFormat {
  SinavPuanFormat._();

  static double soruBasinaPuan(int toplamSoru) =>
      toplamSoru > 0 ? 100.0 / toplamSoru : 0;

  static double alinanNot(int dogru, int toplamSoru) =>
      toplamSoru > 0 ? dogru * 100.0 / toplamSoru : 0;

  /// Tam sayıysa ondalık gösterme; değilse en fazla 2 ondalık.
  static String formatPuan(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    final x = double.parse(v.toStringAsFixed(4));
    if ((x - x.round()).abs() < 1e-6) return '${x.round()}';
    var s = x.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
