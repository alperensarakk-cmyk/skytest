import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Limit diyalogunda kullanıcının seçimi.
/// [premium] ise çağıran, üstteki pratik ekranını `Navigator.pop` ile kapatmamalı
/// (aksi halde açılan Premium rotası hemen geri alınır).
enum LimitExceededResult {
  tomorrow,
  premium,
}

/// Günlük ücretsiz limit dolduğunda.
Future<LimitExceededResult?> showDailyLimitExceededDialog(
  BuildContext context,
) {
  return showDialog<LimitExceededResult>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kBgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Bugünlük hakkın doldu 🎯',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Premium\'a geç, sınırsız çöz!',
        style: TextStyle(
          color: Color(0xFFA1B5D8),
          fontSize: 15,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, LimitExceededResult.tomorrow),
          child: const Text(
            'Yarın Gel',
            style: TextStyle(color: Color(0xFF8DA5C8)),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: const Color(0xFF0B132B),
          ),
          onPressed: () {
            Navigator.pop(ctx, LimitExceededResult.premium);
            final navCtx = context;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!navCtx.mounted) return;
              Navigator.of(navCtx, rootNavigator: true)
                  .pushNamed('/premium');
            });
          },
          child: const Text('Premium\'a Geç'),
        ),
      ],
    ),
  );
}
