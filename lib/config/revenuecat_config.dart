/// RevenueCat — Play / App Store ürün kimlikleri ve entitlement.
/// [productMonthly] vb. mağaza ve RevenueCat panelinde `aerotest_*` olarak tanımlı olmalı.
class RevenueCatConfig {
  RevenueCatConfig._();

  /// Google Play — RevenueCat public SDK key (`goog_...`).
  static const String apiKeyAndroid = 'goog_zrdKfwpfvyERczyqgZrFSLRJvuB';

  /// iOS / simulator — test key; canlı için `appl_...` ile değiştirin.
  static const String apiKeyIos = 'test_ZWTtKTxSJkSlmHPJbnqKAhoIDEg';

  /// RevenueCat → Entitlements → Identifier
  static const String entitlementId = 'Premium';

  static const String productMonthly   = 'aerotest_monthly';
  static const String productQuarterly = 'aerotest_quarterly';
  static const String productYearly    = 'aerotest_yearly';
}
