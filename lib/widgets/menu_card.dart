import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.gradient,
    required this.accentColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final LinearGradient gradient;
  final Color accentColor;
  /// Ana ekranda kaydırma olmadan sığdırmak için daha sıkı padding ve punto.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final edge = compact ? 2.0 : 3.0;
    final hPad = compact ? 12.0 : 18.0;
    final vPad = compact ? 8.0 : 20.0;
    final box = compact ? 38.0 : 52.0;
    final iconSz = compact ? 22.0 : 28.0;
    final titleSz = compact ? 13.5 : 16.0;
    final descSz = compact ? 11.0 : 13.0;
    final gap = compact ? 8.0 : 16.0;
    final arrow = compact ? 13.0 : 15.0;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          child: Icon(icon, color: accentColor, size: iconSz),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: titleSz,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                description,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kTextPrimary.withValues(alpha: 0.65),
                  fontSize: descSz,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: accentColor.withValues(alpha: 0.70),
          size: arrow,
        ),
      ],
    );

    final card = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accentColor.withValues(alpha: 0.12),
        highlightColor: accentColor.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: edge,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: row,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return compact ? SizedBox.expand(child: card) : card;
  }
}
