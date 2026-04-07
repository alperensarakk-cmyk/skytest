import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
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
  int  _selectedIndex = 0;
  DateTime? _lastBackPress;
  /// Ayarlardan dönünce sınav tarihi kartını yenilemek için
  Key _examBannerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PremiumService.syncFromRevenueCat();
    });
  }

  // İstatistik sekmesine her geçişte yeni key → initState yeniden çalışır
  Key _istatistikKey = UniqueKey();

  void _onTabSelected(int i) {
    setState(() {
      if (i == 1) _istatistikKey = UniqueKey(); // veriyi tazele
      if (i == 0 && _selectedIndex != 0) {
        _examBannerKey = UniqueKey(); // sınav tarihi kartını tazele
      }
      _selectedIndex = i;
    });
  }

  Future<bool> _onWillPop() async {
    // Ana sekmede değilse → Ana sekmeye dön
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }

    // Ana sekmede: çift basış kontrolü
    final now = DateTime.now();
    final isDoublePress = _lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2);

    if (isDoublePress) {
      SystemNavigator.pop(); // uygulamadan çık
      return true;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Çıkmak için tekrar basın',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1C2541),
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
      backgroundColor: kBgDark,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(examBannerKey: _examBannerKey),
          IstatistikScreen(key: _istatistikKey),
          const AyarlarScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kBgCard,
        border: Border(
          top: BorderSide(color: Color(0xFF253354), width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: kBgCard,
        shadowColor: Colors.transparent,
        indicatorColor: kAccent.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined,    color: Color(0xFF7B8FAB)),
            selectedIcon: Icon(Icons.home_rounded,    color: kAccent),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: Color(0xFF7B8FAB)),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: kAccent),
            label: 'İstatistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Color(0xFF7B8FAB)),
            selectedIcon: Icon(Icons.settings_rounded, color: kAccent),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
