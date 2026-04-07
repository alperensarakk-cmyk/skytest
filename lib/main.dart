import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/konular_screen.dart';
import 'screens/sinav_screen.dart';
import 'screens/sinav_hazirlik_screen.dart';
import 'screens/kaliplar_screen.dart';
import 'screens/yanlislarim_screen.dart';
import 'screens/kelime_screen.dart';
import 'screens/kelime_yanlislarim_screen.dart';
import 'screens/premium_screen.dart';
import 'services/daily_limit_service.dart';
import 'services/premium_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await PremiumService.initialize();
  await DailyLimitService.ensureDay();
  runApp(const AeroTestApp());
}

class AeroTestApp extends StatelessWidget {
  const AeroTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroTest',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/':                (_) => const MainShell(),
        '/konular':         (_) => const KonularScreen(),
        '/sinav_hazirlik':  (_) => const SinavHazirlikScreen(),
        '/sinav':           (_) => const SinavScreen(),
        '/kaliplar':        (_) => const KaliplarScreen(),
        '/yanlislarim':     (_) => const YanlislarimScreen(),
        '/kelime':          (_) => const KelimeScreen(),
        '/kelime_yanlislar':(_) => const KelimeYanlislarimScreen(),
        '/premium':         (_) => const PremiumScreen(),
      },
    );
  }
}
