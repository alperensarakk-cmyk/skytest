import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ana ekran bilgi sayfası ve ilk açılış onboarding kartları.
class AppModeGuide {
  const AppModeGuide({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.badge,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String title;
  final String badge;
  final String body;
}

const List<AppModeGuide> kAppModeGuides = [
  AppModeGuide(
    icon: Icons.timer_rounded,
    iconColor: kAccent,
    gradient: [Color(0xFF1E6AFF), Color(0xFF094199)],
    title: 'Sınav Modu',
    badge: 'Sınav Deneyimi',
    body:
        'Gerçek sınav koşullarını simüle eden bu modda süre baskısı altında soru çözersin. '
        'Ayarlar veya sınav hazırlık ekranından soru sayısını 10\'dan 80\'e, süreyi 10\'dan 120 dakikaya kadar seçebilirsin.\n\n'
        'Sınav bitince kaç doğru kaç yanlış yaptığını görürsün. '
        'Yanlış yaptığın sorular "Yanlışlarım" listene eklenir; en az 30 soru '
        'çözdükten sonra "Zayıf Konularım" kartında istatistiksel olarak zayıf '
        'kaldığın alanlar listelenir ve o konulardan pratik yapabilirsin.',
  ),
  AppModeGuide(
    icon: Icons.menu_book_rounded,
    iconColor: kAccentTeal,
    gradient: [Color(0xFF3B82F6), Color(0xFF0A0F23)],
    title: 'Konulara Yönelik Çalışma',
    badge: 'Anlayarak Öğren',
    body:
        'Her soru cevaplandığı anda anlık geri bildirim alırsın, doğru cevap yeşil, yanlış kırmızı olarak işaretlenir.\n\n'
        'Daha da önemlisi, her sorunun altında üç katmanlı bir analiz paneli açılır:\n'
        '• Neden doğru olduğunun açıklaması\n'
        '• Diğer şıkların neden yanlış olduğu\n'
        '• Altın sarısı "Tüyo" kutusu: o soru tipini sınavda hızlı çözmenin kısa yolu',
  ),
  AppModeGuide(
    icon: Icons.auto_awesome_rounded,
    iconColor: Color(0xFF2563EB),
    gradient: [Color(0xFF1E3A8A), Color(0xFF071B3A)],
    title: 'Altın Kalıplar',
    badge: 'Sınav Refleksi Kazan',
    body:
        'Havacılık İngilizcesi sınavlarında boşluk doldurma soruları büyük yer tutar. '
        'Bu modda, sınavda en sık karşılaşılan edat ve kalıp kombinasyonlarını öğrenirsin.\n\n'
        'Temel mantık şudur: Boşluğun önünde veya arkasında belirli bir kelime varsa, '
        'boşluğa yüksek ihtimalle o kalıbın eşi gelir. '
        'Örneğin "responsible ___" görünce refleks olarak "FOR" yazabilmek; '
        'kartları kaydırarak bu refleksi kazanman için tasarlandı.',
  ),
  AppModeGuide(
    icon: Icons.spellcheck_rounded,
    iconColor: Color(0xFF1D4ED8),
    gradient: [Color(0xFF172554), Color(0xFF071B3A)],
    title: 'Kelime Çalışması',
    badge: 'Sınava Özel Kelime Havuzu',
    body:
        'SHGM/EASA sınavlarında teknik kelime bilgisi doğrudan soru olarak karşına çıkar. '
        'Bu modda, gerçek sınav sorularından derlenen en kritik teknik kelimeler çoktan seçmeli format ile sana sunulur.\n\n'
        'Her kelime için örnek cümle ve akılda kalıcı bir ipucu bulunur. '
        'Yanlış yaptığın kelimeler "Yanlış Kelimelerim" listene düşer; '
        'oradan tekrar çalışarak zamanla sıfıra indirebilirsin. '
        'Oturum kelime sayısını Ayarlar\'dan, hatta sonsuz modda tüm havuzu çalışabilirsin.',
  ),
];
