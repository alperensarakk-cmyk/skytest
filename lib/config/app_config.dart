import 'package:flutter/foundation.dart';

/// Uygulama sabitleri.
const adminEmail = 'alperensarakk@gmail.com';

/// Mağaza sayfaları ([AppUpdateService] güncelleme diyaloğu).
const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.skytest.skytest_app';
const kAppStoreUrl = 'https://apps.apple.com/app/id6761938550';

/// Ücretsiz katmanı test için: `flutter run --dart-define=FORCE_FREE_TIER=true`
const forceFreeTier = bool.fromEnvironment('FORCE_FREE_TIER', defaultValue: false);

/// Debug build'de otomatik premium (tüm özellikleri test için).
const isDeveloperMode = kDebugMode && !forceFreeTier;
