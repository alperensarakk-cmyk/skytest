import 'package:flutter/material.dart';
import '../services/exam_countdown_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';
import '../widgets/radar_background.dart';

// ── Kart gradientleri ─────────────────────────────────────────────────────────
const _gradientSinav = LinearGradient(
  colors: [Color(0xFF0077B6), Color(0xFF023E8A)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _gradientKonular = LinearGradient(
  colors: [Color(0xFF1C2541), Color(0xFF0D3B6E)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _gradientKaliplar = LinearGradient(
  colors: [Color(0xFF1C2541), Color(0xFF2D1B69)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

const _gradientKelime = LinearGradient(
  colors: [Color(0xFF2D1B69), Color(0xFF1A3A5C)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.examBannerKey});

  final Key? examBannerKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/branding/logo_mark.png',
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AeroTest',
              style: TextStyle(
                color: kAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Havacılık İngilizcesi Sınav Hazırlık Uygulaması.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _showInfoSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.help_outline_rounded, color: Color(0xFFFF6B6B), size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Nasıl\nçalışır?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 8.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RadarBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Merhaba',
                      style: TextStyle(
                        color: kAccent,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const Spacer(),
                    const _DashboardPremiumCta(),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Nereden başlamak istersin?',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ExamCountdownBanner(
                    key: examBannerKey,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: MenuCard(
                    compact: true,
                    icon: Icons.timer_rounded,
                    title: 'Sınav Modu',
                    description: 'Karışık sorularla kendini test et.',
                    onTap: () =>
                        Navigator.pushNamed(context, '/sinav_hazirlik'),
                    gradient: _gradientSinav,
                    accentColor: kAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: MenuCard(
                    compact: true,
                    icon: Icons.menu_book_rounded,
                    title: 'Konulara Yönelik',
                    description: 'Sistem ve gramer odaklı çalışma.',
                    onTap: () => Navigator.pushNamed(context, '/konular'),
                    gradient: _gradientKonular,
                    accentColor: kAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: MenuCard(
                    compact: true,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Altın Kalıplar',
                    description: 'Kritik havacılık kalıplarını ezberle.',
                    onTap: () => Navigator.pushNamed(context, '/kaliplar'),
                    gradient: _gradientKaliplar,
                    accentColor: const Color(0xFFFFD60A),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: MenuCard(
                    compact: true,
                    icon: Icons.spellcheck_rounded,
                    title: 'Kelime Çalışması',
                    description: 'Teknik havacılık kelimelerini güçlendir.',
                    onTap: () => Navigator.pushNamed(context, '/kelime'),
                    gradient: _gradientKelime,
                    accentColor: const Color(0xFF6C63FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InfoSheet(),
    );
  }
}

// ─── Sınav geri sayım kartı ───────────────────────────────────────────────────

class _ExamCountdownBanner extends StatefulWidget {
  const _ExamCountdownBanner({super.key, this.compact = false});

  final bool compact;

  @override
  State<_ExamCountdownBanner> createState() => _ExamCountdownBannerState();
}

class _ExamCountdownBannerState extends State<_ExamCountdownBanner> {
  DateTime? _date;
  int? _days;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await ExamCountdownService.getTargetDate();
    final days = await ExamCountdownService.daysRemaining();
    if (!mounted) return;
    setState(() {
      _date = d;
      _days = days;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = today.add(const Duration(days: 365 * 5));
    final DateTime initial;
    if (_date == null || _date!.isBefore(today)) {
      initial = today;
    } else {
      initial = _date!;
    }
    final initialClamped = initial.isAfter(last) ? last : initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialClamped,
      firstDate: today,
      lastDate: last,
      helpText: 'Hedef sınav tarihi',
      cancelText: 'İptal',
      confirmText: 'Tamam',
    );
    if (picked == null || !mounted) return;
    await ExamCountdownService.setTargetDate(picked);
    await _load();
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tarihi kaldır',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Sınav geri sayımı ana ekrandan kaldırılsın mı?',
          style: TextStyle(color: Color(0xFFA1B5D8), fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFFA1B5D8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ExamCountdownService.clearTargetDate();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compact;
    final hasDate = _date != null && _days != null;

    String mainText;
    Color mainColor = kTextPrimary;
    if (!hasDate) {
      mainText = 'Tarih seçerek geri sayım başlat';
    } else if (_days! > 0) {
      mainText = 'Sınavınıza $_days gün kaldı';
      mainColor = kAccent;
    } else if (_days == 0) {
      mainText = 'Sınavınız bugün — başarılar!';
      mainColor = const Color(0xFFFFD60A);
    } else {
      mainText = 'Tarih ${_days!.abs()} gün önce geçti';
      mainColor = const Color(0xFFFF6B6B);
    }

    final pad = c
        ? const EdgeInsets.fromLTRB(10, 8, 2, 8)
        : const EdgeInsets.fromLTRB(16, 14, 8, 14);
    final iconPad = c ? 7.0 : 10.0;
    final iconSz = c ? 21.0 : 26.0;
    final gap = c ? 8.0 : 14.0;
    final titleFs = c ? 10.0 : 12.0;
    final mainFs = c ? 14.0 : 17.0;
    final subFs = c ? 10.5 : 13.0;
    final hintFs = c ? 9.5 : 12.0;

    final inner = Container(
      width: double.infinity,
      padding: pad,
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: c ? 8 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            c ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(iconPad),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(c ? 10 : 12),
            ),
            child: Icon(Icons.event_available_rounded,
                color: kAccent, size: iconSz),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sınav geri sayımı',
                  style: TextStyle(
                    color: kAccent.withValues(alpha: 0.9),
                    fontSize: titleFs,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: c ? 3 : 6),
                Text(
                  mainText,
                  maxLines: c ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mainColor,
                    fontSize: mainFs,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                if (hasDate && _date != null) ...[
                  SizedBox(height: c ? 2 : 4),
                  Text(
                    ExamCountdownService.formatDateTr(_date!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFA1B5D8),
                      fontSize: subFs,
                    ),
                  ),
                ],
                if (!hasDate) ...[
                  SizedBox(height: c ? 2 : 4),
                  Text(
                    c ? 'Dokunarak tarih seç' : 'Kartın herhangi bir yerine dokun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF7B8FAB),
                      fontSize: hintFs,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.all(c ? 4 : 8),
            constraints:
                c ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
            visualDensity: c ? VisualDensity.compact : VisualDensity.standard,
            icon: const Icon(Icons.edit_calendar_rounded, color: kAccent),
            iconSize: c ? 20 : 24,
            tooltip: 'Tarih seç',
            onPressed: _pickDate,
          ),
          if (hasDate)
            IconButton(
              padding: EdgeInsets.all(c ? 4 : 8),
              constraints:
                  c ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
              visualDensity:
                  c ? VisualDensity.compact : VisualDensity.standard,
              icon: const Icon(Icons.close_rounded, color: Color(0xFF7B8FAB)),
              iconSize: c ? 20 : 24,
              tooltip: 'Tarihi kaldır',
              onPressed: _confirmClear,
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(16),
        child: c ? SizedBox.expand(child: Center(child: inner)) : inner,
      ),
    );
  }
}

// ─── Bilgi Sayfası ────────────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B3E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Tutamaç ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A6B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Başlık ───────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.rocket_launch_rounded, color: kAccent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Bu Uygulamada Neler Var?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'AeroTest, SHGM/EASA sınavlarına hazırlık için tasarlanmış dört farklı çalışma modunu bir arada sunar.',
                style: TextStyle(color: Color(0xFFA1B5D8), fontSize: 13, height: 1.5),
              ),
            ),

            const SizedBox(height: 20),

            // ── Mod Kartları ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: const [
                  _ModeCard(
                    icon: Icons.timer_rounded,
                    iconColor: Color(0xFF48CAE4),
                    gradient: [Color(0xFF0077B6), Color(0xFF023E8A)],
                    title: 'Sınav Modu',
                    badge: 'Sınav Deneyimi',
                    body:
                        'Gerçek sınav koşullarını simüle eden bu modda süre baskısı altında soru çözersin. '
                        'Ayarlar veya sınav hazırlık ekranından soru sayısını 10\'dan 80\'e, süreyi 10\'dan 120 dakikaya kadar seçebilirsin.\n\n'
                        'Sınav bitince kaç doğru kaç yanlış yaptığını, hangi konularda zayıf olduğunu görürsün. '
                        'Yanlış yaptığın sorular otomatik olarak "Yanlışlarım" listene eklenir.',
                  ),
                  SizedBox(height: 14),
                  _ModeCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: Color(0xFF48CAE4),
                    gradient: [Color(0xFF1C2541), Color(0xFF0D3B6E)],
                    title: 'Konulara Yönelik Çalışma',
                    badge: 'Anlayarak Öğren',
                    body:
                        'Her soru cevaplandığı anda anlık geri bildirim alırsın — doğru cevap yeşil, yanlış kırmızı olarak işaretlenir.\n\n'
                        'Daha da önemlisi, her sorunun altında üç katmanlı bir analiz paneli açılır:\n'
                        '• Neden doğru olduğunun açıklaması\n'
                        '• Diğer şıkların neden yanlış olduğu\n'
                        '• Altın sarısı "Tüyo" kutusu: o soru tipini sınavda hızlı çözmenin kısa yolu',
                  ),
                  SizedBox(height: 14),
                  _ModeCard(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: Color(0xFFFFD60A),
                    gradient: [Color(0xFF1C2541), Color(0xFF2D1B69)],
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
                  SizedBox(height: 14),
                  _ModeCard(
                    icon: Icons.spellcheck_rounded,
                    iconColor: Color(0xFF6C63FF),
                    gradient: [Color(0xFF2D1B69), Color(0xFF1A3A5C)],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.badge,
    required this.body,
  });

  final IconData      icon;
  final Color         iconColor;
  final List<Color>   gradient;
  final String        title;
  final String        badge;
  final String        body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFCDD8EC),
              fontSize: 13,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ana sayfa sağ üst: abonelik değilken CTA; premium iken kalan gün + yine `/premium`.
class _DashboardPremiumCta extends StatefulWidget {
  const _DashboardPremiumCta();

  @override
  State<_DashboardPremiumCta> createState() => _DashboardPremiumCtaState();
}

class _DashboardPremiumCtaState extends State<_DashboardPremiumCta>
    with WidgetsBindingObserver {
  static const Color _gold = Color(0xFFFFD60A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PremiumService.isPremiumNotifier.addListener(_onChanged);
    PremiumService.premiumExpirationNotifier.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PremiumService.isPremiumNotifier.removeListener(_onChanged);
    PremiumService.premiumExpirationNotifier.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = PremiumService.isPremiumNotifier.value;
    final days = PremiumService.premiumCalendarDaysRemaining();

    final String label;
    if (!isPremium) {
      label = '👑 Premium\'a Geç';
    } else if (days != null) {
      label = '👑 Premium ol · $days gün kaldı';
    } else {
      label = '👑 Premium ol';
    }

    return TextButton(
      onPressed: () => Navigator.pushNamed(context, '/premium'),
      style: TextButton.styleFrom(
        foregroundColor: _gold,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
