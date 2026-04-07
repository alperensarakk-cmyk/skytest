import 'package:flutter/material.dart';
import '../models/kalip_model.dart';

class FlashCard extends StatelessWidget {
  const FlashCard({required super.key, required this.kalip});
  final KalipModel kalip;

  @override
  Widget build(BuildContext context) {
    return Center(                          // kartı dikey/yatay ortala
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IntrinsicHeight(             // kartın yüksekliği içeriğe göre
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1C2541), Color(0xFF162035)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF48CAE4).withValues(alpha: 0.05),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Üst gradient şerit ─────────────────────────────
                  Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                      ),
                    ),
                  ),

                  // ── Ana içerik ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kategori
                        Text(
                          kalip.kategoriLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4A6080),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // İpucu cümlesi
                        Text(
                          kalip.ipucuKalip,
                          style: const TextStyle(
                            color: Color(0xFFA1B5D8),
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Ayırıcı
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF48CAE4).withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Cevap – küçültülmüş
                        Text(
                          kalip.tamamlayici,
                          style: const TextStyle(
                            color: Color(0xFF48CAE4),
                            fontSize: 30,           // 44 → 30
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Türkçe anlam
                        Text(
                          kalip.turkcaAnlami,
                          style: TextStyle(
                            color: const Color(0xFFA1B5D8).withValues(alpha: 0.75),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ── Taktik kutusu (içeriğin içinde, üstte) ──
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF233056),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD60A)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.lightbulb_rounded,
                                  color: Color(0xFFFFD60A),
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  kalip.taktik,
                                  style: const TextStyle(
                                    color: Color(0xFF8DA5C8),
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
