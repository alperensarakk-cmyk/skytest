import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/figma_home_layout.dart';
import '../services/app_update_service.dart';
import '../services/premium_service.dart';
import 'dashboard_screen.dart';
import 'istatistik_screen.dart';
import 'ayarlar_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  DateTime? _lastBackPress;
  Key _examBannerKey = UniqueKey();
  Key _homeKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PremiumService.syncFromRevenueCat();
      AppUpdateService.checkAndPrompt(context);
    });
  }

  Key _istatistikKey = UniqueKey();

  void _onTabSelected(int i) {
    setState(() {
      if (i == 1) _istatistikKey = UniqueKey();
      if (i == 0 && _selectedIndex != 0) {
        _examBannerKey = UniqueKey();
        _homeKey = UniqueKey();
      }
      _selectedIndex = i;
    });
  }

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }

    final now = DateTime.now();
    final isDoublePress = _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);

    if (isDoublePress) {
      SystemNavigator.pop();
      return true;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Çıkmak için tekrar basın',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kBgCard,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: kBgPrimary,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardScreen(key: _homeKey, examBannerKey: _examBannerKey),
            IstatistikScreen(key: _istatistikKey),
            const AyarlarScreen(),
          ],
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    final s = MediaQuery.sizeOf(context).width / FigmaHomeLayout.frameWidth;
    return ColoredBox(
      color: kBgPrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 * s, 0, 12 * s, 6 * s),
          child: Container(
            height: FigmaHomeLayout.navH * s,
            decoration: BoxDecoration(
              color: kBgSecondary.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavTab(
                  icon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  selected: _selectedIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),
                _NavTab(
                  icon: Icons.bar_chart_rounded,
                  label: 'İstatistik',
                  selected: _selectedIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),
                _NavTab(
                  icon: Icons.settings_rounded,
                  label: 'Ayarlar',
                  selected: _selectedIndex == 2,
                  onTap: () => _onTabSelected(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kAccent : kTextSecondary.withValues(alpha: 0.65);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected)
                Container(
                  width: 28,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 7),
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
