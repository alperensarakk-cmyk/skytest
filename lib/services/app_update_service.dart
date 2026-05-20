import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Mağazada yeni sürüm varken uygulama açılışında bilgilendirme.
///
/// Firestore: koleksiyon `app_config`, doküman `store`
/// ```json
/// {
///   "latest_version": "1.0.8",
///   "latest_build": 16,
///   "message": "Yeni içerikler ve iyileştirmeler.",
///   "force_update": false
/// }
/// ```
/// Yeni sürümü Play / App Store’a yükledikten sonra bu alanları güncelle.
class AppUpdateService {
  AppUpdateService._();

  static const _docPath = 'app_config/store';
  static const _prefsDismissedKey = 'update_prompt_dismissed_for';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final snap = await FirebaseFirestore.instance.doc(_docPath).get();
      if (!snap.exists || snap.data() == null) return null;

      final data = snap.data()!;
      final remoteVersion = (data['latest_version'] as String?)?.trim();
      if (remoteVersion == null || remoteVersion.isEmpty) return null;

      final remoteBuild = _asInt(data['latest_build']);
      final message = (data['message'] as String?)?.trim();
      final force = data['force_update'] == true;

      final pkg = await PackageInfo.fromPlatform();
      final currentVersion = pkg.version;
      final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;

      final versionBehind =
          _compareVersions(currentVersion, remoteVersion) < 0;
      final buildBehind =
          remoteBuild != null && currentBuild < remoteBuild;

      if (!versionBehind && !buildBehind) return null;

      final prefs = await SharedPreferences.getInstance();
      final dismissedFor = prefs.getString(_prefsDismissedKey);
      if (!force && dismissedFor == remoteVersion) return null;

      return AppUpdateInfo(
        latestVersion: remoteVersion,
        message: message?.isNotEmpty == true
            ? message!
            : 'Yeni bir güncelleme yayınlandı. En güncel içerik ve düzeltmeler için mağazadan güncelleyin.',
        forceUpdate: force,
        storeUrl: _storeUrl(),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint(
          'AppUpdateService: Firestore okuma engelli (permission-denied). '
          'Console → Firestore → Rules → app_config için allow read: if true',
        );
      } else {
        debugPrint('AppUpdateService.checkForUpdate: ${e.code} ${e.message}');
      }
      return null;
    } catch (e) {
      debugPrint('AppUpdateService.checkForUpdate: $e');
      return null;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context) async {
    final info = await checkForUpdate();
    if (info == null || !context.mounted) return;
    await _showDialog(context, info);
  }

  static Future<void> _showDialog(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: kAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Güncelleme var',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${info.message}\n\nSürüm ${info.latestVersion}',
          style: const TextStyle(
            color: Color(0xFFA1B5D8),
            height: 1.45,
            fontSize: 14,
          ),
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  _prefsDismissedKey,
                  info.latestVersion,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Sonra',
                style: TextStyle(color: Color(0xFFA1B5D8)),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAccent),
            onPressed: () => _openStore(info.storeUrl),
            child: const Text(
              'Güncelle',
              style: TextStyle(
                color: Color(0xFF0B132B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _storeUrl() {
    if (!kIsWeb && Platform.isIOS) return kAppStoreUrl;
    return kPlayStoreUrl;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// 1.0.10 > 1.0.9
  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.message,
    required this.forceUpdate,
    required this.storeUrl,
  });

  final String latestVersion;
  final String message;
  final bool forceUpdate;
  final String storeUrl;
}
