import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/exam_countdown_service.dart';
import '../services/istatistik_service.dart';
import '../services/settings_service.dart';
import '../services/yanlis_service.dart';
import '../theme/app_theme.dart';

// ─── Renkler ─────────────────────────────────────────────────────────────────
const _cMuted  = Color(0xFFA1B5D8);
const _cDanger = Color(0xFFFF6B6B);

// ─── Dış bağlantılar ─────────────────────────────────────────────────────────
final Uri _kPrivacyPolicyUri = Uri.parse(
  'https://www.freeprivacypolicy.com/live/237c6580-ec2a-442b-be65-a061d8a8b457',
);

final Uri _kFeedbackMailUri = Uri(
  scheme: 'mailto',
  path: 'aerotest.app@outlook.com',
  queryParameters: {'subject': 'AeroTest Geri Bildirim'},
);

// ─────────────────────────────────────────────────────────────────────────────

class AyarlarScreen extends StatefulWidget {
  const AyarlarScreen({super.key});

  @override
  State<AyarlarScreen> createState() => _AyarlarScreenState();
}

class _AyarlarScreenState extends State<AyarlarScreen> {
  int    _kelimeSetSize     = 20;
  int    _examQuestionCount = 30;
  int    _examDurationMin   = 30;
  bool   _examAutoNext      = true;
  DateTime? _examTargetDate;

  bool _secSinavOpen  = false;
  bool _secKelimeOpen = false;
  bool _secVeriOpen   = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final kelimeSet = await SettingsService.getKelimeSetSize();
    final qCount    = await SettingsService.getExamQuestionCount();
    final duration  = await SettingsService.getExamDurationMin();
    final examAuto  = await SettingsService.getExamAutoNext();
    final examDate    = await ExamCountdownService.getTargetDate();

    if (!mounted) return;
    setState(() {
      _kelimeSetSize     = kelimeSet;
      _examQuestionCount = qCount;
      _examDurationMin   = duration;
      _examAutoNext      = examAuto;
      _examTargetDate    = examDate;
    });
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = today.add(const Duration(days: 365 * 5));
    final DateTime initial;
    if (_examTargetDate == null || _examTargetDate!.isBefore(today)) {
      initial = today;
    } else {
      initial = _examTargetDate!;
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
    setState(() => _examTargetDate =
        DateTime(picked.year, picked.month, picked.day));
    _snack('Sınav tarihi kaydedildi.');
  }

  Future<void> _clearExamDate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tarihi kaldır',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Hedef sınav tarihi silinsin mi?',
          style: TextStyle(color: _cMuted, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: _cMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: _cDanger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ExamCountdownService.clearTargetDate();
    setState(() => _examTargetDate = null);
    _snack('Sınav tarihi kaldırıldı.');
  }

