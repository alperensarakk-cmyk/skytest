import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/revenuecat_config.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';

const _cMuted = Color(0xFFA1B5D8);
const _cGold = Color(0xFFFFD60A);
const _cCard = Color(0xFF1C2541);

const _kPrivacyPolicyUrl =
    'https://www.freeprivacypolicy.com/live/237c6580-ec2a-442b-be65-a061d8a8b457';
const _kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  Offerings? _offerings;
  Map<String, String> _priceByProductId = {};
  bool _loadingOfferings = true;
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    setState(() => _loadingOfferings = true);
    final results = await Future.wait<dynamic>([
      PremiumService.fetchOfferings(),
      PremiumService.fetchLocalizedPriceStrings(),
    ]);
    if (!mounted) return;
    final o = results[0] as Offerings?;
    final prices = results[1] as Map<String, String>;
    setState(() {
      _offerings = o;
      _priceByProductId = prices;
      _loadingOfferings = false;
    });
  }

  String _priceLine(String productId, String fallback) =>
      _priceByProductId[productId] ?? fallback;

  /// Offering yokken mağaza adı (web / masaüstü için genel ifade).
  String _fallbackPricingHint() {
    if (kIsWeb) {
      return 'Fiyatlar mağaza üzerinden gösterilir; yanıt verilmezse aşağıdaki tutarlar bilgi amaçlıdır.';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'Fiyatlar App Store üzerinden gösterilir; mağaza yanıt vermezse aşağıdaki tutarlar bilgi amaçlıdır.';
      case TargetPlatform.android:
        return 'Fiyatlar Google Play üzerinden gösterilir; mağaza yanıt vermezse aşağıdaki tutarlar bilgi amaçlıdır.';
      default:
        return 'Fiyatlar mağaza üzerinden gösterilir; mağaza yanıt vermezse aşağıdaki tutarlar bilgi amaçlıdır.';
    }
  }

  Future<void> _buy(String productId) async {
    setState(() => _busyProductId = productId);
    try {
      final out = await PremiumService.purchaseProduct(productId);
      if (!mounted) return;
      if (out == PurchaseOutcome.cancelled) return;

      final String? msg = switch (out) {
        PurchaseOutcome.successStore => 'Premium etkinleştirildi!',
        PurchaseOutcome.sdkNotConfigured =>
          'Ödeme sistemi hazır değil. Uygulamayı yeniden başlatıp tekrar deneyin.',
        PurchaseOutcome.productUnavailable => Platform.isIOS
            ? 'Ürün bulunamadı. App Store ve RevenueCat\'te ürün kimliklerinin eşleştiğinden emin olun.'
            : 'Ürün bulunamadı. Google Play ve RevenueCat\'te ürün kimliklerinin eşleştiğinden emin olun.',
        PurchaseOutcome.failed =>
          'Satın alma tamamlanamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
        PurchaseOutcome.cancelled => null,
      };

      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
      if (out == PurchaseOutcome.successStore) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _restore() async {
    setState(() => _busyProductId = 'restore');
    try {
      await PremiumService.restorePurchases();
      if (!mounted) return;
      if (PremiumService.isPremiumNotifier.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alımlar geri yüklendi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geri yüklenecek aktif abonelik bulunamadı.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Geri yükleme hatası: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _launchLegalUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı açılamadı.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      appBar: AppBar(
        backgroundColor: kBgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AeroTest Premium',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadingOfferings || _busyProductId != null
                ? null
                : _loadStoreData,
            icon: Icon(
              Icons.refresh_rounded,
              color: _loadingOfferings || _busyProductId != null
                  ? Colors.white24
                  : kAccent,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.flight_rounded, color: kAccent, size: 56),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'AeroTest Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loadingOfferings
                ? 'Paketler yükleniyor…'
                : (_offerings?.current == null
                    ? _fallbackPricingHint()
                    : 'Tüm içeriğe sınırsız erişim.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _cMuted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 28),
          _feature(Icons.flight_takeoff_rounded, 'Sınırsız soru çözme'),
          _feature(Icons.menu_book_rounded, 'Tüm konulara erişim'),
          _feature(Icons.auto_awesome_rounded, 'Altın kalıplar tam erişim'),
          _feature(Icons.bar_chart_rounded, 'Detaylı istatistik'),
          const SizedBox(height: 28),
          _packageCard(
            title: 'Aylık',
            priceLine: _priceLine(
              RevenueCatConfig.productMonthly,
              '79,99 ₺ / ay',
            ),
            productId: RevenueCatConfig.productMonthly,
            popular: false,
          ),
          const SizedBox(height: 14),
          _packageCard(
            title: '3 Aylık',
            priceLine: _priceLine(
              RevenueCatConfig.productQuarterly,
              '179,99 ₺ / 3 ay',
            ),
            productId: RevenueCatConfig.productQuarterly,
            popular: true,
          ),
          const SizedBox(height: 14),
          _packageCard(
            title: 'Yıllık',
            priceLine: _priceLine(
              RevenueCatConfig.productYearly,
              '489,99 ₺ / yıl',
            ),
            productId: RevenueCatConfig.productYearly,
            popular: false,
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _busyProductId != null ? null : _restore,
              child: const Text(
                'Satın alımları geri yükle',
                style: TextStyle(
                  color: kAccent,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: kAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => _launchLegalUrl(_kPrivacyPolicyUrl),
                style: TextButton.styleFrom(
                  foregroundColor: _cMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Gizlilik Politikası',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFA1B5D8),
                  ),
                ),
              ),
              Text(
                '·',
                style: TextStyle(
                  color: _cMuted.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: () => _launchLegalUrl(_kTermsOfUseUrl),
                style: TextButton.styleFrom(
                  foregroundColor: _cMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Kullanım Koşulları',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFA1B5D8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageCard({
    required String title,
    required String priceLine,
    required String productId,
    required bool popular,
  }) {
    final busy = _busyProductId == productId;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            color: _cCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: popular
                  ? _cGold.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              width: popular ? 2 : 1,
            ),
            boxShadow: popular
                ? [
                    BoxShadow(
                      color: _cGold.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                priceLine,
                style: TextStyle(
                  color: popular ? _cGold : _cMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : () => _buy(productId),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: const Color(0xFF0B132B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0B132B),
                          ),
                        )
                      : const Text(
                          'Satın Al',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (popular)
          Positioned(
            top: -10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _cGold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'En Popüler',
                style: TextStyle(
                  color: Color(0xFF0B132B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
