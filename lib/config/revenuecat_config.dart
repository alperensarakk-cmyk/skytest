/// RevenueCat — Play / App Store ürün kimlikleri ve entitlement.
///
/// **iOS:** Bundle ID `com.aerotest.app` · RevenueCat dashboard uygulama id: `app42949d7901`
/// **Ürünler:** [productMonthly] vb. hem mağazalarda hem RevenueCat’te `aerotest_*` olmalı.
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

  // ── Entitlement & ürün kimlikleri (Android + iOS aynı) ────────────────────

  /// RevenueCat → Entitlements → Identifier
  static const String entitlementId = 'Premium';

  static const String productMonthly = 'aerotest_monthly';
  static const String productQuarterly = 'aerotest_quarterly';
  static const String productYearly = 'aerotest_yearly';
}
