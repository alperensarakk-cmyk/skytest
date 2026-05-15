import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ghost_record.dart';
import '../services/sky_fight_service.dart';
import '../services/matchmaking_service.dart';
import '../services/ghost_service.dart';
import '../theme/app_theme.dart';
import 'sky_fight_screen.dart';
import 'online_sky_fight_screen.dart';

const _cGold   = Color(0xFFFFD60A);
const _cMuted  = Color(0xFFA1B5D8);
const _cCard   = Color(0xFF1C2541);
const _cPurple = Color(0xFF6C63FF);
const _cGhost  = Color(0xFF00E5FF);
const _cLive   = Color(0xFF4CAF50);

const _kPilotNameKey = 'skyfight_pilot_name';

enum _LobbyStatus { idle, searching, ghostFound, liveFound }

class SkyFightLobbyScreen extends StatefulWidget {
  const SkyFightLobbyScreen({super.key});

  @override
  State<SkyFightLobbyScreen> createState() => _SkyFightLobbyScreenState();
}

class _SkyFightLobbyScreenState extends State<SkyFightLobbyScreen>
    with SingleTickerProviderStateMixin {
  _LobbyStatus _status     = _LobbyStatus.idle;
  int           _searchSec = 0;
  Timer?        _searchTimer;
  String?       _userId;
  GhostRecord?  _foundGhost;
  String        _pilotName = 'Pilot';

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final name  = prefs.getString(_kPilotNameKey);
    final uid   = await SkyFightService.ensureSignedIn();
    if (mounted) {
      setState(() {
        _userId    = uid;
        _pilotName = name ?? _defaultName(uid);
      });
    }
  }

  String _defaultName(String uid) =>
      'Pilot #${uid.substring(0, uid.length.clamp(0, 4)).toUpperCase()}';

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // ── Pilot isim değiştirme ─────────────────────────────────────────────────

  Future<void> _editPilotName() async {
    final ctrl = TextEditingController(text: _pilotName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Pilot İsmini Seç',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          maxLength: 14,
          style: const TextStyle(color: Colors.white),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 _\-]')),
          ],
          decoration: InputDecoration(
            hintText: 'Örnek: AceWrench47',
            hintStyle: const TextStyle(color: _cMuted),
            filled: true,
            fillColor: const Color(0xFF0D1B2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            counterStyle: const TextStyle(color: _cMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: _cMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cPurple),
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPilotNameKey, newName);
      if (mounted) setState(() => _pilotName = newName);
    }
  }

  // ── Matchmaking ───────────────────────────────────────────────────────────

  Future<void> _startFight() async {
    if (_status != _LobbyStatus.idle) return;

    final userId = _userId ?? await SkyFightService.ensureSignedIn();
    _userId = userId;

    setState(() {
      _status     = _LobbyStatus.searching;
      _searchSec  = 0;
    });

    _searchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _searchSec++);
    });

    try {
      // Katman 1: canlı rakip (15 saniye)
      final liveResult = await MatchmakingService.search(userId);
      _searchTimer?.cancel();
      if (!mounted) return;

      if (liveResult != null) {
        setState(() => _status = _LobbyStatus.liveFound);
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        final questions =
            await SkyFightService.fetchQuestionsByIds(liveResult.questionIds);
        if (!mounted) return;

        if (questions.isNotEmpty) {
          setState(() => _status = _LobbyStatus.idle);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OnlineSkyFightScreen(
                matchId: liveResult.matchId,
                userId: userId,
                isPlayer1: liveResult.isPlayer1,
                questions: questions,
              ),
            ),
          );
          return;
        }
      }

      // Katman 2: ghost kaydı ara
      await _tryGhostOrAi(userId);
    } catch (e) {
      _searchTimer?.cancel();
      if (!mounted) return;
      setState(() => _status = _LobbyStatus.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı hatası: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _tryGhostOrAi(String userId) async {
    if (!mounted) return;

    GhostRecord? ghost;
    try {
      ghost = await GhostService.findOpponent(userId);
    } catch (_) {
      ghost = null;
    }

    if (!mounted) return;

    if (ghost != null) {
      setState(() {
        _status     = _LobbyStatus.ghostFound;
        _foundGhost = ghost;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      try {
        final questions =
            await SkyFightService.fetchQuestionsByIds(ghost.questionIds);
        if (!mounted) return;
        setState(() => _status = _LobbyStatus.idle);

        if (questions.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SkyFightScreen(
                userId: userId,
                questions: questions,
                ghostRecord: ghost,
                pilotName: _pilotName,
              ),
            ),
          );
          return;
        }
      } catch (_) {}
    }

    // Katman 3: AI
    await _launchAi(userId);
  }

  Future<void> _launchAi(String userId) async {
    if (!mounted) return;
    setState(() => _status = _LobbyStatus.idle);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rakip bulunamadı — AI Pilot ile oynuyorsun 🤖'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final questions = await SkyFightService.fetchQuestions(count: 10);
      if (!mounted) return;

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorular yüklenemedi. İnternet bağlantını kontrol et.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SkyFightScreen(
            userId: userId,
            questions: questions,
            pilotName: _pilotName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _cancelSearch() async {
    _searchTimer?.cancel();
    final uid = _userId;
    if (uid != null) await MatchmakingService.cancelSearch(uid);
    if (mounted) setState(() => _status = _LobbyStatus.idle);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: _status == _LobbyStatus.searching
              ? _cancelSearch
              : () => Navigator.pop(context),
        ),
        title: const Text(
          'SkyFight',
          style: TextStyle(
            color: _cGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        // Pilot ismi düzenleme butonu
        actions: [
          if (_status == _LobbyStatus.idle)
            TextButton.icon(
              onPressed: _editPilotName,
              icon: const Icon(Icons.edit_rounded, size: 14, color: _cMuted),
              label: Text(
                _pilotName,
                style: const TextStyle(color: _cMuted, fontSize: 12),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _status == _LobbyStatus.idle
            ? _buildIdle()
            : _buildSearching(),
      ),
    );
  }

  // ── Idle ekranı ───────────────────────────────────────────────────────────

  Widget _buildIdle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 28),

          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_cPurple.withValues(alpha: 0.3), kBgDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cPurple.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.flight_rounded, color: _cGold, size: 58),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'SkyFight',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Canlı rakip, ghost kaydı veya AI Pilot\'a karşı düello',
            style: TextStyle(color: _cMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          _RuleCard(
            icon: Icons.people_alt_rounded,
            color: _cLive,
            title: 'Canlı rakip',
            subtitle: '15 saniye beklenir. Bulunamazsa ghost veya AI devreye girer.',
          ),
          const SizedBox(height: 10),
          _RuleCard(
            icon: Icons.person_rounded,
            color: _cGhost,
            title: 'Ghost kaydı',
            subtitle: 'Daha önce oynayan birinin kaydına karşı oynarsın.',
          ),
          const SizedBox(height: 10),
          _RuleCard(
            icon: Icons.bolt_rounded,
            color: _cGold,
            title: 'Hız belirler',
            subtitle: 'İkiniz de doğruysa daha hızlı cevap veren vurur (-10 HP).',
          ),

          const Spacer(),

          _StartButton(onTap: _startFight),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ── Arama / Bulundu ekranı (tam ekran ortalı) ─────────────────────────────

  Widget _buildSearching() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusContent(),
            const SizedBox(height: 40),
            if (_status == _LobbyStatus.searching)
              TextButton(
                onPressed: _cancelSearch,
                child: const Text(
                  'Aramayı İptal Et',
                  style: TextStyle(color: _cMuted, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent() {
    switch (_status) {
      case _LobbyStatus.searching:
        return _SearchingWidget(seconds: _searchSec);
      case _LobbyStatus.liveFound:
        return const _LiveFoundWidget();
      case _LobbyStatus.ghostFound:
        return _foundGhost != null
            ? _GhostFoundWidget(ghost: _foundGhost!)
            : const _LiveFoundWidget();
      case _LobbyStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

// ── Arama widget'ı ─────────────────────────────────────────────────────────

class _SearchingWidget extends StatelessWidget {
  const _SearchingWidget({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    const total = 15;
    final remaining = (total - seconds).clamp(0, total);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: remaining / total,
                strokeWidth: 5,
                backgroundColor: const Color(0xFF253354),
                valueColor: const AlwaysStoppedAnimation<Color>(_cPurple),
              ),
              Text(
                '$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Canlı rakip aranıyor...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Bulunamazsa ghost kaydına veya\nAI Pilot\'a yönlendirileceksin.',
          style: TextStyle(color: _cMuted, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Canlı rakip bulundu ───────────────────────────────────────────────────

class _LiveFoundWidget extends StatelessWidget {
  const _LiveFoundWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _cLive.withValues(alpha: 0.15),
            border: Border.all(color: _cLive.withValues(alpha: 0.5), width: 2),
          ),
          child: const Icon(Icons.wifi_rounded, color: _cLive, size: 40),
        ),
        const SizedBox(height: 22),
        const Text(
          'Canlı Rakip Bulundu!',
          style: TextStyle(
            color: _cLive,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Düello başlıyor...',
          style: TextStyle(color: _cMuted, fontSize: 14),
        ),
      ],
    );
  }
}

// ── Ghost bulundu ─────────────────────────────────────────────────────────

class _GhostFoundWidget extends StatelessWidget {
  const _GhostFoundWidget({required this.ghost});
  final GhostRecord ghost;

  String get _timeAgo {
    final diff = DateTime.now().difference(ghost.createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _cGhost.withValues(alpha: 0.12),
            border:
                Border.all(color: _cGhost.withValues(alpha: 0.45), width: 2),
          ),
          child: const Icon(Icons.person_rounded, color: _cGhost, size: 44),
        ),
        const SizedBox(height: 20),
        const Text(
          'Rakip Bulundu  👻',
          style: TextStyle(color: _cGhost, fontSize: 14, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          ghost.pilotName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Son kayıt: $_timeAgo  •  ${ghost.finalHp} HP ile bitirdi',
          style: const TextStyle(color: _cMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _cGhost.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cGhost.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'Ghost kaydına karşı oynuyorsun',
            style: TextStyle(color: _cGhost, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ── Başlat butonu ─────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _cPurple.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'SAVAŞA GİR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kural kartı ───────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: _cMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
