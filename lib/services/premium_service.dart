import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/revenuecat_config.dart';

/// RevenueCat + yerel premium önbelleği (çevrimdışı).
class PremiumService {
  PremiumService._();

  static const _kPremiumCached = 'premium_cached_local';
  static const _kPremiumExpirationIso = 'premium_expiration_iso';
  static const _kSignedInEmail = 'signed_in_user_email';

  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier(false);
  /// Mağaza (RevenueCat) aboneliğinin bitişi; yalnızca RC önbelleği true iken anlamlıdır.
  static final ValueNotifier<DateTime?> premiumExpirationNotifier =
      ValueNotifier<DateTime?>(null);
  static bool _configured = false;

  static Future<void> initialize() async {
    await _loadCached();
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;
    } catch (_) {
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      // Android: Play public key (`goog_...`). iOS: App Store / test (`appl_...` / `test_...`).
      final String rcKey = Platform.isAndroid
          ? RevenueCatConfig.apiKeyAndroid
          : RevenueCatConfig.apiKeyIos;
      await Purchases.configure(PurchasesConfiguration(rcKey));
      _configured = true;
      Purchases.addCustomerInfoUpdateListener((info) {
        Future.microtask(() => _applyCustomerInfo(info));
      });
      await syncFromRevenueCat();
    } catch (e, st) {
      debugPrint('PremiumService.initialize: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  static bool _isAdminEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    return email.trim().toLowerCase() == adminEmail.trim().toLowerCase();
  }

  /// Giriş sonrası (Firebase Auth vb.) çağırın; [null] veya boş = çıkış.
  static Future<void> setSignedInUserEmail(String? email) async {
    final p = await SharedPreferences.getInstance();
    if (email == null || email.trim().isEmpty) {
      await p.remove(_kSignedInEmail);
    } else {
      await p.setString(_kSignedInEmail, email.trim().toLowerCase());
    }
    await _syncPremiumNotifier();
  }

  static Future<String?> getSignedInUserEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kSignedInEmail);
  }

  /// RevenueCat önbelleği + debug premium + admin e-postası.
  static Future<void> _syncPremiumNotifier() async {
    final p = await SharedPreferences.getInstance();
    final rc = p.getBool(_kPremiumCached) ?? false;
    final em = p.getString(_kSignedInEmail);
    if (forceFreeTier) {
      isPremiumNotifier.value = _isAdminEmail(em);
      return;
    }
    isPremiumNotifier.value =
        rc || isDeveloperMode || _isAdminEmail(em);
  }

  static Future<void> _loadCached() async {
    final p = await SharedPreferences.getInstance();
    final rc = p.getBool(_kPremiumCached) ?? false;
    if (rc) {
      final iso = p.getString(_kPremiumExpirationIso);
      premiumExpirationNotifier.value = (iso != null && iso.isNotEmpty)
          ? DateTime.tryParse(iso)
          : null;
    } else {
      premiumExpirationNotifier.value = null;
    }
    await _syncPremiumNotifier();
  }

  static Future<void> _saveCached(
    bool v, {
    String? expirationIso,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPremiumCached, v);
    if (v) {
      if (expirationIso != null && expirationIso.isNotEmpty) {
        await p.setString(_kPremiumExpirationIso, expirationIso);
        premiumExpirationNotifier.value = DateTime.tryParse(expirationIso);
      } else {
        await p.remove(_kPremiumExpirationIso);
        premiumExpirationNotifier.value = null;
      }
    } else {
      await p.remove(_kPremiumExpirationIso);
      premiumExpirationNotifier.value = null;
    }
    await _syncPremiumNotifier();
  }

  static Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final e = info.entitlements.all[RevenueCatConfig.entitlementId];
    final active = e?.isActive == true;
    final iso = active ? e?.expirationDate : null;
    await _saveCached(active, expirationIso: iso);
  }

  /// Limit kontrolleri: mağaza (RC) || debug build || admin e-postası.
  static Future<bool> isPremiumUser() async => isPremiumNotifier.value;

  /// Yerel gün (takvim); mağaza bitiş tarihi yoksa null.
  /// Debug build'de gerçek abonelik yoksa önizleme için 30 gün döner.
  static int? premiumCalendarDaysRemaining() {
    final exp = premiumExpirationNotifier.value;
    if (exp == null) {
      if (isDeveloperMode && isPremiumNotifier.value) return 30;
      return null;
    }
    final now = DateTime.now();
    final expLocal = exp.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(expLocal.year, expLocal.month, expLocal.day);
    final d = expDay.difference(today).inDays;
    return d < 0 ? 0 : d;
  }

  /// RevenueCat App User ID (çekiliş / destek).
  static Future<String?> getAppUserId() async {
    if (!_configured) return null;
    try {
      return await Purchases.appUserID;
    } catch (e) {
      debugPrint('PremiumService.getAppUserId: $e');
      return null;
    }
  }

  /// Uygulama açılışında / sekme dönüşünde.
  static Future<void> syncFromRevenueCat() async {
    if (!_configured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(info);
    } catch (_) {
      await _loadCached();
    }
  }

  static Future<void> restorePurchases() async {
    if (!_configured) {
      await _loadCached();
      return;
    }
    final info = await Purchases.restorePurchases();
    await _applyCustomerInfo(info);
  }

  static Future<Offerings?> fetchOfferings() async {
    if (!_configured) {
      debugPrint(
        '[RevenueCat] getOfferings: atlandı (Purchases.configure yok / başarısız)',
      );
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      _debugLogOfferings(offerings);
      return offerings;
    } on PlatformException catch (e, st) {
      _debugLogRevenueCatPlatformError('fetchOfferings', e);
      debugPrintStack(stackTrace: st);
      return null;
    } catch (e, st) {
      debugPrint('PremiumService.fetchOfferings: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  /// Flutter konsolu: [RevenueCat] getOfferings sonucu — offering’ler ve paketler.
  static void _debugLogOfferings(Offerings offerings) {
    final ids = offerings.all.keys.join(', ');
    final cur = offerings.current?.identifier ?? '(yok)';
    debugPrint('[RevenueCat] getOfferings ─────────────────────────────');
    debugPrint('[RevenueCat] getOfferings: offering sayısı=${offerings.all.length}');
    debugPrint('[RevenueCat] getOfferings: tüm id\'ler=[$ids]');
    debugPrint('[RevenueCat] getOfferings: current offering id=$cur');

    for (final entry in offerings.all.entries) {
      final off = entry.value;
      final metaKeys = off.metadata.keys.join(', ');
      debugPrint(
        '[RevenueCat] offering "${off.identifier}" '
        'serverDescription="${off.serverDescription}" metadataKeys=[$metaKeys]',
      );
      if (off.availablePackages.isEmpty) {
        debugPrint('[RevenueCat]   └ paket yok (availablePackages boş)');
        continue;
      }
      var i = 0;
      for (final p in off.availablePackages) {
        i++;
        final sp = p.storeProduct;
        debugPrint(
          '[RevenueCat]   paket#$i packageId=${p.identifier} '
          'packageType=${p.packageType.name} '
          'storeProductId=${sp.identifier} '
          'price=${sp.priceString} (${sp.currencyCode}) '
          'title="${sp.title}" '
          'subscriptionPeriod=${sp.subscriptionPeriod ?? "-"}',
        );
      }
    }
    debugPrint('[RevenueCat] getOfferings (son) ─────────────────────────');
  }

  static Package? findPackage(Offerings? offerings, String productId) {
    final current = offerings?.current;
    if (current == null) return null;
    for (final p in current.availablePackages) {
      final id = p.storeProduct.identifier;
      if (id == productId || id.startsWith('$productId:')) return p;
    }
    return null;
  }

  /// Play’de abonelik kimliği `productId:basePlan` olabilir; UI [productId] ile arar.
  static String? resolvePriceString(
    Map<String, String> prices,
    String productId,
  ) {
    final direct = prices[productId];
    if (direct != null && direct.isNotEmpty) return direct;
    for (final e in prices.entries) {
      if (e.key.startsWith('$productId:')) return e.value;
    }
    return null;
  }

  static void _registerStoreProductPrice(
    Map<String, String> prices,
    StoreProduct sp,
  ) {
    prices[sp.identifier] = sp.priceString;
    final opt = sp.defaultOption;
    if (opt != null) {
      prices[opt.productId] = opt.fullPricePhase?.price.formatted ??
          opt.pricingPhases.lastOrNull?.price.formatted ??
          sp.priceString;
      prices[opt.storeProductId] = prices[opt.productId]!;
    }
  }

  static void _registerPricesFromOfferings(
    Map<String, String> prices,
    Offerings? offerings,
  ) {
    if (offerings == null) return;
    for (final off in offerings.all.values) {
      for (final pkg in off.availablePackages) {
        _registerStoreProductPrice(prices, pkg.storeProduct);
      }
    }
  }

  /// Mağaza fiyatları: önce RevenueCat offerings, sonra getProducts (Play/App Store).
  static Future<Map<String, String>> fetchLocalizedPriceStrings({
    Offerings? offerings,
  }) async {
    if (!_configured) return {};
    final prices = <String, String>{};
    _registerPricesFromOfferings(prices, offerings);

    try {
      final ids = [
        RevenueCatConfig.productMonthly,
        RevenueCatConfig.productQuarterly,
        RevenueCatConfig.productYearly,
      ];
      final products = await Purchases.getProducts(
        ids,
        productCategory: ProductCategory.subscription,
      );
      for (final p in products) {
        _registerStoreProductPrice(prices, p);
      }
      if (products.isEmpty && prices.isEmpty) {
        debugPrint(
          'PremiumService.fetchLocalizedPriceStrings: mağazadan ürün dönmedi '
          '(ids=$ids). Play/RevenueCat ürün kimliklerini kontrol edin.',
        );
      }
    } catch (e, st) {
      debugPrint('PremiumService.fetchLocalizedPriceStrings: $e');
      debugPrintStack(stackTrace: st);
    }
    return prices;
  }

  /// RevenueCat: önce mevcut offering içindeki paket, yoksa mağaza ürünü doğrudan
  /// (`getProducts` + `purchaseStoreProduct`) — offerings boş olsa bile App Store /
  /// Play’de ürün tanımlıysa satın alma ekranı açılabilir.
  static Future<PurchaseOutcome> purchaseProduct(String productId) async {
    if (!_configured) {
      debugPrint('PremiumService: Purchases.configure başarısız veya çağrılmadı');
      return PurchaseOutcome.sdkNotConfigured;
    }

    final offerings = await fetchOfferings();
    final pkg = findPackage(offerings, productId);

    if (pkg != null) {
      return _executePurchase(() => Purchases.purchasePackage(pkg));
    }

    debugPrint(
      'PremiumService: Offering\'de paket yok ($productId), getProducts deneniyor',
    );

    late final List<StoreProduct> products;
    try {
      products = await Purchases.getProducts([productId]);
    } on PlatformException catch (e, st) {
      _debugLogRevenueCatPlatformError('getProducts($productId)', e);
      debugPrintStack(stackTrace: st);
      return PurchaseOutcome.failed;
    } catch (e, st) {
      debugPrint('PremiumService.getProducts($productId): $e');
      debugPrintStack(stackTrace: st);
      return PurchaseOutcome.failed;
    }

    if (products.isEmpty) {
      return PurchaseOutcome.productUnavailable;
    }

    return _executePurchase(
      () => Purchases.purchaseStoreProduct(products.first),
    );
  }

  static Future<PurchaseOutcome> _executePurchase(
    Future<PurchaseResult> Function() purchase,
  ) async {
    try {
      final result = await purchase();
      await _applyCustomerInfo(result.customerInfo);
      return PurchaseOutcome.successStore;
    } on PlatformException catch (e, st) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      _debugLogRevenueCatPlatformError('purchase', e);
      debugPrintStack(stackTrace: st);
      return PurchaseOutcome.failed;
    } catch (e, st) {
      debugPrint('PremiumService purchase (non-PlatformException): $e');
      debugPrintStack(stackTrace: st);
      return PurchaseOutcome.failed;
    }
  }

  static void _debugLogRevenueCatPlatformError(
    String context,
    PlatformException e,
  ) {
    final PurchasesErrorCode purchasesCode =
        PurchasesErrorHelper.getErrorCode(e);
    debugPrint(
      'PremiumService.$context: PurchasesErrorCode=$purchasesCode '
      'platformCode=${e.code} message=${e.message} details=${e.details}',
    );
  }
}

enum PurchaseOutcome {
  successStore,
  cancelled,
  sdkNotConfigured,
  productUnavailable,
  failed,
}
