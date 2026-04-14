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
  static const _kSignedInEmail = 'signed_in_user_email';

  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier(false);
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
    isPremiumNotifier.value =
        rc || isDeveloperMode || _isAdminEmail(em);
  }

  static Future<void> _loadCached() async {
    await _syncPremiumNotifier();
  }

  static Future<void> _saveCached(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPremiumCached, v);
    await _syncPremiumNotifier();
  }

  static Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final e = info.entitlements.all[RevenueCatConfig.entitlementId];
    final active = e?.isActive == true;
    await _saveCached(active);
  }

  /// Limit kontrolleri: mağaza (RC) || debug build || admin e-postası.
  static Future<bool> isPremiumUser() async => isPremiumNotifier.value;

  /// Ana ekran "Premium'a Geç" butonu.
  /// Debug'ta `isDeveloperMode` notifier'ı true yaptığı için buton hep gizlenirdi;
  /// burada debug build'de CTA yine gösterilir (premium sayfasına girmek için).
  /// Release APK'da yalnızca gerçekten premium değilken gösterilir.
  static bool get showPremiumDashboardCta =>
      isDeveloperMode || !isPremiumNotifier.value;

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
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  static Package? findPackage(Offerings? offerings, String productId) {
    final current = offerings?.current;
    if (current == null) return null;
    for (final p in current.availablePackages) {
      if (p.storeProduct.identifier == productId) return p;
    }
    return null;
  }

  /// Google Play / App Store yerelleştirilmiş fiyat metinleri (`priceString`).
  /// Ürün bulunamaz veya hata olursa boş harita döner; UI sabit metne düşer.
  static Future<Map<String, String>> fetchLocalizedPriceStrings() async {
    if (!_configured) return {};
    try {
      final ids = [
        RevenueCatConfig.productMonthly,
        RevenueCatConfig.productQuarterly,
        RevenueCatConfig.productYearly,
      ];
      final products = await Purchases.getProducts(ids);
      return {for (final p in products) p.identifier: p.priceString};
    } catch (e, st) {
      debugPrint('PremiumService.fetchLocalizedPriceStrings: $e');
      debugPrintStack(stackTrace: st);
      return {};
    }
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
    } catch (e, st) {
      debugPrint('PremiumService.getProducts: $e');
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
    Future<CustomerInfo> Function() purchase,
  ) async {
    try {
      final info = await purchase();
      await _applyCustomerInfo(info);
      return PurchaseOutcome.successStore;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      debugPrint('PremiumService purchase: $e');
      return PurchaseOutcome.failed;
    } catch (e, st) {
      debugPrint('PremiumService purchase: $e');
      debugPrintStack(stackTrace: st);
      return PurchaseOutcome.failed;
    }
  }
}

enum PurchaseOutcome {
  successStore,
  cancelled,
  sdkNotConfigured,
  productUnavailable,
  failed,
}