  Future<void> _launchUri(Uri uri, String errorHint) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack(errorHint);
    } catch (_) {
      if (mounted) _snack(errorHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Ayarlar',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _ExpandableSettingsSection(
            title: 'Sınav Ayarları',
            icon: Icons.timer_rounded,
            accentColor: kAccent,
            expanded: _secSinavOpen,
            onToggle: () => setState(() => _secSinavOpen = !_secSinavOpen),
            children: [
              _ExamDateTile(
                date: _examTargetDate,
                onTap: _pickExamDate,
                onClear: _clearExamDate,
              ),
              _Divider(),
              _DropdownTile<int>(
                icon:     Icons.quiz_rounded,
                title:    'Varsayılan Soru Sayısı',
                subtitle: 'Sınav başladığında kaç soru seçileceği.',
                options:  const [10, 20, 30, 40, 50, 60, 80],
                labels:   const ['10 Soru', '20 Soru', '30 Soru', '40 Soru', '50 Soru', '60 Soru', '80 Soru'],
                value:    _examQuestionCount,
                onChanged: (v) {
                  setState(() => _examQuestionCount = v);
                  SettingsService.setExamQuestionCount(v);
                },
              ),
              _Divider(),
              _DropdownTile<int>(
                icon:     Icons.hourglass_bottom_rounded,
                title:    'Varsayılan Süre',
                subtitle: 'Sınav sayacının başlangıç süresi.',
                options:  const [10, 20, 30, 45, 60, 90, 120],
                labels:   const ['10 Dakika', '20 Dakika', '30 Dakika', '45 Dakika', '60 Dakika', '90 Dakika', '120 Dakika'],
                value:    _examDurationMin,
                onChanged: (v) {
                  setState(() => _examDurationMin = v);
                  SettingsService.setExamDurationMin(v);
                },
              ),
              _Divider(),
              _SwitchTile(
                icon:     Icons.flash_on_rounded,
                title:    'Cevaptan Sonra Otomatik Geçiş',
                subtitle: 'Sınavda şık işaretlenince sıradaki soruya otomatik geç.',
                value:    _examAutoNext,
                onChanged: (v) {
                  setState(() => _examAutoNext = v);
                  SettingsService.setExamAutoNext(v);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          _ExpandableSettingsSection(
            title: 'Kelime Çalışması',
            icon: Icons.spellcheck_rounded,
            accentColor: kAccent,
            expanded: _secKelimeOpen,
            onToggle: () => setState(() => _secKelimeOpen = !_secKelimeOpen),
            children: [
              _DropdownTile<int>(
                icon:     Icons.format_list_numbered_rounded,
                title:    'Oturum Kelime Sayısı',
                subtitle: 'Her çalışma oturumunda kaç kelime sorulacağı.',
                options:  const [0, 10, 20, 30, 50],
                labels:   const ['Sonsuz', '10 Kelime', '20 Kelime', '30 Kelime', '50 Kelime'],
                value:    _kelimeSetSize,
                onChanged: (v) {
                  setState(() => _kelimeSetSize = v);
                  SettingsService.setKelimeSetSize(v);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          _ExpandableSettingsSection(
            title: 'Veri Yönetimi',
            icon: Icons.storage_rounded,
            accentColor: _cDanger,
            expanded: _secVeriOpen,
            onToggle: () => setState(() => _secVeriOpen = !_secVeriOpen),
            children: [
              _ActionTile(
                icon:    Icons.replay_circle_filled_rounded,
                title:   'Yanlışlarımı Temizle',
                subtitle: 'Yanlış yapılan soruların listesi silinir.',
                color:   _cDanger,
                onTap:   () => _confirm(
                  title:   'Yanlışlarımı Temizle',
                  message: 'Tüm yanlış soru kayıtları silinecek. Bu işlem geri alınamaz.',
                  onConfirm: () async {
                    await YanlisService.clearAll();
                    _snack('Yanlışlarım listesi temizlendi.');
                  },
                ),
              ),
              _Divider(),
              _ActionTile(
                icon:    Icons.bar_chart_rounded,
                title:   'İstatistikleri Sıfırla',
                subtitle: 'Tamamlanan sınav kayıtları silinir.',
                color:   _cDanger,
                onTap:   () => _confirm(
                  title:   'İstatistikleri Sıfırla',
                  message: 'Tüm sınav geçmişi silinecek. Bu işlem geri alınamaz.',
                  onConfirm: () async {
                    await IstatistikService.clearAll();
                    _snack('Sınav istatistikleri sıfırlandı.');
                  },
                ),
              ),
              _Divider(),
              _ActionTile(
                icon:    Icons.delete_forever_rounded,
                title:   'Tüm Yerel Veriyi Sıfırla',
                subtitle: 'Yanlışlar, istatistikler ve ayarların tamamı silinir.',
                color:   _cDanger,
                onTap:   () => _confirm(
                  title:   'Her Şeyi Sıfırla',
                  message: 'Yanlışlar, istatistikler ve tüm ayarlar silinecek. Uygulama sıfırdan başlayacak.',
                  dangerous: true,
                  onConfirm: () async {
                    await YanlisService.clearAll();
                    await IstatistikService.clearAll();
                    await SettingsService.resetAll();
                    await _loadSettings();
                    _snack('Tüm veriler sıfırlandı.');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SectionLabel(label: 'Hakkında', icon: Icons.info_outline_rounded, color: kAccent),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/branding/logo_mark.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AeroTest',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Sürüm 1.0.0',
                          style: TextStyle(color: _cMuted, fontSize: 12)),
                      SizedBox(height: 2),
                      Text('Havacılık İngilizcesi sınav hazırlık uygulaması.',
                          style: TextStyle(color: _cMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            _Divider(),
            _ActionTile(
              icon:    Icons.privacy_tip_outlined,
              title:   'Gizlilik Politikası',
              subtitle: 'Tarayıcıda aç',
              color:   kAccent,
              onTap:   () => _launchUri(_kPrivacyPolicyUri, 'Bağlantı açılamadı.'),
            ),
            _Divider(),
            _ActionTile(
              icon:    Icons.feedback_outlined,
              title:   'Geri Bildirim Gönder',
              subtitle: 'aerotest.app@outlook.com',
              color:   kAccent,
              onTap:   () => _launchUri(_kFeedbackMailUri, 'E-posta uygulaması açılamadı.'),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirm({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    bool dangerous = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç', style: TextStyle(color: _cMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Onayla',
              style: TextStyle(
                color: dangerous ? _cDanger : kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirm();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: kBgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Alt Widgetlar ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.icon,
    this.color = kAccent,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ExpandableSettingsSection extends StatelessWidget {
  const _ExpandableSettingsSection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: kBgCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _cMuted,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _SettingsCard(children: children),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        indent: 56,
        endIndent: 16,
        color: Color(0xFF253354),
      );
}

class _ExamDateTile extends StatelessWidget {
  const _ExamDateTile({
    required this.date,
    required this.onTap,
    required this.onClear,
  });
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final subtitle = date == null
        ? 'Geri sayım için dokunun; ana ekranda da görünür.'
        : '${ExamCountdownService.formatDateTr(date!)} — değiştirmek için dokunun';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const _IconBox(icon: Icons.event_available_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hedef sınav tarihi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: _cMuted, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (date != null)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: _cDanger,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Kaldır', style: TextStyle(fontSize: 12)),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: kAccent.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData  icon;
  final String    title;
  final String    subtitle;
  final bool      value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: _cMuted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kAccent,
            activeTrackColor: kAccent.withValues(alpha: 0.35),
            inactiveTrackColor: const Color(0xFF253354),
          ),
        ],
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });
  final IconData   icon;
  final String     title;
  final String     subtitle;
  final List<T>    options;
  final List<String> labels;
  final T          value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(color: _cMuted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          DropdownButton<T>(
            value: value,
            dropdownColor: const Color(0xFF1C2541),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.bold),
            iconEnabledColor: kAccent,
            items: List.generate(
              options.length,
              (i) => DropdownMenuItem<T>(
                value: options[i],
                child: Text(labels[i]),
              ),
            ),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconBox(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: _cMuted, fontSize: 11, height: 1.4)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color = kAccent});
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
