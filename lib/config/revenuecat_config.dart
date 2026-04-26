import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// RevenueCat — Play / App Store ürün kimlikleri ve entitlement.
///
/// **iOS:** Bundle ID `com.aerotest.app` · RevenueCat dashboard uygulama id: `app42949d7901`
/// **App Store ürünleri:** [productMonthlyIos] vb. — ASC ve RevenueCat ile birebir aynı olmalı.
/// **Google Play:** [productMonthlyAndroid] vb. — Play Console ve RevenueCat ile aynı olmalı.
class RevenueCatConfig {
  RevenueCatConfig._();

  // ── Public SDK keys (platform bazlı kullanım: [PremiumService.initialize]) ──

  /// Google Play — RevenueCat public SDK key (`goog_...`).
  static const String apiKeyAndroid = 'goog_zrdKfwpfvyERczyqgZrFSLRJvuB';

  /// Release / CI: `flutter build ... --dart-define=REVENUECAT_IOS_API_KEY=appl_...`
  static const String _apiKeyIosFromEnvironment = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  /// App Store — RevenueCat public SDK key (`appl_...`).
  /// RevenueCat → Project → API keys → **AeroTest (iOS app42949d7901)**.
  /// Boş bırakılabilir; o zaman önce [_apiKeyIosFromEnvironment], yoksa [apiKeyIosSandbox] kullanılır.
  static const String apiKeyIosAppStore = 'appl_KekutYCVZOUneSKsFprWceDEGkZ';

  /// Xcode / simülator / geliştirme: RevenueCat test public key (`test_...`).
  static const String apiKeyIosSandbox = 'test_ZWTtKTxSJkSlmHPJbnqKAhoIDEg';

  /// iOS [Purchases.configure] için çözümlenen anahtar (override → gömülü App Store → test).
  static String get apiKeyIos {
    if (_apiKeyIosFromEnvironment.isNotEmpty) {
      return _apiKeyIosFromEnvironment;
    }
    if (apiKeyIosAppStore.isNotEmpty) {
      return apiKeyIosAppStore;
    }
    return apiKeyIosSandbox;
  }

  // ── Entitlement & ürün kimlikleri (platforma göre [productMonthly] getter’ları) ──

  /// RevenueCat → Entitlements → Identifier
  static const String entitlementId = 'Premium';

  /// Google Play ürün kimlikleri.
  static const String productMonthlyAndroid = 'aerotest_monthly';
  static const String productQuarterlyAndroid = 'aerotest_quarterly';
  static const String productYearlyAndroid = 'aerotest_yearly';

  /// App Store ürün kimlikleri.
  static const String productMonthlyIos = 'com.aerotest.app.sub.monthly';
  static const String productQuarterlyIos = 'com.aerotest.app.sub.quarterly';
  static const String productYearlyIos = 'com.aerotest.app.sub.yearly';

  /// Mağaza + RevenueCat’te kullanılacak ürün id’si (iOS / diğer).
  static String get productMonthly =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? productMonthlyIos
          : productMonthlyAndroid;

  static String get productQuarterly =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? productQuarterlyIos
          : productQuarterlyAndroid;

  static String get productYearly =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? productYearlyIos
          : productYearlyAndroid;
}
