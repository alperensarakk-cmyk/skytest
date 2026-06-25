import 'package:flutter_test/flutter_test.dart';
import 'package:aerotest/models/konu_performans.dart';
import 'package:aerotest/models/sinav_sonucu.dart';
import 'package:aerotest/services/zayif_konu_service.dart';

SinavSonucu _sinav({
  required int dogru,
  required int yanlis,
  Map<String, KonuPerformans> konuPerformans = const {},
  Map<String, int> yanlisKategoriler = const {},
  int analizVersiyonu = 0,
}) {
  final cevaplanan = dogru + yanlis;
  return SinavSonucu(
    tarih: DateTime(2026, 1, 1),
    dogru: dogru,
    yanlis: yanlis,
    bos: 10 - cevaplanan,
    toplam: 10,
    yuzde: cevaplanan > 0 ? dogru / cevaplanan * 100 : 0,
    yanlisKategoriler: yanlisKategoriler,
    konuPerformans: konuPerformans,
    analizVersiyonu: analizVersiyonu,
  );
}

void main() {
  group('ZayifKonuService.hesapla', () {
    test('yanlisKategoriler tek başına analize girmez', () {
      final ozet = ZayifKonuService.hesapla([
        _sinav(
          dogru: 1,
          yanlis: 9,
          yanlisKategoriler: const {
            'Yapi': 9,
            'Ceviri': 6,
            'Kelime': 3,
          },
        ),
      ]);

      expect(ozet.toplamCevaplanan, 0);
      expect(ozet.yeterliVeri, isFalse);
      expect(ozet.konular, isEmpty);
    });

    test('analizVersiyonu 1 artık sayılmaz', () {
      final ozet = ZayifKonuService.hesapla([
        _sinav(
          dogru: 2,
          yanlis: 8,
          analizVersiyonu: 1,
          konuPerformans: const {
            'Yapi': KonuPerformans(dogru: 2, yanlis: 8),
          },
        ),
      ]);

      expect(ozet.toplamCevaplanan, 0);
      expect(ozet.konular, isEmpty);
    });

    test('10 soruluk tek sınavda konu listelenmez', () {
      final ozet = ZayifKonuService.hesapla([
        _sinav(
          dogru: 2,
          yanlis: 8,
          analizVersiyonu: 2,
          konuPerformans: const {
            'Yapi': KonuPerformans(dogru: 2, yanlis: 8),
          },
        ),
      ]);

      expect(ozet.toplamCevaplanan, 10);
      expect(ozet.yeterliVeri, isFalse);
      expect(ozet.konular, isEmpty);
    });

    test('30+ güvenilir soruda zayıf konu çıkar', () {
      final ozet = ZayifKonuService.hesapla([
        _sinav(
          dogru: 12,
          yanlis: 8,
          analizVersiyonu: 2,
          konuPerformans: const {
            'Yapi': KonuPerformans(dogru: 2, yanlis: 6),
            'Ceviri': KonuPerformans(dogru: 5, yanlis: 1),
            'Kelime': KonuPerformans(dogru: 5, yanlis: 1),
          },
        ),
        _sinav(
          dogru: 8,
          yanlis: 2,
          analizVersiyonu: 2,
          konuPerformans: const {
            'Okuma': KonuPerformans(dogru: 8, yanlis: 2),
          },
        ),
      ]);

      expect(ozet.toplamCevaplanan, 30);
      expect(ozet.yeterliVeri, isTrue);
      expect(ozet.konular.length, 1);
      expect(ozet.konular.first.tipKey, 'Yapi');
    });

    test('konuPerformans tutarsızsa sınav sayılmaz', () {
      final ozet = ZayifKonuService.hesapla([
        _sinav(
          dogru: 5,
          yanlis: 5,
          analizVersiyonu: 2,
          konuPerformans: const {
            'Yapi': KonuPerformans(dogru: 0, yanlis: 9),
          },
        ),
      ]);

      expect(ozet.toplamCevaplanan, 0);
      expect(ozet.konular, isEmpty);
    });
  });
}
