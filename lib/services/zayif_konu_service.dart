import '../models/konu_performans.dart';
import '../models/sinav_sonucu.dart';
import '../models/soru_model.dart';
import 'soru_secim_service.dart';

class ZayifKonu {
  const ZayifKonu({
    required this.tipKey,
    required this.label,
    required this.yanlisSayisi,
    required this.dogruSayisi,
  });

  final String tipKey;
  final String label;
  final int yanlisSayisi;
  final int dogruSayisi;

  int get toplamDeneme => dogruSayisi + yanlisSayisi;

  double get hataOrani =>
      toplamDeneme > 0 ? yanlisSayisi / toplamDeneme : 0;
}

/// Zayıf konu kartının durumu (ilerleme + liste).
class ZayifKonuOzet {
  const ZayifKonuOzet({
    required this.konular,
    required this.toplamCevaplanan,
    required this.minGerekli,
  });

  final List<ZayifKonu> konular;
  final int toplamCevaplanan;
  final int minGerekli;

  int get kalan => (minGerekli - toplamCevaplanan).clamp(0, minGerekli);

  bool get yeterliVeri => toplamCevaplanan >= minGerekli;

  bool get zayifKonuVar => konular.isNotEmpty;
}

class ZayifKonuService {
  ZayifKonuService._();

  static const examTipKeys = {
    'Yapi',
    'Ceviri',
    'Kelime',
    'Okuma',
    'Bosluk_Doldurma',
    'Cumle_Tamamlama',
  };

  static const _etiketler = <String, String>{
    'Yapi': 'Gramer & Yapı',
    'Ceviri': 'Çeviri',
    'Kelime': 'Kelime Bilgisi',
    'Okuma': 'Okuma Anlama',
    'Bosluk_Doldurma': 'Boşluk Doldurma',
    'Cumle_Tamamlama': 'Cümle Tamamlama',
    'Gramer': 'Gramer & Yapı',
  };

  /// Kartın açılması için gereken toplam cevaplanmış sınav sorusu.
  static const minToplamCevaplanan = 30;

  /// Bir konunun değerlendirmeye alınması için o tipte en az bu kadar soru.
  static const minKonuDenemesi = 5;

  /// Konu başına en az bu kadar yanlış olmalı.
  static const minKonuYanlis = 3;

  /// Hata oranı en az %40 olmalı (3/5 gibi).
  static const minKonuHataOrani = 0.40;

  static const maxKonuGoster = 6;
  static const pratikSoruSayisi = 15;

  static String etiket(String tipKey) =>
      _etiketler[tipKey] ?? tipKey.replaceAll('_', ' ');

  static String normalizeTipKey(String raw) {
    final tip = SoruSecimService.normalizeSoruTipi(raw);
    if (tip == 'Gramer') return 'Yapi';
    if (examTipKeys.contains(tip)) return tip;
    return tipKeyFromKategori(raw);
  }

  static String tipKeyFromSoru(SoruModel s) {
    final tip = SoruSecimService.normalizeSoruTipi(s.soruTipi);
    if (tip == 'Gramer') return 'Yapi';
    if (examTipKeys.contains(tip)) return tip;
    return tipKeyFromKategori(s.kategori);
  }

  static String tipKeyFromKategori(String kategori) {
    final k = kategori.toLowerCase().replaceAll('_', ' ');

    if (k.contains('ceviri')) return 'Ceviri';
    if (k.contains('kelime')) return 'Kelime';
    if (k.contains('okuma')) return 'Okuma';
    if (k.contains('bosluk')) return 'Bosluk_Doldurma';
    if (k.contains('cumle') && k.contains('tamamlama')) {
      return 'Cumle_Tamamlama';
    }
    if (k.contains('gramer') || k == 'yapi' || k.contains('yapı')) {
      return 'Yapi';
    }
    return 'Yapi';
  }

  static String normalizeStoredKey(String storedKey) {
    if (examTipKeys.contains(storedKey) || storedKey == 'Gramer') {
      return normalizeTipKey(storedKey);
    }
    return tipKeyFromKategori(storedKey);
  }

  static bool soruTipKeyEslesir(SoruModel s, String tipKey) {
    return tipKeyFromSoru(s) == tipKey;
  }

  /// Zayıf konu analizine dahil edilebilir sınav (yeni kayıt + tutarlı veri).
  static bool analizSinaviMi(SinavSonucu s) {
    if (s.analizVersiyonu < 2) return false;
    if (s.konuPerformans.isEmpty) return false;

    var perfDogru = 0;
    var perfYanlis = 0;
    for (final perf in s.konuPerformans.values) {
      perfDogru += perf.dogru;
      perfYanlis += perf.yanlis;
    }

    return perfDogru == s.dogru && perfYanlis == s.yanlis;
  }

  static List<SinavSonucu> _analizSinavlari(List<SinavSonucu> sonuclar) =>
      sonuclar.where(analizSinaviMi).toList();

  /// Yalnızca güvenilir (analizVersiyonu ≥ 1) sınavları sayar.
  static int toplamCevaplananSay(List<SinavSonucu> sonuclar) {
    var n = 0;
    for (final s in _analizSinavlari(sonuclar)) {
      n += s.dogru + s.yanlis;
    }
    return n;
  }

  /// Yalnızca güvenilir sınavlardan konu performansını birleştirir.
  static Map<String, KonuPerformans> birlestir(List<SinavSonucu> sonuclar) {
    final toplam = <String, KonuPerformans>{};

    for (final s in _analizSinavlari(sonuclar)) {
      s.konuPerformans.forEach((tip, perf) {
        final key = normalizeStoredKey(tip);
        final mevcut = toplam[key] ?? const KonuPerformans();
        toplam[key] = mevcut.birlestir(perf);
      });
    }

    return toplam;
  }

  /// İstatistiksel eşiklerle zayıf konu listesi üretir.
  static ZayifKonuOzet hesapla(List<SinavSonucu> sonuclar) {
    final cevaplanan = toplamCevaplananSay(sonuclar);

    if (cevaplanan < minToplamCevaplanan) {
      return ZayifKonuOzet(
        konular: const [],
        toplamCevaplanan: cevaplanan,
        minGerekli: minToplamCevaplanan,
      );
    }

    final birlesik = birlestir(sonuclar);
    final adaylar = <ZayifKonu>[];

    for (final e in birlesik.entries) {
      final perf = e.value;
      if (!_konuZayifMi(perf)) continue;

      adaylar.add(
        ZayifKonu(
          tipKey: e.key,
          label: etiket(e.key),
          yanlisSayisi: perf.yanlis,
          dogruSayisi: perf.dogru,
        ),
      );
    }

    adaylar.sort((a, b) {
      final oranFark = b.hataOrani.compareTo(a.hataOrani);
      if (oranFark != 0) return oranFark;
      return b.yanlisSayisi.compareTo(a.yanlisSayisi);
    });

    return ZayifKonuOzet(
      konular: cevaplanan >= minToplamCevaplanan
          ? adaylar.take(maxKonuGoster).toList()
          : const [],
      toplamCevaplanan: cevaplanan,
      minGerekli: minToplamCevaplanan,
    );
  }

  static bool _konuZayifMi(KonuPerformans perf) {
    if (perf.yanlis < minKonuYanlis) return false;
    if (perf.toplam < minKonuDenemesi) return false;
    // Eski kayıtlarda yalnızca yanlış birikmiş olabilir (doğru=0).
    if (perf.dogru == 0) return false;
    return perf.hataOrani >= minKonuHataOrani;
  }
}
