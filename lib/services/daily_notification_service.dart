import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Yerel bildirimler: günlük 12:00 + haftalık Pazartesi 00:00.
/// Android 12+: bildirim + (mümkünse) tam alarm izni; yoksa inexact yedek.
class DailyNotificationService {
  DailyNotificationService._();

  static const _idDaily = 9001;
  static const _idWeekly = 9002;
  static const _channelDaily = 'aerotest_daily';
  static const _channelWeekly = 'aerotest_weekly';
  static const _prefsPromptAsked = 'notification_prompt_asked_v1';
  static const _prefsEnabled = 'notifications_enabled_v1';

  static const _dailyHour = 12;
  static const _dailyMinute = 0;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _tzReady = false;

  static GlobalKey<NavigatorState>? navigatorKey;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      await _initTimeZone();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onTap,
        onDidReceiveBackgroundNotificationResponse: _onTapBackground,
      );

      if (Platform.isAndroid) {
        await _android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelDaily,
            'Günlük hatırlatma',
            description: 'Her gün öğlen çalışma hatırlatması',
            importance: Importance.high,
          ),
        );
        await _android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelWeekly,
            'Haftalık sınav',
            description: 'Yeni haftalık test başladığında',
            importance: Importance.high,
          ),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsEnabled) == true) {
        await _scheduleAll();
      }
    } catch (e, st) {
      debugPrint('DailyNotificationService.initialize: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Ana ekran açılışında ve ayarlardan dönünce: izin + planlama.
  static Future<void> ensurePermissionAndSchedule() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_prefsPromptAsked) == true;

    if (!alreadyAsked) {
      await prefs.setBool(_prefsPromptAsked, true);
    }

    await _requestPlatformPermissions();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final allowed = await _notificationsAllowed();
    if (!allowed) {
      debugPrint('DailyNotificationService: bildirim izni kapalı');
      await prefs.setBool(_prefsEnabled, false);
      return;
    }

    await prefs.setBool(_prefsEnabled, true);
    await _scheduleAll();

    if (kDebugMode) {
      final mode = await _resolveAndroidScheduleMode();
      debugPrint('DailyNotificationService: planlama tamam (Android mod: $mode)');
    }
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse r) => _onTap(r);

  static void _onTap(NotificationResponse response) {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    switch (response.payload) {
      case 'challenge':
        nav.pushNamed('/challenge');
        break;
      case 'home':
        nav.pushNamedAndRemoveUntil('/', (_) => false);
        break;
    }
  }

  static Future<void> _initTimeZone() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      if (kDebugMode) {
        debugPrint('DailyNotificationService: saat dilimi $name');
      }
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('DailyNotificationService: saat dilimi UTC (yedek)');
    }
    _tzReady = true;
  }

  static Future<void> _requestPlatformPermissions() async {
    if (Platform.isAndroid) {
      await _android?.requestNotificationsPermission();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (await _android?.canScheduleExactNotifications() != true) {
        await _android?.requestExactAlarmsPermission();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<bool> _notificationsAllowed() async {
    if (Platform.isAndroid) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  /// Android 14 + Samsung: inexact çoğu cihazda gecikir veya gelmez.
  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    try {
      if (await _android?.canScheduleExactNotifications() == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint('DailyNotificationService.canScheduleExact: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Debug: anında test bildirimi.
  static Future<void> showImmediateTest() async {
    if (!kDebugMode) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (!await _notificationsAllowed()) return;

    await _plugin.show(
      9003,
      'Bugün ne kadar çalıştın?',
      'Hedeflediğin puan için çalışmaya başla. (test)',
      _detailsDaily(),
      payload: 'home',
    );
    debugPrint('DailyNotificationService: anında test bildirimi gönderildi');
  }

  static Future<void> _scheduleAll() async {
    await _initTimeZone();
    await scheduleDaily();
    await scheduleWeekly();
  }

  static Future<void> scheduleDaily() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await _plugin.cancel(_idDaily);

    final tz.TZDateTime scheduled = kDebugMode
        ? tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2))
        : _nextTimeTodayOrTomorrow(_dailyHour, _dailyMinute);

    final androidMode = await _resolveAndroidScheduleMode();

    if (kDebugMode) {
      debugPrint(
        'DailyNotificationService: günlük → '
        '${scheduled.toIso8601String()} mod=$androidMode',
      );
    }

    try {
      await _plugin.zonedSchedule(
        _idDaily,
        'Bugün ne kadar çalıştın?',
        'Hedeflediğin puan için çalışmaya başla.',
        scheduled,
        _detailsDaily(),
        androidScheduleMode: androidMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            kDebugMode ? null : DateTimeComponents.time,
        payload: 'home',
      );
      debugPrint('DailyNotificationService: günlük planlandı OK');
    } catch (e, st) {
      debugPrint('DailyNotificationService.scheduleDaily: $e');
      debugPrintStack(stackTrace: st);
      if (Platform.isAndroid) {
        await _scheduleDailyInexactFallback(scheduled);
      }
    }
  }

  static Future<void> _scheduleDailyInexactFallback(
      tz.TZDateTime scheduled) async {
    try {
      await _plugin.zonedSchedule(
        _idDaily,
        'Bugün ne kadar çalıştın?',
        'Hedeflediğin puan için çalışmaya başla.',
        scheduled,
        _detailsDaily(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            kDebugMode ? null : DateTimeComponents.time,
        payload: 'home',
      );
      debugPrint('DailyNotificationService: günlük inexact yedek OK');
    } catch (e) {
      debugPrint('DailyNotificationService.scheduleDaily fallback: $e');
    }
  }

  static Future<void> scheduleWeekly() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    await _plugin.cancel(_idWeekly);

    final scheduled = _nextMondayMidnight();
    final androidMode = await _resolveAndroidScheduleMode();

    if (kDebugMode) {
      debugPrint(
        'DailyNotificationService: haftalık → '
        '${scheduled.toIso8601String()} mod=$androidMode',
      );
    }

    try {
      await _plugin.zonedSchedule(
        _idWeekly,
        'Haftalık test başladı',
        'Diğer kullanıcılara karşı kendini test et.',
        scheduled,
        _detailsWeekly(),
        androidScheduleMode: androidMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'challenge',
      );
      debugPrint('DailyNotificationService: haftalık planlandı OK');
    } catch (e, st) {
      debugPrint('DailyNotificationService.scheduleWeekly: $e');
      debugPrintStack(stackTrace: st);
      if (Platform.isAndroid) {
        await _scheduleWeeklyInexactFallback(scheduled);
      }
    }
  }

  static Future<void> _scheduleWeeklyInexactFallback(
      tz.TZDateTime scheduled) async {
    try {
      await _plugin.zonedSchedule(
        _idWeekly,
        'Haftalık test başladı',
        'Diğer kullanıcılara karşı kendini test et.',
        scheduled,
        _detailsWeekly(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'challenge',
      );
      debugPrint('DailyNotificationService: haftalık inexact yedek OK');
    } catch (e) {
      debugPrint('DailyNotificationService.scheduleWeekly fallback: $e');
    }
  }

  static tz.TZDateTime _nextTimeTodayOrTomorrow(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  /// Sonraki Pazartesi 00:00 (hafta başlangıcı).
  static tz.TZDateTime _nextMondayMidnight() {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, 0, 0);
    while (t.weekday != DateTime.monday) {
      t = t.add(const Duration(days: 1));
    }
    if (!t.isAfter(now)) {
      t = t.add(const Duration(days: 7));
    }
    return t;
  }

  static NotificationDetails _detailsDaily() => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelDaily,
          'Günlük hatırlatma',
          channelDescription: 'Her gün öğlen çalışma hatırlatması',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  static NotificationDetails _detailsWeekly() => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelWeekly,
          'Haftalık sınav',
          channelDescription: 'Yeni haftalık test',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
}
